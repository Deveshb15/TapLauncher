import Foundation
import IOKit
import IOKit.hid

// HID constants for Apple SPU sensors (Bosch BMI286 IMU).
private let kPageVendor: Int = 0xFF00
private let kUsageAccel: Int = 3
private let kIMUReportLen: Int = 22
private let kIMUDataOffset: Int = 6
private let kIMUDecimation: Int = 8
private let kReportBufSize: Int = 4096
private let kReportIntervalUS: Int32 = 1000

enum AccelerometerError: Error, CustomStringConvertible {
    case noSPUDrivers
    case noAccelerometer
    case deviceOpenFailed(Int32)

    var description: String {
        switch self {
        case .noSPUDrivers: return "No AppleSPUHIDDriver found — not Apple Silicon?"
        case .noAccelerometer: return "No accelerometer HID device found"
        case .deviceOpenFailed(let kr): return "IOHIDDeviceOpen failed: \(kr)"
        }
    }
}

/// Reads the Apple Silicon accelerometer via IOKit HID.
/// Must run as root. Callbacks fire on the main CFRunLoop.
class Accelerometer {
    var onSample: ((Double, Double, Double) -> Void)?

    private var device: IOHIDDevice?
    private var reportBuffer = [UInt8](repeating: 0, count: kReportBufSize)
    private var decimationCounter: Int = 0

    func start() throws {
        try wakeSPUDrivers()
        try registerAccelerometer()
    }

    func stop() {
        if let device = device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            self.device = nil
        }
    }

    // MARK: - Wake SPU Drivers

    private func wakeSPUDrivers() throws {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else {
            throw AccelerometerError.noSPUDrivers
        }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            throw AccelerometerError.noSPUDrivers
        }
        defer { IOObjectRelease(iterator) }

        var found = false
        var service = IOIteratorNext(iterator)
        while service != 0 {
            found = true
            let props: [(String, Int32)] = [
                ("SensorPropertyReportingState", 1),
                ("SensorPropertyPowerState", 1),
                ("ReportInterval", kReportIntervalUS),
            ]
            for (key, value) in props {
                var val = value
                let cfKey = key as CFString
                let cfVal = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &val)!
                IORegistryEntrySetCFProperty(service, cfKey, cfVal)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        if !found {
            throw AccelerometerError.noSPUDrivers
        }
    }

    // MARK: - Register Accelerometer HID Device

    private func registerAccelerometer() throws {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else {
            throw AccelerometerError.noAccelerometer
        }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            throw AccelerometerError.noAccelerometer
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let usagePage = registryPropertyInt(service, key: "PrimaryUsagePage"),
                  let usage = registryPropertyInt(service, key: "PrimaryUsage") else {
                continue
            }

            if usagePage == kPageVendor && usage == kUsageAccel {
                let hidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, service)
                guard let hidDevice = hidDevice else { continue }
                let dev = hidDevice as IOHIDDevice

                let openResult = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
                guard openResult == kIOReturnSuccess else {
                    throw AccelerometerError.deviceOpenFailed(openResult)
                }

                self.device = dev

                // Register input report callback.
                // We pass `self` as context via Unmanaged pointer.
                let context = Unmanaged.passUnretained(self).toOpaque()
                reportBuffer.withUnsafeMutableBufferPointer { buf in
                    IOHIDDeviceRegisterInputReportCallback(
                        dev,
                        buf.baseAddress!,
                        buf.count,
                        hidReportCallback,
                        context
                    )
                }

                IOHIDDeviceScheduleWithRunLoop(
                    dev,
                    CFRunLoopGetMain(),
                    CFRunLoopMode.defaultMode.rawValue
                )

                return // Found and registered the accelerometer
            }
        }

        throw AccelerometerError.noAccelerometer
    }

    // MARK: - Report Parsing

    fileprivate func handleReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length == kIMUReportLen else { return }

        // Decimation: keep 1 in N samples
        decimationCounter += 1
        if decimationCounter < kIMUDecimation { return }
        decimationCounter = 0

        let off = kIMUDataOffset
        guard length >= off + 12 else { return }

        // Parse XYZ as little-endian Int32 from byte offsets 6, 10, 14
        let rawX = report.advanced(by: off).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        let rawY = report.advanced(by: off + 4).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        let rawZ = report.advanced(by: off + 8).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }

        let x = Int32(littleEndian: rawX)
        let y = Int32(littleEndian: rawY)
        let z = Int32(littleEndian: rawZ)

        let gx = Double(x) / 65536.0
        let gy = Double(y) / 65536.0
        let gz = Double(z) / 65536.0

        onSample?(gx, gy, gz)
    }

    // MARK: - Helpers

    private func registryPropertyInt(_ service: io_service_t, key: String) -> Int? {
        guard let ref = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return nil
        }
        let value = ref.takeRetainedValue()
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
}

// C-compatible callback function for IOKit HID reports.
private func hidReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context = context else { return }
    let accel = Unmanaged<Accelerometer>.fromOpaque(context).takeUnretainedValue()
    accel.handleReport(report, length: reportLength)
}

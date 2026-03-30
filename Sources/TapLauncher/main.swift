import AppKit

// Require root for IOKit HID access to the accelerometer.
guard geteuid() == 0 else {
    fputs("Error: TapLauncher requires root access for accelerometer.\n", stderr)
    fputs("Run with: sudo \(CommandLine.arguments[0])\n", stderr)
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // Menu bar only, no Dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()

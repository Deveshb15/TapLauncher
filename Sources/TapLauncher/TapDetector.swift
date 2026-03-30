import Foundation

enum TapEvent {
    case singleTap(amplitude: Double)
    case doubleTap(amplitude: Double)
}

/// Detects single and double taps from accelerometer data.
///
/// Pipeline: high-pass filter → spike detection → single/double state machine.
class TapDetector {
    var onTap: ((TapEvent) -> Void)?
    var minAmplitude: Double = 0.05
    var doubleTapWindow: TimeInterval = 0.4
    var cooldown: TimeInterval = 0.75

    // High-pass filter state (alpha = 0.95, removes gravity)
    private let hpAlpha: Double = 0.95
    private var hpPrevRaw: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private var hpPrevOut: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private var hpReady: Bool = false

    // Spike detection
    private var lastSpikeTime: Date = .distantPast
    private let minInterSpikeGap: TimeInterval = 0.05 // 50ms

    // Single/double tap state machine
    private enum State {
        case idle
        case waitingForSecondTap(firstAmplitude: Double)
        case cooldownActive
    }
    private var state: State = .idle
    private var doubleTapTimer: DispatchWorkItem?
    private var cooldownTimer: DispatchWorkItem?

    func processSample(x: Double, y: Double, z: Double) {
        // Stage 1: High-pass filter to remove gravity
        if !hpReady {
            hpPrevRaw = (x, y, z)
            hpReady = true
            return
        }

        let hx = hpAlpha * (hpPrevOut.x + x - hpPrevRaw.x)
        let hy = hpAlpha * (hpPrevOut.y + y - hpPrevRaw.y)
        let hz = hpAlpha * (hpPrevOut.z + z - hpPrevRaw.z)
        hpPrevRaw = (x, y, z)
        hpPrevOut = (hx, hy, hz)

        let magnitude = (hx * hx + hy * hy + hz * hz).squareRoot()

        // Stage 2: Spike detection
        let now = Date()
        guard magnitude > minAmplitude,
              now.timeIntervalSince(lastSpikeTime) > minInterSpikeGap else {
            return
        }
        lastSpikeTime = now

        // Stage 3: Single/double tap state machine
        handleSpike(amplitude: magnitude)
    }

    private func handleSpike(amplitude: Double) {
        switch state {
        case .idle:
            state = .waitingForSecondTap(firstAmplitude: amplitude)

            // Start timer — if no second tap arrives, it's a single tap
            let timer = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.onTap?(.singleTap(amplitude: amplitude))
                self.enterCooldown()
            }
            doubleTapTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapWindow, execute: timer)

        case .waitingForSecondTap(let firstAmplitude):
            // Second tap arrived within window — double tap!
            doubleTapTimer?.cancel()
            doubleTapTimer = nil
            let amp = max(firstAmplitude, amplitude)
            onTap?(.doubleTap(amplitude: amp))
            enterCooldown()

        case .cooldownActive:
            break // Ignore taps during cooldown
        }
    }

    private func enterCooldown() {
        state = .cooldownActive
        let timer = DispatchWorkItem { [weak self] in
            self?.state = .idle
        }
        cooldownTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldown, execute: timer)
    }
}

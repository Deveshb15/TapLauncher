import AppKit

// Require root for IOKit HID access to the accelerometer.
guard geteuid() == 0 else {
    fputs("Error: TapLauncher requires root access for accelerometer.\n", stderr)
    fputs("Run with: sudo \(CommandLine.arguments[0])\n", stderr)
    exit(1)
}

let app = NSApplication.shared

// First launch: show as regular app with Dock icon so settings window is prominent.
// Subsequent launches: menu bar only.
if Settings.shared.config.hasLaunchedBefore {
    app.setActivationPolicy(.accessory)
} else {
    app.setActivationPolicy(.regular)
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()

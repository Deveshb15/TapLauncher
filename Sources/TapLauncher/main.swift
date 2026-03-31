import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)

// If not running as root, prompt for admin privileges and relaunch.
if geteuid() != 0 {
    let execPath = Bundle.main.executablePath ?? CommandLine.arguments[0]

    let alert = NSAlert()
    alert.messageText = "TapLauncher needs administrator access"
    alert.informativeText = "The accelerometer can only be read with root privileges. Click \"Grant Access\" to enter your password."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Grant Access")
    alert.addButton(withTitle: "Quit")

    let response = alert.runModal()
    guard response == .alertFirstButtonReturn else { exit(0) }

    // Relaunch as root via osascript password prompt
    let escapedPath = execPath.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", "do shell script \"\\\"\(escapedPath)\\\"\" with administrator privileges"]
    do {
        try proc.run()
    } catch {
        let errAlert = NSAlert()
        errAlert.messageText = "Failed to get admin access"
        errAlert.informativeText = "\(error.localizedDescription)"
        errAlert.runModal()
    }
    exit(0)
}

// Running as root — start the app normally.
if Settings.shared.config.hasLaunchedBefore {
    app.setActivationPolicy(.accessory)
} else {
    app.setActivationPolicy(.regular)
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()

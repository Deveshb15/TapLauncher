import Foundation

/// Launches apps as the real (non-root) user via launchctl.
class AppLauncher {
    private let realUID: uid_t

    init() {
        if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"],
           let pw = getpwnam(sudoUser) {
            realUID = pw.pointee.pw_uid
        } else {
            realUID = getuid()
        }
    }

    func handle(event: TapEvent) {
        let config = Settings.shared.config
        let appPath: String?

        switch event {
        case .singleTap:
            appPath = config.singleTapAppPath
        case .doubleTap:
            appPath = config.doubleTapAppPath
        }

        guard let path = appPath else { return }
        launchApp(at: path)
    }

    private func launchApp(at path: String) {
        let appName = URL(fileURLWithPath: path)
            .deletingPathExtension().lastPathComponent

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["asuser", "\(realUID)", "/usr/bin/open", "-a", appName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

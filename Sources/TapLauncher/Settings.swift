import Foundation

enum SoundMode: String, Codable, CaseIterable {
    case pain, sexy, halo, lizard, custom, none
}

struct TapLauncherConfig: Codable {
    var singleTapAppPath: String?
    var doubleTapAppPath: String?
    var soundMode: SoundMode = .pain
    var customAudioPath: String?
    var minAmplitude: Double = 0.05
    var doubleTapWindow: Double = 0.4
    var cooldown: Double = 0.75
    var isEnabled: Bool = true
}

class Settings {
    static let shared = Settings()

    var config: TapLauncherConfig

    private let configURL: URL

    private init() {
        let realUser = ProcessInfo.processInfo.environment["SUDO_USER"] ?? NSUserName()
        let realHome = "/Users/\(realUser)"
        let configDir = "\(realHome)/.config/taplauncher"
        configURL = URL(fileURLWithPath: "\(configDir)/config.json")

        // Ensure config directory exists
        try? FileManager.default.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true
        )

        // Load existing config or use defaults
        if let data = try? Data(contentsOf: configURL),
           let loaded = try? JSONDecoder().decode(TapLauncherConfig.self, from: data) {
            config = loaded
        } else {
            config = TapLauncherConfig()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configURL)

        // chown the file back to the real user
        let realUser = ProcessInfo.processInfo.environment["SUDO_USER"] ?? NSUserName()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/chown")
        process.arguments = ["-R", "\(realUser):staff", configURL.deletingLastPathComponent().path]
        try? process.run()
        process.waitUntilExit()
    }

    func appName(for path: String?) -> String {
        guard let path = path else { return "Not Set" }
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }
}

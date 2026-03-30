import AVFoundation
import Foundation

/// Plays sound effects on tap events, with multiple sound modes matching spank.
class AudioPlayer {
    var soundMode: SoundMode = .pain
    var customAudioPath: String?

    // Escalation tracking (for sexy/lizard modes)
    private var escalationScore: Double = 0
    private var lastTapTime: Date = .distantPast
    private let decayHalfLife: Double = 30.0 // seconds

    // Keep references to active players so they aren't deallocated mid-playback
    private var activePlayers: [AVAudioPlayer] = []

    // Cached file lists per mode
    private var cachedFiles: [SoundMode: [URL]] = [:]

    func playForTap(amplitude: Double) {
        guard soundMode != .none else { return }

        let files = audioFiles(for: soundMode)
        guard !files.isEmpty else { return }

        let file: URL
        switch soundMode {
        case .sexy, .lizard:
            file = selectEscalated(from: files)
        case .pain, .halo, .custom, .none:
            file = files.randomElement()!
        }

        playFile(file)
    }

    // MARK: - Sound Mode File Loading

    private func audioFiles(for mode: SoundMode) -> [URL] {
        if let cached = cachedFiles[mode] { return cached }

        var files: [URL] = []

        switch mode {
        case .pain, .sexy, .halo, .lizard:
            let dirName = mode.rawValue
            if let resourceURL = findAudioDirectory(named: dirName) {
                files = loadMP3s(from: resourceURL)
            }
        case .custom:
            if let path = customAudioPath {
                files = loadMP3s(from: URL(fileURLWithPath: path))
            }
        case .none:
            break
        }

        // Sort by filename for consistent escalation ordering
        files.sort { $0.lastPathComponent < $1.lastPathComponent }
        cachedFiles[mode] = files
        return files
    }

    /// Look for audio directory in multiple locations:
    /// 1. .app bundle Resources/audio/<name>
    /// 2. SPM Bundle.module (for swift run)
    private func findAudioDirectory(named name: String) -> URL? {
        // .app bundle: Contents/Resources/audio/<name>
        let appBundlePath = Bundle.main.bundlePath
        let appResourceDir = URL(fileURLWithPath: appBundlePath)
            .appendingPathComponent("Contents/Resources/audio/\(name)")
        if FileManager.default.fileExists(atPath: appResourceDir.path) {
            return appResourceDir
        }

        // SPM resource bundle (for swift run / swift build)
        if let url = Bundle.module.url(forResource: "audio/\(name)", withExtension: nil) {
            return url
        }

        return nil
    }

    private func loadMP3s(from directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var mp3s: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "mp3" {
                mp3s.append(url)
            }
        }
        return mp3s
    }

    // MARK: - Escalation Logic (ported from spank's slapTracker)

    private func selectEscalated(from files: [URL]) -> URL {
        let now = Date()

        // Decay existing score
        if lastTapTime != .distantPast {
            let elapsed = now.timeIntervalSince(lastTapTime)
            escalationScore *= pow(0.5, elapsed / decayHalfLife)
        }
        escalationScore += 1.0
        lastTapTime = now

        // Calculate scale factor so sustained max-rate tapping reaches the last file
        let cooldown = Settings.shared.config.cooldown
        let ssMax = 1.0 / (1.0 - pow(0.5, cooldown / decayHalfLife))
        let scale = (ssMax - 1.0) / log(Double(files.count + 1))

        // Map score to file index using 1 - exp(-x) sigmoid
        let normalized = 1.0 - exp(-(escalationScore - 1.0) / scale)
        let idx = min(Int(Double(files.count) * normalized), files.count - 1)
        return files[max(0, idx)]
    }

    // MARK: - Playback

    private func playFile(_ url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            activePlayers.append(player)
            player.play()

            // Clean up after playback finishes
            let duration = player.duration + 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.activePlayers.removeAll { $0 === player }
            }
        } catch {
            fputs("Audio playback error: \(error)\n", stderr)
        }
    }

    /// Clear cached files (call when sound mode or custom path changes).
    func invalidateCache() {
        cachedFiles.removeAll()
        escalationScore = 0
        lastTapTime = .distantPast
    }
}

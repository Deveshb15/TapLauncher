import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accelerometer: Accelerometer!
    private var tapDetector: TapDetector!
    private var appLauncher: AppLauncher!
    private var audioPlayer: AudioPlayer!
    private var settingsWindow: NSWindow?

    // Menu items that need dynamic updates
    private var statusMenuItem: NSMenuItem!
    private var singleTapMenuItem: NSMenuItem!
    private var doubleTapMenuItem: NSMenuItem!
    private var soundMenuItem: NSMenuItem!
    private var enabledMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupComponents()
        setupMenuBar()
        startAccelerometer()

        // First launch: open settings if no apps are configured yet
        let config = Settings.shared.config
        if config.singleTapAppPath == nil && config.doubleTapAppPath == nil {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
        }
    }

    // MARK: - Setup

    private func setupComponents() {
        let config = Settings.shared.config

        accelerometer = Accelerometer()
        tapDetector = TapDetector()
        appLauncher = AppLauncher()
        audioPlayer = AudioPlayer()

        // Apply settings
        tapDetector.minAmplitude = config.minAmplitude
        tapDetector.doubleTapWindow = config.doubleTapWindow
        tapDetector.cooldown = config.cooldown
        audioPlayer.soundMode = config.soundMode
        audioPlayer.customAudioPath = config.customAudioPath

        // Wire pipeline
        accelerometer.onSample = { [weak self] x, y, z in
            guard let self = self, Settings.shared.config.isEnabled else { return }
            self.tapDetector.processSample(x: x, y: y, z: z)
        }

        tapDetector.onTap = { [weak self] event in
            guard let self = self else { return }
            let tapType: String
            switch event {
            case .singleTap(let amp):
                tapType = "Single tap (amp: \(String(format: "%.3f", amp)))"
            case .doubleTap(let amp):
                tapType = "Double tap (amp: \(String(format: "%.3f", amp)))"
            }
            print(tapType)

            self.appLauncher.handle(event: event)
            self.audioPlayer.playForTap(amplitude: {
                switch event {
                case .singleTap(let a), .doubleTap(let a): return a
                }
            }())
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "TapLauncher") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "T"
            }
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "TapLauncher", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        statusMenuItem = NSMenuItem(title: "Status: Listening...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        singleTapMenuItem = NSMenuItem(
            title: "Single Tap \u{2192} \(Settings.shared.appName(for: Settings.shared.config.singleTapAppPath))",
            action: nil,
            keyEquivalent: ""
        )
        singleTapMenuItem.isEnabled = false
        menu.addItem(singleTapMenuItem)

        doubleTapMenuItem = NSMenuItem(
            title: "Double Tap \u{2192} \(Settings.shared.appName(for: Settings.shared.config.doubleTapAppPath))",
            action: nil,
            keyEquivalent: ""
        )
        doubleTapMenuItem.isEnabled = false
        menu.addItem(doubleTapMenuItem)

        soundMenuItem = NSMenuItem(
            title: "Sound: \(Settings.shared.config.soundMode.rawValue.capitalized)",
            action: nil,
            keyEquivalent: ""
        )
        soundMenuItem.isEnabled = false
        menu.addItem(soundMenuItem)

        menu.addItem(.separator())

        enabledMenuItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: "e"
        )
        enabledMenuItem.target = self
        enabledMenuItem.state = Settings.shared.config.isEnabled ? .on : .off
        menu.addItem(enabledMenuItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func startAccelerometer() {
        do {
            try accelerometer.start()
            statusMenuItem.title = "Status: Listening..."
            print("Accelerometer started, listening for taps...")
        } catch {
            statusMenuItem.title = "Status: Error - \(error)"
            fputs("Accelerometer error: \(error)\n", stderr)
        }
    }

    // MARK: - Menu Actions

    @objc private func toggleEnabled() {
        Settings.shared.config.isEnabled.toggle()
        enabledMenuItem.state = Settings.shared.config.isEnabled ? .on : .off
        statusMenuItem.title = Settings.shared.config.isEnabled ? "Status: Listening..." : "Status: Paused"
        Settings.shared.save()
    }

    @objc private func quit() {
        accelerometer.stop()
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = createSettingsWindow()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings Window

    private func createSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "TapLauncher Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        var y: CGFloat = 420
        let leftMargin: CGFloat = 20
        let labelWidth: CGFloat = 120.0
        let fieldWidth: CGFloat = 220.0

        let config = Settings.shared.config

        // --- Tap Actions ---
        y -= 30
        addSectionLabel(to: contentView, text: "Tap Actions", y: y)

        y -= 30
        addLabel(to: contentView, text: "Single Tap:", x: leftMargin, y: y)
        let singleTapField = addTextField(
            to: contentView,
            x: leftMargin + labelWidth,
            y: y,
            width: fieldWidth,
            value: config.singleTapAppPath ?? ""
        )
        singleTapField.tag = 1
        addButton(to: contentView, title: "Choose...", x: leftMargin + labelWidth + fieldWidth + 8, y: y) { [weak self] in
            self?.chooseApp(for: singleTapField)
        }

        y -= 30
        addLabel(to: contentView, text: "Double Tap:", x: leftMargin, y: y)
        let doubleTapField = addTextField(
            to: contentView,
            x: leftMargin + labelWidth,
            y: y,
            width: fieldWidth,
            value: config.doubleTapAppPath ?? ""
        )
        doubleTapField.tag = 2
        addButton(to: contentView, title: "Choose...", x: leftMargin + labelWidth + fieldWidth + 8, y: y) { [weak self] in
            self?.chooseApp(for: doubleTapField)
        }

        // --- Sound Mode ---
        y -= 40
        addSectionLabel(to: contentView, text: "Sound Mode", y: y)

        y -= 30
        let soundModes: [SoundMode] = [.pain, .sexy, .halo, .lizard, .custom, .none]
        let popup = NSPopUpButton(frame: NSRect(x: leftMargin, y: y, width: 200, height: 25))
        for mode in soundModes {
            popup.addItem(withTitle: mode.rawValue.capitalized)
        }
        popup.selectItem(withTitle: config.soundMode.rawValue.capitalized)
        popup.tag = 10
        contentView.addSubview(popup)

        y -= 30
        addLabel(to: contentView, text: "Custom folder:", x: leftMargin, y: y)
        let customField = addTextField(
            to: contentView,
            x: leftMargin + labelWidth,
            y: y,
            width: fieldWidth,
            value: config.customAudioPath ?? ""
        )
        customField.tag = 3
        addButton(to: contentView, title: "Browse...", x: leftMargin + labelWidth + fieldWidth + 8, y: y) { [weak self] in
            self?.chooseDirectory(for: customField)
        }

        // --- Sensitivity ---
        y -= 40
        addSectionLabel(to: contentView, text: "Sensitivity", y: y)

        y -= 30
        addLabel(to: contentView, text: "Amplitude:", x: leftMargin, y: y)
        let ampSlider = NSSlider(
            value: config.minAmplitude,
            minValue: 0.01,
            maxValue: 0.3,
            target: nil,
            action: nil
        )
        ampSlider.frame = NSRect(x: leftMargin + labelWidth, y: y, width: 200, height: 20)
        ampSlider.tag = 20
        contentView.addSubview(ampSlider)
        let ampLabel = addValueLabel(to: contentView, x: leftMargin + labelWidth + 210, y: y, value: String(format: "%.2f", config.minAmplitude))
        ampLabel.tag = 21
        ampSlider.target = self
        ampSlider.action = #selector(sliderChanged(_:))

        y -= 30
        addLabel(to: contentView, text: "Tap window:", x: leftMargin, y: y)
        let tapWindowSlider = NSSlider(
            value: config.doubleTapWindow * 1000,
            minValue: 200,
            maxValue: 800,
            target: nil,
            action: nil
        )
        tapWindowSlider.frame = NSRect(x: leftMargin + labelWidth, y: y, width: 200, height: 20)
        tapWindowSlider.tag = 30
        contentView.addSubview(tapWindowSlider)
        let twLabel = addValueLabel(to: contentView, x: leftMargin + labelWidth + 210, y: y, value: "\(Int(config.doubleTapWindow * 1000))ms")
        twLabel.tag = 31
        tapWindowSlider.target = self
        tapWindowSlider.action = #selector(sliderChanged(_:))

        y -= 30
        addLabel(to: contentView, text: "Cooldown:", x: leftMargin, y: y)
        let cooldownSlider = NSSlider(
            value: config.cooldown * 1000,
            minValue: 300,
            maxValue: 2000,
            target: nil,
            action: nil
        )
        cooldownSlider.frame = NSRect(x: leftMargin + labelWidth, y: y, width: 200, height: 20)
        cooldownSlider.tag = 40
        contentView.addSubview(cooldownSlider)
        let cdLabel = addValueLabel(to: contentView, x: leftMargin + labelWidth + 210, y: y, value: "\(Int(config.cooldown * 1000))ms")
        cdLabel.tag = 41
        cooldownSlider.target = self
        cooldownSlider.action = #selector(sliderChanged(_:))

        // --- Save / Cancel ---
        y -= 50
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings(_:)))
        saveButton.frame = NSRect(x: 280, y: y, width: 80, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings(_:)))
        cancelButton.frame = NSRect(x: 370, y: y, width: 80, height: 30)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        return window
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard let contentView = settingsWindow?.contentView else { return }
        switch sender.tag {
        case 20: // amplitude
            if let label = contentView.viewWithTag(21) as? NSTextField {
                label.stringValue = String(format: "%.2f", sender.doubleValue)
            }
        case 30: // tap window
            if let label = contentView.viewWithTag(31) as? NSTextField {
                label.stringValue = "\(Int(sender.doubleValue))ms"
            }
        case 40: // cooldown
            if let label = contentView.viewWithTag(41) as? NSTextField {
                label.stringValue = "\(Int(sender.doubleValue))ms"
            }
        default:
            break
        }
    }

    @objc private func saveSettings(_ sender: Any) {
        guard let contentView = settingsWindow?.contentView else { return }

        // Read fields
        if let field = contentView.viewWithTag(1) as? NSTextField {
            let path = field.stringValue.isEmpty ? nil : field.stringValue
            Settings.shared.config.singleTapAppPath = path
        }
        if let field = contentView.viewWithTag(2) as? NSTextField {
            let path = field.stringValue.isEmpty ? nil : field.stringValue
            Settings.shared.config.doubleTapAppPath = path
        }
        if let field = contentView.viewWithTag(3) as? NSTextField {
            let path = field.stringValue.isEmpty ? nil : field.stringValue
            Settings.shared.config.customAudioPath = path
        }
        if let popup = contentView.viewWithTag(10) as? NSPopUpButton,
           let title = popup.selectedItem?.title,
           let mode = SoundMode(rawValue: title.lowercased()) {
            Settings.shared.config.soundMode = mode
        }
        if let slider = contentView.viewWithTag(20) as? NSSlider {
            Settings.shared.config.minAmplitude = slider.doubleValue
        }
        if let slider = contentView.viewWithTag(30) as? NSSlider {
            Settings.shared.config.doubleTapWindow = slider.doubleValue / 1000.0
        }
        if let slider = contentView.viewWithTag(40) as? NSSlider {
            Settings.shared.config.cooldown = slider.doubleValue / 1000.0
        }

        // Apply to components
        let config = Settings.shared.config
        tapDetector.minAmplitude = config.minAmplitude
        tapDetector.doubleTapWindow = config.doubleTapWindow
        tapDetector.cooldown = config.cooldown
        audioPlayer.soundMode = config.soundMode
        audioPlayer.customAudioPath = config.customAudioPath
        audioPlayer.invalidateCache()

        // Update menu
        singleTapMenuItem.title = "Single Tap \u{2192} \(Settings.shared.appName(for: config.singleTapAppPath))"
        doubleTapMenuItem.title = "Double Tap \u{2192} \(Settings.shared.appName(for: config.doubleTapAppPath))"
        soundMenuItem.title = "Sound: \(config.soundMode.rawValue.capitalized)"

        Settings.shared.save()
        settingsWindow?.close()
    }

    @objc private func cancelSettings(_ sender: Any) {
        settingsWindow?.close()
    }

    // MARK: - File Choosers

    private func chooseApp(for textField: NSTextField) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            textField.stringValue = url.path
        }
    }

    private func chooseDirectory(for textField: NSTextField) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let url = panel.url {
            textField.stringValue = url.path
        }
    }

    // MARK: - View Helpers

    private func addSectionLabel(to view: NSView, text: String, y: CGFloat) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 20, y: y, width: 440, height: 20)
        label.font = .boldSystemFont(ofSize: 13)
        view.addSubview(label)
    }

    private func addLabel(to view: NSView, text: String, x: CGFloat, y: CGFloat) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: x, y: y, width: 120, height: 20)
        label.alignment = .right
        view.addSubview(label)
    }

    @discardableResult
    private func addTextField(to view: NSView, x: CGFloat, y: CGFloat, width: CGFloat, value: String) -> NSTextField {
        let field = NSTextField(string: value)
        field.frame = NSRect(x: x, y: y, width: width, height: 22)
        field.isEditable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        view.addSubview(field)
        return field
    }

    @discardableResult
    private func addValueLabel(to view: NSView, x: CGFloat, y: CGFloat, value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.frame = NSRect(x: x, y: y, width: 60, height: 20)
        view.addSubview(label)
        return label
    }

    private func addButton(to view: NSView, title: String, x: CGFloat, y: CGFloat, action: @escaping () -> Void) {
        let button = CallbackButton(title: title, action: action)
        button.frame = NSRect(x: x, y: y, width: 80, height: 22)
        button.bezelStyle = .rounded
        view.addSubview(button)
    }
}

// Helper button that invokes a closure
private class CallbackButton: NSButton {
    private var callback: (() -> Void)?

    convenience init(title: String, action: @escaping () -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.callback = action
        self.target = self
        self.action = #selector(buttonClicked)
    }

    @objc private func buttonClicked() {
        callback?()
    }
}

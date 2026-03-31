import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
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

    // Settings window controls (stored instead of tag-based lookup)
    private var singleTapIconView: NSImageView!
    private var singleTapNameLabel: NSTextField!
    private var singleTapPath: String?
    private var doubleTapIconView: NSImageView!
    private var doubleTapNameLabel: NSTextField!
    private var doubleTapPath: String?
    private var soundModePopup: NSPopUpButton!
    private var customFolderField: NSTextField!
    private var ampSlider: NSSlider!
    private var ampValueLabel: NSTextField!
    private var tapWindowSlider: NSSlider!
    private var tapWindowValueLabel: NSTextField!
    private var cooldownSlider: NSSlider!
    private var cooldownValueLabel: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupComponents()
        setupMenuBar()
        startAccelerometer()

        // First launch or no apps configured: open settings
        let config = Settings.shared.config
        if !config.hasLaunchedBefore || (config.singleTapAppPath == nil && config.doubleTapAppPath == nil) {
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

        tapDetector.minAmplitude = config.minAmplitude
        tapDetector.doubleTapWindow = config.doubleTapWindow
        tapDetector.cooldown = config.cooldown
        audioPlayer.soundMode = config.soundMode
        audioPlayer.customAudioPath = config.customAudioPath

        accelerometer.onSample = { [weak self] x, y, z in
            guard let self = self, Settings.shared.config.isEnabled else { return }
            self.tapDetector.processSample(x: x, y: y, z: z)
        }

        tapDetector.onTap = { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .singleTap(let amp):
                print("Single tap (amp: \(String(format: "%.3f", amp)))")
            case .doubleTap(let amp):
                print("Double tap (amp: \(String(format: "%.3f", amp)))")
            }

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
            action: nil, keyEquivalent: ""
        )
        singleTapMenuItem.isEnabled = false
        menu.addItem(singleTapMenuItem)

        doubleTapMenuItem = NSMenuItem(
            title: "Double Tap \u{2192} \(Settings.shared.appName(for: Settings.shared.config.doubleTapAppPath))",
            action: nil, keyEquivalent: ""
        )
        doubleTapMenuItem.isEnabled = false
        menu.addItem(doubleTapMenuItem)

        soundMenuItem = NSMenuItem(
            title: "Sound: \(Settings.shared.config.soundMode.rawValue.capitalized)",
            action: nil, keyEquivalent: ""
        )
        soundMenuItem.isEnabled = false
        menu.addItem(soundMenuItem)

        menu.addItem(.separator())

        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledMenuItem.target = self
        enabledMenuItem.state = Settings.shared.config.isEnabled ? .on : .off
        menu.addItem(enabledMenuItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
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
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = createSettingsWindow()
        settingsWindow = window
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Mark first launch as done
        if !Settings.shared.config.hasLaunchedBefore {
            Settings.shared.config.hasLaunchedBefore = true
            Settings.shared.save()
        }
        // Return to menu-bar-only mode
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Settings Window

    private func createSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TapLauncher"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 520)

        let config = Settings.shared.config
        singleTapPath = config.singleTapAppPath
        doubleTapPath = config.doubleTapAppPath

        // Main vertical stack
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Tap Actions Section ---
        let tapBox = makeSection(title: "Tap Actions")
        let tapContent = NSStackView()
        tapContent.orientation = .vertical
        tapContent.spacing = 12

        let singleRow = makeAppRow(
            label: "Single Tap",
            appPath: config.singleTapAppPath,
            iconView: &singleTapIconView,
            nameLabel: &singleTapNameLabel,
            action: #selector(chooseSingleTapApp)
        )
        let doubleRow = makeAppRow(
            label: "Double Tap",
            appPath: config.doubleTapAppPath,
            iconView: &doubleTapIconView,
            nameLabel: &doubleTapNameLabel,
            action: #selector(chooseDoubleTapApp)
        )
        tapContent.addArrangedSubview(singleRow)
        tapContent.addArrangedSubview(doubleRow)
        tapBox.contentView = tapContent
        mainStack.addArrangedSubview(tapBox)

        // --- Sound Mode Section ---
        let soundBox = makeSection(title: "Sound Mode")
        let soundContent = NSStackView()
        soundContent.orientation = .vertical
        soundContent.spacing = 12

        // Mode selector row with preview button
        let modeRow = NSStackView()
        modeRow.orientation = .horizontal
        modeRow.spacing = 10
        modeRow.alignment = .centerY
        let modeLabel = NSTextField(labelWithString: "Mode:")
        modeLabel.font = .systemFont(ofSize: 13)
        modeLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        soundModePopup = NSPopUpButton(frame: .zero)
        for mode in SoundMode.allCases {
            let title: String
            let desc: String
            switch mode {
            case .pain:   title = "Pain";   desc = " — 10 protest sounds"
            case .sexy:   title = "Sexy";   desc = " — 60 escalating clips"
            case .halo:   title = "Halo";   desc = " — 9 death sounds"
            case .lizard: title = "Lizard"; desc = " — escalating lizard"
            case .custom: title = "Custom"; desc = " — your MP3s"
            case .none:   title = "None";   desc = " — silent"
            }
            soundModePopup.addItem(withTitle: title + desc)
            soundModePopup.lastItem?.representedObject = mode.rawValue
        }
        // Select current mode
        for item in soundModePopup.itemArray {
            if item.representedObject as? String == config.soundMode.rawValue {
                soundModePopup.select(item)
                break
            }
        }
        soundModePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true

        let previewBtn = NSButton(frame: .zero)
        previewBtn.bezelStyle = .rounded
        previewBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Preview sound")
        previewBtn.imagePosition = .imageLeading
        previewBtn.title = " Preview"
        previewBtn.target = self
        previewBtn.action = #selector(previewSoundMode)

        modeRow.addArrangedSubview(modeLabel)
        modeRow.addArrangedSubview(soundModePopup)
        modeRow.addArrangedSubview(previewBtn)
        modeRow.addArrangedSubview(NSView()) // spacer
        soundContent.addArrangedSubview(modeRow)

        // Custom folder row
        let customRow = NSStackView()
        customRow.orientation = .horizontal
        customRow.spacing = 10
        customRow.alignment = .centerY
        let customLabel = NSTextField(labelWithString: "Custom folder:")
        customLabel.font = .systemFont(ofSize: 13)
        customLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        customFolderField = NSTextField(string: config.customAudioPath ?? "")
        customFolderField.isEditable = true
        customFolderField.isBezeled = true
        customFolderField.bezelStyle = .roundedBezel
        customFolderField.placeholderString = "Select a folder with MP3 files..."
        customFolderField.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        let browseBtn = NSButton(title: "Browse...", target: self, action: #selector(browseCustomFolder))
        browseBtn.bezelStyle = .rounded
        customRow.addArrangedSubview(customLabel)
        customRow.addArrangedSubview(customFolderField)
        customRow.addArrangedSubview(browseBtn)
        soundContent.addArrangedSubview(customRow)

        soundBox.contentView = soundContent
        mainStack.addArrangedSubview(soundBox)

        // --- Sensitivity Section ---
        let sensBox = makeSection(title: "Sensitivity")
        let sensContent = NSStackView()
        sensContent.orientation = .vertical
        sensContent.spacing = 10

        let ampRow = makeSliderRow(
            label: "Sensitivity",
            value: config.minAmplitude,
            min: 0.01, max: 0.3,
            displayValue: String(format: "%.2f", config.minAmplitude),
            slider: &ampSlider,
            valueLabel: &ampValueLabel,
            action: #selector(sliderChanged(_:))
        )
        let tapWinRow = makeSliderRow(
            label: "Tap window",
            value: config.doubleTapWindow * 1000,
            min: 200, max: 800,
            displayValue: "\(Int(config.doubleTapWindow * 1000))ms",
            slider: &tapWindowSlider,
            valueLabel: &tapWindowValueLabel,
            action: #selector(sliderChanged(_:))
        )
        let cdRow = makeSliderRow(
            label: "Cooldown",
            value: config.cooldown * 1000,
            min: 300, max: 2000,
            displayValue: "\(Int(config.cooldown * 1000))ms",
            slider: &cooldownSlider,
            valueLabel: &cooldownValueLabel,
            action: #selector(sliderChanged(_:))
        )
        sensContent.addArrangedSubview(ampRow)
        sensContent.addArrangedSubview(tapWinRow)
        sensContent.addArrangedSubview(cdRow)
        sensBox.contentView = sensContent
        mainStack.addArrangedSubview(sensBox)

        // --- Buttons ---
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(cancelBtn)
        buttonRow.addArrangedSubview(saveBtn)
        mainStack.addArrangedSubview(buttonRow)

        // Layout
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])

        // Make sections fill width
        for view in mainStack.arrangedSubviews {
            if view is NSBox || view is NSStackView {
                view.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -48).isActive = true
            }
        }

        return window
    }

    // MARK: - Section Builder

    private func makeSection(title: String) -> NSBox {
        let box = NSBox()
        box.title = title
        box.titleFont = .boldSystemFont(ofSize: 13)
        box.boxType = .primary
        box.contentViewMargins = NSSize(width: 12, height: 12)
        return box
    }

    // MARK: - App Row Builder

    private func makeAppRow(
        label: String,
        appPath: String?,
        iconView: inout NSImageView!,
        nameLabel: inout NSTextField!,
        action: Selector
    ) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let tapLabel = NSTextField(labelWithString: label)
        tapLabel.font = .systemFont(ofSize: 13)
        tapLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let icon = NSImageView()
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        icon.imageScaling = .scaleProportionallyUpOrDown
        iconView = icon

        let name = NSTextField(labelWithString: "Not Set")
        name.font = .systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingTail
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel = name

        // Set initial state
        updateAppDisplay(iconView: icon, nameLabel: name, path: appPath)

        let chooseBtn = NSButton(title: "Choose...", target: self, action: action)
        chooseBtn.bezelStyle = .rounded

        row.addArrangedSubview(tapLabel)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(name)
        row.addArrangedSubview(chooseBtn)

        return row
    }

    private func updateAppDisplay(iconView: NSImageView, nameLabel: NSTextField, path: String?) {
        guard let path = path, FileManager.default.fileExists(atPath: path) else {
            iconView.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "No app")
            nameLabel.stringValue = "Not Set"
            nameLabel.textColor = .secondaryLabelColor
            return
        }
        iconView.image = NSWorkspace.shared.icon(forFile: path)
        nameLabel.stringValue = Settings.shared.appName(for: path)
        nameLabel.textColor = .labelColor
    }

    // MARK: - Slider Row Builder

    private func makeSliderRow(
        label: String,
        value: Double,
        min: Double,
        max: Double,
        displayValue: String,
        slider: inout NSSlider!,
        valueLabel: inout NSTextField!,
        action: Selector
    ) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = .systemFont(ofSize: 13)
        textLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let sl = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        sl.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        slider = sl

        let vl = NSTextField(labelWithString: displayValue)
        vl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        vl.widthAnchor.constraint(equalToConstant: 60).isActive = true
        vl.alignment = .right
        valueLabel = vl

        row.addArrangedSubview(textLabel)
        row.addArrangedSubview(sl)
        row.addArrangedSubview(vl)

        return row
    }

    // MARK: - Settings Actions

    @objc private func sliderChanged(_ sender: NSSlider) {
        if sender === ampSlider {
            ampValueLabel.stringValue = String(format: "%.2f", sender.doubleValue)
        } else if sender === tapWindowSlider {
            tapWindowValueLabel.stringValue = "\(Int(sender.doubleValue))ms"
        } else if sender === cooldownSlider {
            cooldownValueLabel.stringValue = "\(Int(sender.doubleValue))ms"
        }
    }

    @objc private func chooseSingleTapApp() {
        if let path = chooseApp() {
            singleTapPath = path
            updateAppDisplay(iconView: singleTapIconView, nameLabel: singleTapNameLabel, path: path)
        }
    }

    @objc private func chooseDoubleTapApp() {
        if let path = chooseApp() {
            doubleTapPath = path
            updateAppDisplay(iconView: doubleTapIconView, nameLabel: doubleTapNameLabel, path: path)
        }
    }

    @objc private func previewSoundMode() {
        guard let rawValue = soundModePopup.selectedItem?.representedObject as? String,
              let mode = SoundMode(rawValue: rawValue) else { return }
        let customPath = customFolderField.stringValue.isEmpty ? nil : customFolderField.stringValue
        audioPlayer.previewSound(for: mode, customPath: customPath)
    }

    @objc private func browseCustomFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            customFolderField.stringValue = url.path
        }
    }

    @objc private func saveSettings() {
        Settings.shared.config.singleTapAppPath = singleTapPath
        Settings.shared.config.doubleTapAppPath = doubleTapPath

        if let rawValue = soundModePopup.selectedItem?.representedObject as? String,
           let mode = SoundMode(rawValue: rawValue) {
            Settings.shared.config.soundMode = mode
        }

        let customPath = customFolderField.stringValue
        Settings.shared.config.customAudioPath = customPath.isEmpty ? nil : customPath
        Settings.shared.config.minAmplitude = ampSlider.doubleValue
        Settings.shared.config.doubleTapWindow = tapWindowSlider.doubleValue / 1000.0
        Settings.shared.config.cooldown = cooldownSlider.doubleValue / 1000.0

        // Apply to live components
        let config = Settings.shared.config
        tapDetector.minAmplitude = config.minAmplitude
        tapDetector.doubleTapWindow = config.doubleTapWindow
        tapDetector.cooldown = config.cooldown
        audioPlayer.soundMode = config.soundMode
        audioPlayer.customAudioPath = config.customAudioPath
        audioPlayer.invalidateCache()

        // Update menu bar
        singleTapMenuItem.title = "Single Tap \u{2192} \(Settings.shared.appName(for: config.singleTapAppPath))"
        doubleTapMenuItem.title = "Double Tap \u{2192} \(Settings.shared.appName(for: config.doubleTapAppPath))"
        soundMenuItem.title = "Sound: \(config.soundMode.rawValue.capitalized)"

        Settings.shared.save()
        settingsWindow?.close()
    }

    @objc private func cancelSettings() {
        settingsWindow?.close()
    }

    // MARK: - File Chooser

    private func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            return url.path
        }
        return nil
    }
}

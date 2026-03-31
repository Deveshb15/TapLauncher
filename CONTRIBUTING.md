# Contributing to TapLauncher

## Prerequisites

- macOS 14.0+ on Apple Silicon
- Swift 5.9+ (ships with Xcode 15+)
- `sudo` access for testing (IOKit HID requires root)

## Development Setup

```bash
git clone https://github.com/Deveshb15/TapLauncher.git
cd TapLauncher
swift build          # Debug build
make run             # Build .app bundle and run with sudo
```

## Project Structure

```
TapLauncher/
├── Package.swift                  # SPM manifest
├── Makefile                       # Build, bundle, DMG, release targets
├── Info.plist                     # macOS app bundle metadata
├── Sources/TapLauncher/
│   ├── main.swift                 # Entry point, root check, NSApp setup
│   ├── AppDelegate.swift          # Menu bar, settings window, wiring
│   ├── Accelerometer.swift        # IOKit HID accelerometer access
│   ├── TapDetector.swift          # Signal processing + tap pattern detection
│   ├── AudioPlayer.swift          # Sound playback with escalation logic
│   ├── AppLauncher.swift          # Launch apps as real user via launchctl
│   ├── Settings.swift             # JSON config persistence
│   └── Resources/audio/           # Bundled MP3 sound packs
│       ├── pain/                  # 10 clips
│       ├── sexy/                  # 60 clips (escalation)
│       ├── halo/                  # 9 clips
│       └── lizard/                # 1 clip
```

## Tap Detection Pipeline

```
IOKit HID (BMI286 @ ~100Hz)
    → High-pass filter (removes gravity)
    → Spike detection (amplitude threshold + debounce)
    → State machine (single/double tap discrimination)
    → Actions (app launch + audio playback)
```

## Adding a New Sound Pack

1. Create a directory under `Sources/TapLauncher/Resources/audio/` (e.g., `robot/`)
2. Add numbered MP3 files (`00.mp3`, `01.mp3`, ...)
3. Add a case to `SoundMode` in `Settings.swift`:
   ```swift
   enum SoundMode: String, Codable, CaseIterable {
       case pain, sexy, halo, lizard, robot, custom, none
   }
   ```
4. If it should escalate (like sexy/lizard), add it to the escalation switch in `AudioPlayer.swift`
5. The settings popup auto-populates from `SoundMode.allCases`

## Pull Requests

1. Fork the repo and create a branch
2. Make your changes
3. Test with `make run` on an Apple Silicon Mac
4. Submit a PR with a clear description of what changed and why

## Reporting Issues

Open an issue with:
- macOS version and Mac model
- Steps to reproduce
- Expected vs actual behavior

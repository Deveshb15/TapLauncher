# TapLauncher

A macOS menu bar app that detects physical taps on your Apple Silicon MacBook and launches apps based on tap patterns. Tap once to open one app, tap twice to open another. Optionally plays sound effects when you tap.

## Features

- **Single & double tap detection** — configure different apps for each pattern
- **Sound effects** — plays audio responses on tap (multiple modes)
- **Menu bar app** — lives in your status bar, stays out of the way
- **Configurable sensitivity** — adjust detection threshold, tap window, and cooldown
- **Escalation modes** — rapid tapping plays progressively intense sounds

## Requirements

- **Apple Silicon Mac** (M1 Pro, M2, M3, M4 — any Apple Silicon with accelerometer)
- **macOS 14.0** (Sonoma) or later
- **sudo / root access** — required for IOKit HID accelerometer access

## Installation

### Download DMG

1. Download the latest `.dmg` from [Releases](https://github.com/Deveshb15/TapLauncher/releases)
2. Open the DMG and drag `TapLauncher.app` to Applications
3. Remove the quarantine flag (app is not code-signed):
   ```bash
   sudo xattr -cr /Applications/TapLauncher.app
   ```
4. Run from terminal (requires sudo for accelerometer access):
   ```bash
   sudo /Applications/TapLauncher.app/Contents/MacOS/TapLauncher
   ```

### Build from Source

```bash
git clone https://github.com/Deveshb15/TapLauncher.git
cd TapLauncher
make bundle
sudo TapLauncher.app/Contents/MacOS/TapLauncher
```

## Usage

1. **First launch** — the Settings window opens automatically
2. **Configure tap actions** — click "Choose..." to select apps for single and double tap
3. **Pick a sound mode** — select from the dropdown (or "None" for silent)
4. **Save** — settings persist across restarts
5. **Tap your MacBook** — the configured apps will open and sounds will play

After first setup, TapLauncher runs silently in the menu bar. Click the hand icon to access settings or quit.

## Sound Modes

| Mode | Description |
|------|-------------|
| **Pain** | 10 random pain/protest sounds (default) |
| **Sexy** | 60 clips that escalate in intensity the more you tap |
| **Halo** | 9 Halo video game death sounds |
| **Lizard** | Lizard sound with escalation |
| **Custom** | Your own MP3 files from any directory |
| **None** | Silent — just launches apps |

Escalation modes (Sexy, Lizard) track your tapping frequency over a rolling window. Rapid tapping progressively selects more intense sounds. The score decays with a 30-second half-life.

## Sensitivity Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Sensitivity | 0.05 | 0.01–0.30 | Minimum acceleration (in g) to detect a tap. Lower = more sensitive |
| Tap window | 400ms | 200–800ms | Time window to detect a second tap for double-tap |
| Cooldown | 750ms | 300–2000ms | Minimum time between detected taps |

## How It Works

TapLauncher reads the Bosch BMI286 accelerometer on Apple Silicon Macs via IOKit HID. The detection pipeline:

1. **Accelerometer** — reads raw sensor data at ~100Hz via IOKit HID callbacks
2. **High-pass filter** — removes gravity bias (alpha=0.95)
3. **Spike detection** — triggers when filtered magnitude exceeds threshold
4. **Pattern recognition** — state machine distinguishes single vs double taps
5. **Action** — launches configured app and plays sound

## Building

```bash
make build      # Compile Swift binary
make bundle     # Build .app bundle
make dmg        # Create .dmg installer
make run        # Build + run with sudo
make install    # Install to /Applications
make clean      # Remove build artifacts
```

## Configuration

Settings are stored at `~/.config/taplauncher/config.json`:

```json
{
  "singleTapAppPath": "/Applications/Safari.app",
  "doubleTapAppPath": "/Applications/Terminal.app",
  "soundMode": "pain",
  "minAmplitude": 0.05,
  "doubleTapWindow": 0.4,
  "cooldown": 0.75,
  "isEnabled": true
}
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Credits

- Audio files and accelerometer approach inspired by [spank](https://github.com/taigrr/spank)
- Accelerometer detection algorithms based on [apple-silicon-accelerometer](https://github.com/olvvier/apple-silicon-accelerometer)

## License

[MIT](LICENSE)

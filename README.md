# BoltLauncher

A tiny macOS **menu bar app launcher** with **global hotkeys**.

- Add any `.app`
- Record a global hotkey for it
- Press the hotkey (or click in the menu bar) to **toggle** the app:
  - if the app is frontmost → **hide** it
  - otherwise → **launch/activate** it
- Optional **Launch at login**
- Tracks launch count

> This project is currently **unsigned / not notarized** (free distribution). macOS Gatekeeper may block the first launch.

## Download

Go to **Releases** and download one of:

- `BoltLauncher-vX.Y.Z.zip`
- `BoltLauncher-vX.Y.Z.dmg`

## Install

1. Download the zip/dmg from Releases
2. Drag `BoltLauncher.app` to `/Applications`
3. Launch it — it will appear in the **menu bar** (no Dock icon)

### Gatekeeper (first launch)

If macOS says it can’t be opened because the developer cannot be verified:

- Try **right click → Open** on `BoltLauncher.app` once, OR
- Go to **System Settings → Privacy & Security** and click **Open Anyway**

## Usage

- Click the menu bar icon to open the menu
- Click **Settings…**
  - **Add App…** to pick an application
  - Click **Record Hotkey** then press your desired shortcut
  - Enable **Launch at login** if you want

## Build from source

Requirements:

- macOS 13+
- Xcode 15+

Build:

```bash
xcodebuild -project MacAppLauncher.xcodeproj \
  -scheme MacAppLauncher \
  -configuration Release \
  -derivedDataPath build
```

The built app will be in `build/Build/Products/Release/`.

## Data storage

BoltLauncher stores configuration in a local SQLite database:

`~/Library/Application Support/MacAppLauncher/launcher.sqlite`

## License

MIT

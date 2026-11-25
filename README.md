# EjectBar

EjectBar is a small native macOS menu-bar utility for ejecting external disks before sleep and optionally remounting them after wake.

## Run

Requires macOS 13 or later and the Swift toolchain:

```sh
swift run
```

The app stays in the menu bar and does not show a Dock icon. Its menu lists mounted external volumes, offers individual and bulk eject controls, and exposes the sleep and wake preferences. The same preferences are available in **Settings**.

## Behavior and limitations

- Ejection and remounting use macOS Disk Arbitration. A volume that is busy or in use may refuse to eject; close files and applications using it before retrying.
- Eject-before-sleep is best-effort: macOS may continue entering sleep before the asynchronous eject operation finishes.
- Only disks ejected by the automatic pre-sleep action are queued for remount. A disk must still be connected after wake for macOS to remount it.
- The package builds a native SwiftUI executable. Creating a distributable signed `.app` bundle requires an Xcode project or a separate packaging/signing step.

## Test

```sh
swift test
```

The test target uses XCTest; if it is unavailable in the active Swift toolchain, select a full Xcode installation before running tests.

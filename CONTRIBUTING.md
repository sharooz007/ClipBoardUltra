# Contributing to ClipBoardUltra

Thank you for your interest in contributing to **ClipBoardUltra**! We welcome bug reports, design ideas, feature requests, and code contributions.

## Guiding Principles

1. **Native Performance First**: Zero Electron, zero web views. Pure Swift and AppKit. Memory usage under 40 MB, zero idle CPU, instant keyboard response.
2. **Tactile Industrial Aesthetic**: The UI follows a physical desk instrument metaphor (perforated paper roll, tactile keycaps with travel, amber LED readouts). Keep this design language consistent across all new features.
3. **100% Offline & Private**: Zero network connections, zero telemetry, zero analytics. Everything is stored locally on the user's Mac in `~/Library/Application Support/ClipBoardUltra/`.
4. **Keyboard-Driven**: Every action must be executable via keyboard without requiring mouse interaction.

---

## Local Development Setup

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15+ or Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9 or later
- Optional (for packaging DMG): Homebrew and `create-dmg` (`brew install create-dmg`)

### Building the Project

Clone the repository and run the build script:

```bash
git clone https://github.com/sharooz007/ClipBoardUltra.git
cd ClipBoardUltra

# Build, sign locally, install to /Applications and launch
./scripts/build.sh

# Build without auto-launching
NO_LAUNCH=1 ./scripts/build.sh
```

> **Note on Accessibility Permission**:
> The `scripts/build.sh` script automatically creates a dedicated local code-signing identity in `~/Library/Keychains/clipboardultra-signing.keychain-db`. This ensures macOS remembers your Accessibility permission across rebuilds so you don't have to re-grant it every time you recompile.

### Building via Swift Package Manager

You can also build the CLI binary using standard SwiftPM:

```bash
swift build -c release
```

### Packaging the Installer DMG

To create a release-ready, styled `.dmg` installer with HiDPI Retina graphics:

```bash
./scripts/create_dmg.sh
```

This outputs `ClipBoardUltra.dmg` at the repository root.

---

## Project Structure

```
ClipBoardUltra/
├── Sources/
│   └── ClipBoardUltra/
│       ├── App/            # Entry point (main.swift) & NSApplicationDelegate
│       ├── Core/           # Clipboard polling, SQLite/JSON persistence, hotkeys, auto-paste
│       └── UI/             # Overlay panel, custom keycaps, theme tokens, preview screen
├── Resources/              # App icon, logo, Info.plist
├── scripts/                # Build, icon generation, DMG packaging
├── docs/                   # Documentation and visual assets
├── Package.swift           # Swift Package Manager manifest
└── README.md
```

---

## Pull Request Guidelines

1. **Fork and branch**: Create a feature branch off `main` (e.g. `feat/syntax-highlighting` or `fix/overlay-blur`).
2. **Keep PRs focused**: Address a single feature or bug fix per pull request.
3. **Preserve Privacy**: Ensure no network calls or telemetry are introduced.
4. **Test Thoroughly**:
   - Verify keyboard navigation (arrow keys, return, tab, escape).
   - Test auto-pasting in standard macOS apps (Notes, Terminal, Safari, TextEdit).
   - Ensure the app builds without warnings with `swift build`.
5. **Open a Pull Request**: Provide a clear summary of your changes, the motivation, and screenshots or GIFs if UI changes were made.

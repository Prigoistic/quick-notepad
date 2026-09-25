# Quick Notepad

A tiny floating notepad for macOS. Press `Cmd+Shift+N` from anywhere — any app,
any desktop Space, even a fullscreen browser tab — and a small text panel pops
up. Type, hit `Cmd+Enter` (or click Save), and it's appended into a single
"Quick Capture" note in Apple Notes with a timestamp.

No App Store install, no third-party app. It's a small Swift program that
runs quietly in the background and starts automatically at login.

## Requirements

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`)

## Build & install

```bash
./Scripts/build-app.sh   # builds QuickNotepad.app
./Scripts/install.sh     # installs to ~/Applications and starts it at login
```

## Usage

- `Cmd+Shift+N` — open/hide the panel
- `Cmd+Enter` — save into Notes
- `Escape` — hide without saving (your text isn't lost)

## Development

```bash
swift build --toolset Toolset.json
swift test --toolset Toolset.json
```

`Toolset.json` points the compiler at this machine's Swift Testing plugin
path — a workaround for running `swift test` without a full Xcode install.

See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design
spec and implementation plan.

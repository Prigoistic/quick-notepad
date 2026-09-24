# Quick Notepad — Design

## Problem

macOS's built-in Quick Note (Fn+Q / hot corner) is unreliable over fullscreen apps and other
Spaces (jumps to Desktop instead of overlaying, and has had input-focus glitches where typing
doesn't register). We're building a minimal replacement: a global-hotkey floating notepad that
reliably overlays any app/Space and saves into Apple Notes.

## Goals

- `Cmd+Shift+N` opens a small floating text panel from anywhere — any desktop Space, any
  fullscreen app (browser, WhatsApp, PDF viewer, etc.) — without switching Spaces or stealing
  focus from the underlying app more than necessary.
- Typing works immediately on open, no extra click needed.
- Saving appends the note into a single running Apple Notes note titled "Quick Capture",
  with a bold date-time subheading per entry. Existing content is never overwritten.
- Runs quietly in the background, auto-starting at login. No App Store install, no
  third-party app — a small program we build and the user owns.

## Known limitation

AppleScript has no true "append" operation for a Notes body — saving reads the note's
current HTML body, concatenates the new block, and writes the whole thing back. For a
plain-text capture note this is fine, but if you ever manually add an image, checklist,
or table to the "Quick Capture" note, a save from Quick Notepad can drop that formatting
on the write-back. Keep "Quick Capture" as plain text only if this matters to you.

## Non-goals

- Rich text formatting in the capture panel itself (plain text in, formatted subheading is
  the only structure added).
- Multi-note support, folders, tagging, or search — single running note only.
- Cross-platform support — macOS only.

## Architecture

Single Swift/AppKit app, `QuickNotepad`, built as a background agent (`LSUIElement = true`,
no Dock icon), auto-started via a LaunchAgent plist.

### Components

- **HotkeyManager** — registers `Cmd+Shift+N` globally via Carbon's `RegisterEventHotKey`.
  Chosen over an `NSEvent` global monitor because it doesn't require Accessibility
  permissions and fires reliably system-wide, including over fullscreen apps.
- **NotepadPanel** — an `NSPanel`:
  - Style: borderless, `.nonactivatingPanel`.
  - Collection behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary` — lets it
    render on top of the active Space/fullscreen app without switching the user away from it.
  - Level: floating.
  - Contains a single `NSTextView`, auto-focused as first responder on show.
- **NotesBridge** — runs an `NSAppleScript` script against the Notes app to perform the save
  (see Data flow below).
- Minimal menu bar item (status bar icon) for Quit — the only persistent UI surface.

## Data flow: open → type → save

1. User presses `Cmd+Shift+N` anywhere. HotkeyManager's callback shows NotepadPanel and makes
   its NSTextView first responder. Any previously-unsaved text from the last session is
   restored into the view (nothing is lost between opens).
2. User types. `Cmd+Enter` triggers save; `Escape` hides the panel (text is retained in memory
   for next open, not discarded).
3. On save, NotesBridge invokes AppleScript that:
   a. Looks up a note titled "Quick Capture" in the default Notes account; creates it if
      absent.
   b. Appends to the end of its body: a bold subheading with the current date/time
      (e.g. "Sep 24, 2026 · 3:41 PM"), followed by the typed text as a new paragraph.
   c. Never rewrites or reorders existing content — append-only.
4. On success: panel's text view is cleared and the panel hides.
5. On failure (Notes not running/signed in, note deleted mid-flight, AppleScript error): the
   panel stays open, text is preserved untouched, and a small inline error label appears in
   the panel with the failure reason. User can retry save or copy text out manually.

## Repo layout

```
quick-notepad/
  Package.swift
  Sources/QuickNotepad/
    main.swift
    HotkeyManager.swift
    NotepadPanel.swift
    NotesBridge.swift
  Scripts/
    build-app.sh      # swift build + assemble QuickNotepad.app bundle + Info.plist
    install.sh         # copies .app to /Applications (or ~/Applications) + installs LaunchAgent plist
  LaunchAgent/
    com.priyam.quicknotepad.plist
  docs/superpowers/specs/
    2026-09-24-quick-notepad-design.md
```

Built with Swift Package Manager (no Xcode project required). `Scripts/build-app.sh` compiles
the executable and wraps it into a proper `.app` bundle (with `Info.plist` setting
`LSUIElement = true`) so macOS treats it as a backgrounded, no-Dock-icon agent.

## Error handling

- AppleScript/Notes failures never destroy unsaved text — the panel keeps it until a save
  actually succeeds.
- If the global hotkey fails to register (e.g., conflict with another app), the app logs to
  a file (`~/Library/Logs/QuickNotepad.log`) and the menu bar icon shows a warning state.
- If Notes.app isn't running, NotesBridge's AppleScript launches it first (`tell application
  "Notes" to activate` before the note lookup) so save doesn't silently fail just because
  Notes wasn't open.

## Testing (manual — this is a UI/system-integration tool, not unit-testable business logic)

- [ ] `Cmd+Shift+N` opens the panel over a fullscreen browser window without switching Spaces.
- [ ] `Cmd+Shift+N` opens the panel while on a different Space (e.g. a fullscreen PDF/WhatsApp).
- [ ] Typing registers immediately on open, no click required.
- [ ] `Cmd+Enter` saves, appends correctly under a new date-time subheading, and does not
      alter prior note content.
- [ ] Saving when the "Quick Capture" note has been deleted recreates it correctly.
- [ ] Saving when Notes.app is not running launches it and still saves correctly.
- [ ] `Escape` hides the panel without saving, and reopening restores the unsaved text.
- [ ] App auto-launches after logout/login (LaunchAgent verification).

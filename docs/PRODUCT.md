# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos (native AppKit + SwiftUI; menu-bar accessory app, no Dock icon)

## Users
The owner-developer, working on a Mac all day across editors, browsers, terminals and chat apps. They summon the clipboard history mid-task, pick a clip, and expect it pasted into the field they were just typing in. (Inferred from the codebase and the user's request; not interviewed.)

## Product Purpose
A fast, keyboard-first clipboard history: text, code, images, files and recent screenshots in one floating panel. Success = hotkey → pick → Enter → content appears in the previous app, with no manual ⌘V.

## Positioning
Local-only, lightweight clipboard manager that also surfaces the Mac's own screenshot folder alongside copied items.

## Operating Context
- Summoned with ⌥⌘V (user choice) over any app, including full-screen spaces.
- Used in bursts of a few seconds; keyboard navigation is the primary path, mouse is secondary.
- Starts automatically at login (user requirement).

## Capabilities and Constraints
- Needs macOS Accessibility permission to post the ⌘V keystroke.
- History stored locally in ~/Library/Application Support/ClipBoardUltra; password-manager (concealed) clips are ignored.
- macOS 13+; built with swiftc via scripts/build.sh (SwiftPM currently broken on this machine's toolchain).

## Brand Commitments
- Name: ClipBoardUltra. No prior logo existed (the previous icon was never wired into Info.plist); a new logo is requested.

## Product Principles
1. The paste must land — reliability beats features.
2. Keyboard first; every action has a key.
3. Get out of the way: open instantly, close the moment the job is done.
4. Private by default: nothing leaves the Mac.

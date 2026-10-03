# Design

The overlay looks like a desk instrument that prints your clipboard. The history is a roll of paper coming out of a slot, actions are physical keycaps, live state shows on an amber readout, and one safety-orange key is reserved for Paste. Tokens live in `Sources/ClipBoardUltra/UI/Theme.swift`.

## Palette
| Role | Token | Hex |
|---|---|---|
| Chassis (gradient top → body) | `chassisTop`, `chassis` | #2A2D31 → #1E2023 |
| Recessed wells (search, slot) | `chassisLow` | #141517 |
| Preview screen, readouts | `screen` | #101113 |
| Legends on chassis | `bone` / `boneDim` | #E3E0D7 / #A6A49D |
| Paper roll / hover | `paper` / `paperShade` | #E9ECE7 / #DCE0DA |
| Ink on paper | `ink` / `inkFaded` | #1C1F23 / #555A62 |
| Perforation | `perforation` | #AEB3AC |
| Primary action only | `orange` (skirt `orangeDeep`) | #FF6A1A (#C94B0C) |
| Live state (count, metadata, lit key LED) | `amber` | #FFB547 |

Orange is used for Paste, for confirming destructive actions, and for the "auto-paste off" signal. Nothing else is orange.

## Type
- UI text uses SF Pro. Metadata, counts, key legends and code use SF Mono, because they are measurements or code.
- Titles are 13–14 pt semibold or medium. Metadata is 10 pt mono uppercase, joined with " · ".

## Components
- **Keycap** (`KeycapStyle`) comes in three tones: graphite (default), bone (secondary action) and orange (primary). Each has a darker skirt under a lighter face, and the face travels 1.5–2 pt when pressed. When a graphite key is "lit" (the selected filter or a pinned state), it shows an amber LED dot.
- **Slip** (`ClipRowView`) is one row on the paper roll.
  - The first nine rows show a `⌘1`–`⌘9` key outline.
  - A selected row prints in reverse: paper-colored text on an ink ground.
  - Rows are separated by a dashed perforation line.
- **Slot** is the dark bar the roll feeds from. Its lip casts a 10 pt shadow onto the paper.
- **Readout** is an amber mono counter on the screen color. When recording is paused, "PAUSED" shows under it in orange.
- **Settings window** uses the same chassis. Tabs are keycaps (the active tab is lit), section titles are amber mono caps, and each group of rows sits on a recessed screen panel with hairline dividers. Native switches and menus are tinted orange. Destructive buttons use a two-step graphite → orange "…?" confirmation instead of a modal dialog.

## Motion
New slips slide down from the slot (0.2 s ease-out). With Reduce Motion on, they cross-fade instead. Keycap travel takes 0.07 s. There is no other motion.

## Logo
`scripts/generate_icon.swift` draws the logo: a torn slip feeding from a gunmetal slot, with an orange key and an amber status light. The menu bar glyph (`MenuBarGlyph`) is a template-image version of the same shape.

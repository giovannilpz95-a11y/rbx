# UiTheme

The shared look for every screen in the game: palette, fonts, chunky buttons, windows, HUD pills,
bars, badges, toasts, in-world bubbles and bouncy motion. The design reference is the vault note
`Design/25 UI Style Guide`.

Rojo maps `uitheme/src` to `ReplicatedStorage.UiTheme` (see `farm/default.project.json`).

```lua
local UiTheme = require(ReplicatedStorage:WaitForChild("UiTheme"))
local button = UiTheme.Kit.button("Collect", "primary", { Parent = frame })
UiTheme.Kit.skinButton(existingTextButton, "danger")
local window = UiTheme.Kit.panel(onClose) -- window.root, .title, .close, .body
```

Farm UI code should use the `Ui` helpers in `farm/src/client/UI/Ui.luau`, which wrap this module.
Formatting is checked by the farm CI (`stylua --check ../uitheme`), and the farm tests compile
every file here and test `Palette` and `Format`.

## Parts for the bigger screens

Added for the UI gaps in the vault note `Design/UI Reference & Gaps` (G13):

| Part | What it is |
|---|---|
| `Kit.tabs(names, selected, onSelect, props?, badges?)` | A row of 44 px tabs; the picked one is blue. Rebuild on every render. |
| `Kit.stepper(value, min, max, onChange, props?)` | − value + for picking a quantity; the ends grey out. |
| `Kit.needChip(have, need, props?)` | An icon slot and "have/need", red when short, green with a tick when covered. |
| `Kit.portrait(look, size, name?, props?)` | A peg-folk face (skin, hat colour, hat style) in a round frame, with an optional name plate. |
| `Kit.iconBubble(props?)` + `Kit.setIconBubble(bubble, count)` | A round ready bubble with a picture slot and a count, for BillboardGuis. |
| `Kit.edgeIcon(glyph, props?)` + `Kit.setEdgeTimer(edge, text)` | A round screen-edge icon with a countdown and a red dot. |
| `Kit.onTap(button, fn)` | Runs `fn` once per tap, on the press, so a window refresh can't swallow it. |
| `Motion.flyTo(gui, from, to, onArrive?)` | A reward icon flying to its HUD counter; instant with Reduce Motion. |

Crop Pop's `tests/theme.spec.luau` smoke-tests every part against its Roblox mock.

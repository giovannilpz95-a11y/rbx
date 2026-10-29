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

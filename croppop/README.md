# Crop Pop

The match-3 side game for the farm (design: `Design/Features/F12 Crop Pop Puzzle` in the vault). This folder has the board engine, a server replay check, Hearts and boosters, and a simple ScreenGui board with 5 test levels.

## Layout

`default.project.json` is a Rojo project. Without Rojo, copy the scripts into Studio like this:

| Folder | Goes to | What's in it |
|---|---|---|
| `src/shared` | `ReplicatedStorage.CropPop` (a ModuleScript from `init.luau`, the other files are its child ModuleScripts) | The engine: `Board`, `Matcher`, `Engine`, `Goals`, `Rng`, `Tiles`, `Levels`, `Replay`, `Hearts`, `Boosters` |
| `src/server` | `ServerScriptService.CropPopServer` (Folder) | `CropPopService` (Script) and `RunStore` (ModuleScript) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.CropPopClient` (Folder) | `Main` (LocalScript), `PuzzleScreen`, `BoardView`, `TileStyle` (ModuleScripts) |

`tests/` and `tools/` only run outside Studio.

## Playing it in Studio

Press Play and click the **🍅 Crop Pop** button in the bottom-left. Pick a level from the Crop Pop Trail, pick any start boosters, and press Play. Swipe a tile, or tap one tile and then a neighbour. The booster bar (🪏 🧹 🧤 🔀) sits under the board, or in the side panel on a wide screen: tap one, then tap the board. In Studio every test level is unlocked; live servers unlock them in order.

The button is temporary. The Puzzle Porch and the Town Square cabinet should call `PuzzleScreen.open()` (or `open(levelId)`) instead.

## How it fits together

- **Engine** (`Engine.new(level, seed, options)`, then `trySwap(x1, y1, x2, y2)`) runs the whole move: the swap, matches, power-ups, cascades, refills and a shuffle if the board is stuck. It returns phases (`Swap`, `Pop`, `Drop`, `Shuffle`) that `BoardView` animates.
- **Rules (first-pass):** a line of 3+ or a 2x2 square matches. 4 in a line makes a **Seed Sprayer** (a row of 4 clears a row, a column of 4 a column), a 2x2 square makes a **Bumblebee**, a T or L makes a **Hay Bomb** (clears a diamond 2 steps out), 5 in a line makes a **Sunflower**. Swapping two power-ups combines them; a Sunflower swapped with a tile clears that colour.
- **Obstacles and goals:** holes in the board shape, **mud** under tiles (1 or 2 layers) and **hay bales** (1 to 3 layers, hit by neighbouring matches and blasts). Goals: collect N of a tile, clear all mud, break all hay bales.
- **Determinism:** every random choice comes from `Rng` (xorshift32) seeded by the server, so the same seed and swaps always give the same board.
- **Anti-cheat:** `StartLevel` gives the client a seed and a token. When the level ends, the client sends its swaps to `FinishLevel`; the server replays them and only fires `ServerStorage.CropPopLevelWon(player, levelId, rewards, firstWin)` if the replay wins. The farm economy should listen to that event to pay Coins and XP.
- **Hearts:** 5 at most, one back every 30 minutes, even offline. Starting a level holds a heart and a win gives it back, so only losses (and quitting) cost one. When they're all gone, a full refill costs 36 Gems (Township's 5 lives for 900 T-cash, rescaled).
- **Boosters:** before a level, Sprayer Start, Bomb Start and Sunflower Start put that power-up on the starting board; they're charged when the level starts. During a level, the Trowel breaks one tile or bale layer, the Rake clears a row, Garden Gloves swap any two neighbours without needing a match, and Shake-Up shuffles. They don't cost a move, go into the action list with the swaps, and are charged after the server's replay. New players get 2 of each. Spends over 10 Gems ask "Spend X Gems?" first and go through on a second tap. Prices follow Township's (its boosters come in 3s, so per booster after the T-cash rescale), apart from Sprayer Start and Garden Gloves, which are first-pass.
- **Saving and Gems:** the farm owns the save. It calls `ServerStorage.CropPopLoadSave(player, puzzleBlock)` when the profile loads and reads `CropPopGetSave(player)` before each save. Until the save loads, levels can't start (Studio without the farm falls back to a fresh state after 10 seconds). Buying calls the farm's `CropPopSpendGems(player, amount, reason)`.
- **Levels** are Luau tables in `Levels.luau` (layout strings, colours, goals, moves, rewards). The Studio level editor (P2) will write the same format.

## Not in yet

Paid +5-move continues (`Engine:addMoves`), Hot Streak, Unlimited Hearts rewards (the timer is in `Hearts`), the other obstacles, the level editor and real tile art.

## Tests

From this folder:

```sh
cargo run --release --manifest-path tools/luaurun/Cargo.toml -- tests/run.luau
```

`tools/luaurun` is a tiny Luau host (Rust + mlua). The runner builds a fake instance tree the way Rojo would, so the modules keep their normal `require(script.Parent.X)` calls. The specs cover the rules, gravity, every combo, goals, 1,000 random runs replayed to the same state, every booster (and 200 random runs mixing boosters and swaps), Hearts timing, the server's run checks, shop and saves, and a play-through of all 5 levels on the real client code against a small mock of the Roblox API. CI runs them on every push that touches `croppop/`.

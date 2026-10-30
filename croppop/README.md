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

Press Play and click the **🍅 Crop Pop** button in the bottom-left (Studio only; in the game the Puzzle Porch cabinet in the Town Square opens it). Pick a level from the Crop Pop Trail, pick any start boosters, and press Play. Swipe a tile, or tap one tile and then a neighbour. The booster bar (⛏️ 🧹 🧤 🔀) sits under the board, or in the side panel on a wide screen: tap one, then tap the board. In Studio every test level is unlocked (live servers unlock them in order), and **Dev: 1 move** (or the L key) jumps to the last move. That jump goes in the action list and the Studio server's replay accepts it, so you can test buying continues; live servers refuse it. **Dev: 0 hearts** on the Trail (or the H key) empties your hearts so the refill offer shows.

The farm opens the screen by firing `ReplicatedStorage.CropPopOpen`, a client-side BindableEvent. Whichever client script runs first creates it (`FindFirstChild`, or else a new `BindableEvent` with that name).

## How it fits together

- **Engine** (`Engine.new(level, seed, options)`, then `trySwap(x1, y1, x2, y2)`) runs the whole move: the swap, matches, power-ups, cascades, refills and a shuffle if the board is stuck. It returns phases (`Swap`, `Pop`, `Drop`, `Shuffle`) that `BoardView` animates.
- **Rules (first-pass):** a line of 3+ or a 2x2 square matches. 4 in a line makes a **Seed Sprayer** (a row of 4 clears a row, a column of 4 a column), a 2x2 square makes a **Bumblebee**, a T or L makes a **Hay Bomb** (clears a diamond 2 steps out), 5 in a line makes a **Sunflower**. Swapping two power-ups combines them; a Sunflower swapped with a tile clears that colour.
- **Obstacles and goals:** holes in the board shape, **mud** under tiles (1 or 2 layers), **hay bales** (1 to 3 layers, hit by neighbouring matches and blasts), **frost** over a tile (1 or 2 layers: the tile is frozen in place and can't be swapped, but still matches; each match or blast through it breaks a layer and the tile stays), **weeds** (block a cell like a 1-layer bale; after any swap that pulls no weed, one spreads onto a plain tile next to a weed), and **pumpkins** (they never match and blasts can't break them; they fall and swap like tiles, and one that reaches the bottom cell of its column, marked ⬇️, is collected; refills drop new ones until enough are on the way, as many at once as the layout starts with), and **clover** (grows on cells: a match with a tile on clover plants it on every cell of the match, and a power-up going off on clover, or a combo with either piece on it, plants it everywhere it hits). Goals: collect N of a tile, clear all mud, break all hay bales, break all frost, pull all weeds (a spread adds one to pull), bring N pumpkins down, grow clover on every cell.
- **Determinism:** every random choice comes from `Rng` (xorshift32) seeded by the server, so the same seed and swaps always give the same board.
- **Anti-cheat:** `StartLevel` gives the client a seed and a token. When the level ends, the client sends its swaps to `FinishLevel`; the server replays them and only fires `ServerStorage.CropPopLevelWon(player, levelId, rewards, firstWin)` if the replay wins. The farm economy should listen to that event to pay Coins and XP.
- **Hearts:** 5 at most, one back every 30 minutes, even offline. Starting a level holds a heart and a win gives it back, so only losses (and quitting) cost one. When they're all gone, a full refill costs 36 Gems (Township's 5 lives for 900 T-cash, rescaled).
- **Boosters:** before a level, Sprayer Start, Bomb Start and Sunflower Start put that power-up on the starting board; they're charged when the level starts. During a level, the Trowel breaks one tile or bale layer, the Rake clears a row, Garden Gloves swap any two neighbours without needing a match, and Shake-Up shuffles. They don't cost a move, go into the action list with the swaps, and are charged after the server's replay. New players get 2 of each. Spends over 10 Gems ask "Spend X Gems?" first and go through on a second tap. Prices follow Township's (its boosters come in 3s, so per booster after the T-cash rescale), apart from Sprayer Start and Garden Gloves, which are first-pass.
- **Continues:** running out of moves offers +5 moves for Gems: 10, then 20 (with a Seed Sprayer), 35, then 50 each (with a Hay Bomb), up to 10 per run. The price is on the button, there's no countdown, and "Give up" ends the level. The server replays the run before selling one (it has to be out of moves), and the final replay can't use more continues than were paid for. Township's first continue was 10 T-cash; the later steps are first-pass.
- **Hot Streak:** win levels in a row and the next level starts with free power-ups: a Seed Sprayer after 1 win, plus a Hay Bomb after 2, plus a Sunflower from 3. A loss or leaving a level part-way ends it (the X asks first). The streak is in the save, and a save made mid-level stores 0, so dropping out ends it too.
- **Trail Chests:** beating every 10th level for the first time opens a 🎁 Trail Chest (`TrailChest.luau`): Coins (100, then 20 more per chest), one pre-level and one or two in-level boosters (rotating), and 15 minutes of Unlimited Hearts (30 on every 3rd chest). Contents are fixed, never random. The server pays it after the replay check; its Coins go into the `CropPopLevelWon` rewards (as `rewards.chestCoins` too). First-pass numbers.
- **Heart gifts:** neighbors send each other hearts from the farm's Neighbors panel. The farm checks that they're neighbors, then calls `ServerStorage.CropPopGiftHeart:Invoke(fromPlayer, toUserId)`, which returns `(ok, message)`; the message is for the sender. `CropPopHeartGiftStatus:Invoke(player)` returns `{ sentTo, left, perDay }` for greying out buttons. Each player can send 10 a day, one per neighbor. Gifts wait in a gift box (the `CropPopHeartGifts` DataStore, so they reach players who are offline or on another server; in memory in Studio). The Trail shows a **🎁 Claim** button that moves them into empty hearts, at most 5 a day. A box holds 20, and gifts expire after 7 days. Township lets co-op members send lives but gives no numbers, so these are first-pass (`Hearts.Gifts`).
- **Not enough Gems:** if the farm shares the balance (`ServerStorage.CropPopGetGems(player)`), offers the player can't afford are greyed with "Not enough 💎" before any tap. Without it, the same state shows after a charge fails.
- **Saving and Gems:** the farm owns the save. It calls `ServerStorage.CropPopLoadSave(player, puzzleBlock)` when the profile loads and reads `CropPopGetSave(player)` before each save. Until the save loads, levels can't start (Studio without the farm falls back to a fresh state after 10 seconds). Buying calls the farm's `CropPopSpendGems(player, amount, reason)`.
- **Levels:** 150 of them, as Luau tables (layout strings, colours, goals, moves, rewards) in `Levels/Set01.luau` to `Set06.luau`, 25 each. Every 5th level is Tough and every 10th from 20 is Super Tough. 2-layer bales come in at level 9, thick mud at 13, frost at 21 (its intro level), 3-layer bales at 26, six tile colours on some hard levels from 30, thick frost at 33, weeds at 41 (its intro level), pumpkins at 101 and clover at 126 (each with its intro level; levels 101–125 and 126–150 are the first two updates after the MVP). Level names that promise an obstacle ("Muddy Boots", "Rolling Bales") get it. The Trail shows the levels you've reached and the next 4 locked ones.

## Making levels

Levels 6 to 150 come from `tools/levelgen.luau`. It builds each one from original shape and obstacle patterns (seeded by the level id, so the same id always gives the same level) and gives it the fewest moves (15 to 35) at which the test bot reaches a target win rate. The bot plays randomly, so its targets read low: 80% on Normal levels up to 12, falling to 50% by level 51; Tough 45% to 32%; Super Tough 25% then 20%. Levels 1 to 5 are hand-made.

```sh
luaurun tools/levelgen.luau 6 150 > levels.txt   # prints each level as Luau, with the bot's win rate
```

Hand changes go through the level editor below; once a level ships, change it there rather than regenerating it.

## Level editor (Studio only)

On the Trail, press **Dev: Editor** (or the F6 key; E is the farm's interact key) in Studio Play mode. Studio unlocks every level; **Dev 🔒** on the Trail shows it locked to your real progress, as a player sees it. **Dev +5🎒** adds 5 of every booster, **Dev 🎁** puts a heart gift from a pretend neighbor in your gift box, and **Dev: 0 hearts** empties the hearts.
- Paint the board with the brushes: cell, hole, mud, double mud, hay bales with 1–3 layers, frost with 1–2 layers, and weeds.
- Set the size, moves, difficulty, tile colours (3–6) and up to 3 goals.
- The status line says what's wrong while the level isn't valid.
- **Test play** plays the level offline, with no hearts, rewards or streak.
- **Bot check** has the test bot (`Bot.luau`) play it 50 times and shows its win rate. The bot plays randomly, so people do better; use it to compare levels.
- **Export** writes the level as Luau (`LevelText.luau`), shown in the box and printed to Output, ready to paste into the level's set file (the editor says which).
- **Load** brings an existing level in to edit.

## Not in yet

The obstacles beyond the MVP's four (crates, chains, honey and the rest in F12), and real tile art.

## Tests

From this folder:

```sh
cargo run --release --manifest-path tools/luaurun/Cargo.toml -- tests/run.luau
```

`tools/luaurun` is a tiny Luau host (Rust + mlua). The runner builds a fake instance tree the way Rojo would, so the modules keep their normal `require(script.Parent.X)` calls. The specs cover the rules, gravity, every combo, goals, 1,000 random runs replayed to the same state, every booster (and 200 random runs mixing boosters and swaps), Hearts timing, the server's run checks, shop and saves, and a play-through of all 5 levels on the real client code against a small mock of the Roblox API. CI runs them on every push that touches `croppop/`.

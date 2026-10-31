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

Press Play and click the **🍅 Crop Pop** button in the top-right (Studio only; in the game the Puzzle Porch cabinet in the Town Square opens it). Pick a level from the Crop Pop Trail, pick any start boosters, and press Play. Swipe a tile, or tap one tile and then a neighbour. The booster bar (⛏️ 🧹 🧤 🔀) sits under the board, or in the side panel on a wide screen: tap one, then tap the board. In Studio every test level is unlocked (live servers unlock them in order), and **Dev: 1 move** (or the L key) jumps to the last move. That jump goes in the action list and the Studio server's replay accepts it, so you can test buying continues; live servers refuse it. **Dev: 0 hearts** on the Trail (or the H key) empties your hearts so the refill offer shows. The J key plays the test bot's next move, for checks without clicks.

The farm opens the screen by firing `ReplicatedStorage.CropPopOpen`, a client-side BindableEvent. Whichever client script runs first creates it (`FindFirstChild`, or else a new `BindableEvent` with that name).

## How it fits together

- **Engine** (`Engine.new(level, seed, options)`, then `trySwap(x1, y1, x2, y2)`) runs the whole move: the swap, matches, power-ups, cascades, refills and a shuffle if the board is stuck. It returns phases (`Swap`, `Pop`, `Drop`, `Shuffle`) that `BoardView` animates.
- **Rules (first-pass):** a line of 3+ or a 2x2 square matches. 4 in a line makes a **Seed Sprayer** (a row of 4 clears a row, a column of 4 a column), a 2x2 square makes a **Bumblebee**, a T or L makes a **Hay Bomb** (clears a diamond 2 steps out), 5 in a line makes a **Sunflower**. Swapping two power-ups combines them; a Sunflower swapped with a tile clears that colour.
- **Obstacles and goals:** holes in the board shape, **mud** under tiles (1 or 2 layers), **hay bales** (1 to 3 layers, hit by neighbouring matches and blasts), **frost** over a tile (1 or 2 layers: the tile is frozen in place and can't be swapped, but still matches; each match or blast through it breaks a layer and the tile stays), **weeds** (block a cell like a 1-layer bale; after any swap that pulls no weed, one spreads onto a plain tile next to a weed), and **pumpkins** (they never match and blasts can't break them; they fall and swap like tiles, and one that reaches the bottom cell of its column, marked ⬇️, is collected; refills drop new ones until enough are on the way, as many at once as the layout starts with), **clover** (grows on cells: a match with a tile on clover plants it on every cell of the match, and a power-up going off on clover, or a combo with either piece on it, plants it everywhere it hits), and **stone walls** (1 or 2 layers, like bales, but neighbouring matches don't touch them: only blasts and the Trowel break them). **Portals** (🌀, a level's `portals` list) link an entrance cell to an exit anywhere on the board: pieces leaving the entrance land in the exit instead of the cell below, nothing falls or spawns into an exit from above, and pumpkins don't leave from an entrance. **Pumpkin baskets** (🧺, `d` in the layout) are gaps in the board that pieces fall past: a match next to one, or a blast reaching it, drops a pumpkin into the cell below (once per basket per wave, while the Pumpkins goal still needs more), and on basket levels refills drop no pumpkins. Goals: collect N of a tile, clear all mud, break all hay bales, break all frost, pull all weeds (a spread adds one to pull), bring N pumpkins down, grow clover on every cell, break all stone walls.
- **Determinism:** every random choice comes from `Rng` (xorshift32) seeded by the server, so the same seed and swaps always give the same board.
- **Anti-cheat:** `StartLevel` gives the client a seed and a token. When the level ends, the client sends its swaps to `FinishLevel`; the server replays them and only fires `ServerStorage.CropPopLevelWon(player, levelId, rewards, firstWin)` if the replay wins. The farm economy should listen to that event to pay Coins and XP.
- **Hearts:** 5 at most, one back every 30 minutes, even offline. Starting a level holds a heart and a win gives it back, so only losses (and quitting) cost one. When they're all gone, a full refill costs 36 Gems (Township's 5 lives for 900 T-cash, rescaled).
- **Boosters:** before a level, Sprayer Start, Bomb Start and Sunflower Start put that power-up on the starting board; they're charged when the level starts. During a level, the Trowel breaks one tile or bale layer, the Rake clears a row, Garden Gloves swap any two neighbours without needing a match, and Shake-Up shuffles. They don't cost a move, go into the action list with the swaps, and are charged after the server's replay. New players get 2 of each. Spends over 10 Gems ask "Spend X Gems?" first and go through on a second tap. Prices follow Township's (its boosters come in 3s, so per booster after the T-cash rescale), apart from Sprayer Start and Garden Gloves, which are first-pass.
- **Continues:** running out of moves offers +5 moves for Gems: 10, then 20 (with a Seed Sprayer), 35, then 50 each (with a Hay Bomb), up to 10 per run. The price is on the button, there's no countdown, and "Give up" ends the level. The server replays the run before selling one (it has to be out of moves), and the final replay can't use more continues than were paid for. Township's first continue was 10 T-cash; the later steps are first-pass.
- **Hot Streak:** win levels in a row and the next level starts with free power-ups: a Seed Sprayer after 1 win, plus a Hay Bomb after 2, plus a Sunflower from 3. A loss or leaving a level part-way ends it (the X asks first). The streak is in the save, and a save made mid-level stores 0, so dropping out ends it too.
- **Trail Chests:** beating every 10th level for the first time opens a 🎁 Trail Chest (`TrailChest.luau`): Coins (100, then 20 more per chest), one pre-level and one or two in-level boosters (rotating), and 15 minutes of Unlimited Hearts (30 on every 3rd chest). Contents are fixed, never random. The server pays it after the replay check; its Coins go into the `CropPopLevelWon` rewards (as `rewards.chestCoins` too). First-pass numbers.
- **Score tracks:** one is always running (`ScoreTracks.luau`, UTC days): **🐝 Bee Parade** Friday to Sunday counts Bumblebees made in won levels (20 steps), and **🌽 Corn Harvest** Monday to Thursday counts Corn tiles cleared (25 steps). Each step pays as soon as it's reached: boosters, Coins, Gems (8 midway, 400 at the end, plus 56 at Corn Harvest step 22), unlimited hearts, **x2 points** for a while, or a **free start booster** that goes on every level while it lasts. Points start over with the next track. The rewards follow Township's Treasure Tree and Green Machine tracks (T-cash / 25 as Gems; building materials paid as 50 Coins each for now); the step costs keep Township's shape but are scaled to what the test bot makes per win, so about 60 wins finish Bee Parade and 80 finish Corn Harvest. The track sits at the top of the Trail (tap it for the steps), and the win panel shows the points and any steps reached. Coins and Gems from steps go out in the `CropPopLevelWon` rewards (`rewards.trackCoins` is included in `coins`; `rewards.gems` is for the farm to pay).
- **Harvest Cup:** a leaderboard competition (`Cup.luau`), three a week on UTC days: Mon–Tue, Wed–Thu and Fri–Sun. Winning a level during a cup enters you into a group of up to 30 players, and each win scores 🏆 cups by difficulty (1 Normal, 3 Tough, 5 Super Tough, as in Township's Mayor's Cup). Reaching 20 cups pays 30 minutes of unlimited hearts. When the cup ends, the top 10 of each group get prizes on their next visit: 1st gets 3 h of unlimited hearts, 3 of each start booster and a Garden Gloves, Shake-Up and Trowel; it steps down to 1 of each start booster for 4th–10th. You only place if someone finished below you. Groups and scores live in data stores shared by every server (`CupBoard.luau`: an entrant count in `CropPopCups`, one OrderedDataStore per group); Studio keeps them in memory, and the 7 and 8 keys add 10 cups or end your cup. Group size and the personal goal are first-pass (Township doesn't publish them).
- **Tractor Race:** a 4-player race on race weekends (`Race.luau`, Friday to Sunday UTC). Your first win puts you in a race with up to 3 others; the first to 15 wins finish in order, and the race is over once 3 have finished. Finishing pays at once: 1st gets 1 h of unlimited hearts, one of each start booster and a Garden Gloves, Shake-Up and Trowel (Township's Farmers' Race prize); 2nd and 3rd step down (first-pass). Your next win starts a new race. Any win counts, so players at the end of the Trail can race too, and you only place if someone else is in your race. Races share the cup's data stores in groups of 4 (`CropPopRace<key>g<group>`); Studio races every day, and the 9 key adds 5 race wins.
- **Heart gifts:** neighbors send each other hearts from the farm's Neighbors panel. The farm checks that they're neighbors, then calls `ServerStorage.CropPopGiftHeart:Invoke(fromPlayer, toUserId)`, which returns `(ok, message)`; the message is for the sender. `CropPopHeartGiftStatus:Invoke(player)` returns `{ sentTo, left, perDay }` for greying out buttons. Each player can send 10 a day, one per neighbor. Gifts wait in a gift box (the `CropPopHeartGifts` DataStore, so they reach players who are offline or on another server; in memory in Studio). The Trail shows a **🎁 Claim** button that moves them into empty hearts, at most 5 a day. A box holds 20, and gifts expire after 7 days. Township lets co-op members send lives but gives no numbers, so these are first-pass (`Hearts.Gifts`).
- **Not enough Gems:** if the farm shares the balance (`ServerStorage.CropPopGetGems(player)`), offers the player can't afford are greyed with "Not enough 💎" before any tap. Without it, the same state shows after a charge fails.
- **Saving and Gems:** the farm owns the save. It calls `ServerStorage.CropPopLoadSave(player, puzzleBlock)` when the profile loads and reads `CropPopGetSave(player)` before each save. Until the save loads, levels can't start (Studio without the farm falls back to a fresh state after 10 seconds). Buying calls the farm's `CropPopSpendGems(player, amount, reason)`.
- **Levels:** 225 of them, as Luau tables (layout strings, colours, goals, moves, rewards) in `Levels/Set01.luau` to `Set09.luau`, 25 each. Every 5th level is Tough and every 10th from 20 is Super Tough. 2-layer bales come in at level 9, thick mud at 13, frost at 21 (its intro level), 3-layer bales at 26, six tile colours on some hard levels from 30, thick frost at 33, weeds at 41 (its intro level), pumpkins at 101, clover at 126 stone walls at 151, with 2-layer stone from 160, portals at 176 and pumpkin baskets at 201 (each with its intro level; levels 101–125, 126–150, 151–175, 176–200 and 201–225 are the first five updates after the MVP). Level names that promise an obstacle ("Muddy Boots", "Rolling Bales") get it. The Trail shows the levels you've reached and the next 4 locked ones.

## Making levels

Levels 6 to 225 come from `tools/levelgen.luau`. It builds each one from original shape and obstacle patterns (seeded by the level id, so the same id always gives the same level) and gives it the fewest moves (15 to 35) at which the test bot reaches a target win rate. The bot plays randomly, so its targets read low: 80% on Normal levels up to 12, falling to 50% by level 51; Tough 45% to 32%; Super Tough 25% then 20%. Levels 1 to 5 are hand-made.

```sh
luaurun tools/levelgen.luau 6 225 > levels.txt   # prints each level as Luau, with the bot's win rate
```

Hand changes go through the level editor below; once a level ships, change it there rather than regenerating it.

## Level editor (Studio only)

On the Trail, press **Dev: Editor** (or the F6 key; E is the farm's interact key) in Studio Play mode. Studio unlocks every level; **Dev 🔒** on the Trail shows it locked to your real progress, as a player sees it. **Dev +5🎒** adds 5 of every booster, **Dev 🎁** puts a heart gift from a pretend neighbor in your gift box, and **Dev: 0 hearts** empties the hearts.
- Paint the board with the brushes: cell, hole, mud, double mud, hay bales with 1–3 layers, frost with 1–2 layers, weeds, pumpkins, clover, stone walls with 1–2 layers, pumpkin baskets (🧺), and portals (🌀: tap an entrance, then its exit; tap either end again to remove it).
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

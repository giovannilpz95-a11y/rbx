# Farm greybox

A walkable greybox of the farm, built from plain blocks, for testing the walk-first controls and the core loop before any art. It follows the vault notes *15 3D World & Avatar Play*, *09 Roblox Architecture*, *02 Farming*, *05 Orders & Economy* and *Township Baseline Numbers*.

## What's in it

- **World:** a hub with a spawn, a Ring Road, and 12 plot slots around it. Each player gets a plot (only the 96 x 96 stud start area is built) with 6 fields (2 x 2 tiles), a Barn, a Bakery, an Order Board with a delivery truck, and a gate with your name on it.
- **Walk-first controls ("Reach + Errands"):**
  - Tap or click anything on your plot within **Reach (32 studs)** and it happens. Things in reach get an outline.
  - Tap something farther away and your avatar **auto-walks** there at sprint speed, then does it. Steering yourself cancels the walk.
  - **Hold the action button** (E, gamepad X, or the round touch button) to sweep: it harvests ready beds in front of you and sows your last seed into empty beds you walk over. The button's label shows the current "tool" (Scythe, Seeds, Use).
  - **Walk past** the Bakery's output table to collect finished goods.
  - Walk 20, sprint 28 studs/s (Shift, left stick click, or the Sprint button). Camera zoom 10 to 45.
- **Core loop:** plant Wheat (level 1) and Corn (level 3), timers keep running while you're away, harvest into the Barn (50 slots), build the Bakery at level 2, make Bread, fill Order Board cards for Coins and XP, level up to the MVP cap of 12. The Barn can sell items.
- **Paperwork from anywhere:** Orders (O), Barn (B) and Bakery (F) panels from the HUD.
- **Saving:** one profile per player in a DataStore, with a session lock, autosave every 90 s, save on leave and on shutdown, schema version and migrations.
- **Server decides everything:** the client only sends intents (plant this field, deliver card 2). Every remote is rate-limited and checked, hands-on actions check that your avatar is near, and all Coins, Gems and XP go through one service.

## Numbers

Config lives in `src/shared/Config/`. Crops, the Bakery, Bread, the XP curve, level rewards, the starting wallet (500 Coins, 30 Gems), the Barn size and the 30-minute order refresh are the **Township baseline**. Order slots per level, the order reward formula and all the walking numbers are **first-pass** and meant to be tuned in this greybox.

Only Wheat, Corn and the Bakery are switched on (`Balance.enabledCrops`, `Balance.enabledFactories`); the full crop table is already in the config.

## Run it in Studio

With [Rokit](https://github.com/rojo-rbx/rokit) installed, from this folder:

```sh
rokit install
rojo serve
```

Then connect with the Rojo plugin in a new Baseplate place (delete the Baseplate; the game builds its own ground). Or build a place file with `rojo build default.project.json -o farm-greybox.rbxlx` and open it.

The project maps to:

| Folder | Goes to |
|---|---|
| `src/shared` | `ReplicatedStorage.FarmShared` |
| `src/server` | `ServerScriptService.FarmServer` (`Main` is the Script) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.FarmClient` (`Main` is the LocalScript) |

Shared modules use Luau's string requires (`require("./Config/Crops")`) so the same files run in Roblox and in the Lune tests.

**Saving in Studio:** turn on *Game Settings > Security > Enable Studio Access to API Services* to test real saves (they go to a separate `_DEV` store). Without it, the game warns and plays on an unsaved farm.

**Debug panel (Studio only, `` ` `` key):** try Reach 0 / 16 / 32 / 48, walk speed 16 / 20 / 24, and shorter timers (x0.25 makes Wheat take 30 s, as in the prototype checklist).

## Tests

```sh
lune run tests/run.luau     # config integrity, timers, levels, order generation, saves, compile check
stylua --check src tests    # formatting
```

CI runs both and a Rojo build on every pull request that touches `farm/`.

## Not in the greybox yet

Overview camera and the Errand queue, Gem speed-ups, tool drops and tool orders, animals, more factories, placing and moving buildings, Houses and Population, visiting and Helping Hands, the tutorial, and the Train Station. Selene linting and `luau-lsp` strict type checks should be added to CI next.

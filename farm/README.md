# Farm greybox

A walkable greybox of the farm, built from plain blocks, for testing the walk-first controls and the core loop before any art. It follows the vault notes *15 3D World & Avatar Play*, *09 Roblox Architecture*, *02 Farming*, *05 Orders & Economy* and *Township Baseline Numbers*.

## What's in it

- **World:** a hub with a spawn, a Ring Road, and 12 plot slots around it. Each player gets a plot (only the 96 x 96 stud start area is built) with 6 fields (2 x 2 tiles), a Barn, a row of 5 factories, 3 animal pens, an Order Board with a delivery truck, and a gate with your name on it.
- **Walk-first controls ("Reach + Errands"):**
  - Tap or click anything on your plot within **Reach (32 studs)** and it happens. Things in reach get an outline.
  - Tap something farther away and your avatar **auto-walks** there at sprint speed, then does it. Steering yourself cancels the walk.
  - **Hold the action button** (E, gamepad X, or the round touch button) to sweep: it harvests ready beds in front of you and sows your last seed into empty beds you walk over. The button's label shows the current "tool" (Scythe, Seeds, Use).
  - **Walk past** a factory's output table to collect finished goods.
  - **Tap a pen** (or hold the action button next to it) to collect what the animals made; collecting refeeds them if you have feed. Tapping a pen with nothing to do opens its panel.
  - Walk 20, sprint 28 studs/s (Shift, left stick click, or the Sprint button). Camera zoom 10 to 45.
- **Core loop:** plant crops, timers keep running while you're away, harvest into the Barn (50 slots), feed animals, build factories and make goods, fill Order Board cards for Coins and XP, level up to the MVP cap of 12. The Barn can sell items.
- **Everything in the level-12 MVP** (*18 MVP & Roadmap*):
  - Crops: Wheat (L1), Corn (L3), Carrots (L4), Sugarcane (L7), Cotton (L9).
  - Animals: the Cow Barn comes with 3 Cows at level 1 (plus 2 bags of Cow Feed to start), Chicken Coop at 5, Sheep Fold at 10. Each pen comes with 3 animals and you can buy up to 3 more. One bag of feed feeds 3 animals.
  - Factories: Bakery (L2), Feed Mill (L3), Dairy (L4), Sugar Mill (L7), Textile Mill (L9), with 13 recipes: Bread, Cookies, Bagel; Cow, Chicken and Sheep Feed (3 bags a batch); Cream, Cheese, Butter; Sugar; Cotton Fabric, Yarn, Shirt.
  - Order cards only ask for things your farm can make right now (and never feed).
- **Paperwork from anywhere:** Orders (O), Barn (B) and Buildings (F) panels from the HUD. Buildings lists every factory and pen with its status.
- **Saving:** one profile per player in a DataStore, with a session lock, autosave every 90 s, save on leave and on shutdown, schema version and migrations.
- **Server decides everything:** the client only sends intents (plant this field, deliver card 2). Every remote is rate-limited and checked, hands-on actions check that your avatar is near, and all Coins, Gems and XP go through one service.

## Numbers

Config lives in `src/shared/Config/`. Crops, animals and pens, factories, recipes, the XP curve, level rewards, the starting wallet (500 Coins, 30 Gems), the Barn size and the 30-minute order refresh are the **Township baseline**. Order slots per level, the order reward formula and all the walking numbers are **first-pass** and meant to be tuned in this greybox.

What's switched on is in `Balance.enabledCrops`, `Balance.enabledFactories` and `Balance.enabledPens`; the full crop table is already in the config. The 2 bags of starter Cow Feed are first-pass.

## Run it in Studio

With [Rokit](https://github.com/rojo-rbx/rokit) installed, from this folder:

```sh
rokit install
rojo serve
```

Then connect with the Rojo plugin in a new Baseplate place. The game builds its own ground and removes the template's Baseplate and SpawnLocation when the server starts. Or build a place file with `rojo build default.project.json -o farm-greybox.rbxlx` and open it.

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

Overview camera and the Errand queue, Gem speed-ups, extra queue slots, tool drops and tool orders, pen upgrades, placing and moving buildings, new fields from Population, Houses and Population, visiting and Helping Hands, the tutorial, and the Train Station. Selene linting and `luau-lsp` strict type checks should be added to CI next.

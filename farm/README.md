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
- **Core loop:** plant crops, timers keep running while you're away, harvest into the Barn (50 slots), feed animals, build factories and make goods, fill Order Board cards for Coins and XP, level up to the live cap (12 at launch, see the content bank below). The Barn can sell items.
- **Everything in the level-12 MVP** (*18 MVP & Roadmap*):
  - Crops: Wheat (L1), Corn (L3), Carrots (L4), Sugarcane (L7), Cotton (L9).
  - Animals: the Cow Barn comes with 3 Cows at level 1 (plus 2 bags of Cow Feed to start), Chicken Coop at 5, Sheep Fold at 10. Each pen comes with 3 animals and you can buy up to 3 more. One bag of feed feeds 3 animals.
  - Factories: Bakery (L2), Feed Mill (L3), Dairy (L4), Sugar Mill (L7), Textile Mill (L9), with 13 recipes: Bread, Cookies, Bagel; Cow, Chicken and Sheep Feed (3 bags a batch); Cream, Cheese, Butter; Sugar; Cotton Fabric, Yarn, Shirt.
  - Order cards only ask for things your farm can make right now (and never feed).
- **Gem speed-ups** (Township baseline prices, two taps to confirm): finish a growing field (tap it; with 2+ fields of that crop growing, **Finish all** does them together for the summed price), a factory job or construction, every producing animal in a pen, or an Order Board wait; buy extra factory queue slots (8 Gems, then +4 each, to 6 slots; the 7th waits for factory upgrades). Finished goods wait on a 6-item output tray (Township start; upgrades would take it to 8).
- **Town** (*07 Town Building*, Township baseline): Houses raise Population, Community Buildings raise the Population Cap (base 80). A farm starts with 4 Houses (Population 60). House copies unlock by level and need room under the Cap; factories need a minimum Population to build (Bakery 55 … Textile Mill 105). Community Buildings also cost Bricks, Planks and Panes, which drop from harvests (2%, more for long crops) and Order Board deliveries (25%) from level 5, or cost 8 Gems each (drop rates first-pass). New buildings go on the next free lot of **Main Street**, the strip between your gate and the Ring Road. Tap any town building, or press T, for the Town panel.
- **More fields and land** (*02 Farming*, Township baseline): fields 7 to 22 arrive free as Population grows (65 up to 360), with XP. Fields 7 to 10 fit in the start area; from field 11 on they need the West Meadow cleared. Four land expansions (West Meadow, East Meadow, North Fields, Far Corners) cost 25 to 50 Coins and take 20 to 35 minutes, each needing a Population and the previous one finished. Start them from the Land section of the Town panel.
- **Barn upgrades** (*02 Farming*, Township baseline): upgrade *n* costs *n* each of Nails, Hinges and Paint and no Coins (50 → 70 → 90 → 110, then +25 each). Barn materials drop from harvests and orders from level 5 on the same roll as building materials, or cost 12 Gems each. When the Barn is full (less than 2 free), its panel says so; it always lists what you have most of first, with Sell buttons.
- **First-session guide** (*11 UI & UX* FTUE, *01 Core Loop*, the first-60-seconds script in *17*): new farms start with 3 ripe Wheat fields and an easy 4-Wheat order. A card at the bottom with a townsfolk guide (Hattie, Pip, Auntie Crumb, Mort) gives one line per step and a bouncing arrow points at what to walk to, through the first 30 minutes: harvest, replant, ship the first truck, reach level 2, build the Bakery, bake Bread, feed the Cows, collect Milk, reach level 3, build the Feed Mill and make Cow Feed, reach level 4, build a Lean-to Cabin, build the Dairy (its first Finish is free), start the West Meadow, reach level 5, then 5 Gems. The first Wheat, Bread and Milk while their step is on take 30 s. Steps end on their own when their goal is met; Skip appears from step 3. Each step is logged to the Roblox onboarding funnel. Farms from before the guide don't see it; the Debug panel can replay it.
- **Coming back** (*01 Core Loop*, *08 Social & Events*): after 5+ minutes away, a "While you were away" panel lists ready fields, goods waiting, animal products, buildings and land that finished, and the orders on the board. From level 5 a 7-day login calendar gives a gift on each new UTC day (100 Coins, Nails, 200 Coins, Hinges, 5 Gems, 300 Coins + Paint, 15 Gems; Coins x1.5 from level 11). A missed day pauses the calendar instead of resetting it. Tool and decoration days give Barn materials until those ship. The Debug panel can fake an absence.
- **Daily Quests** (*08 Social & Events*, first-pass numbers): once the first-session guide is done, three quests a day from 00:00 UTC, picked from what your farm can do: harvest 30 crops (80 Coins, 20 XP), collect 10 animal goods (80, 20), make 5 factory goods (100, 25) or deliver 3 orders (120, 30); targets are halved below level 5. Progress counts on its own and a toast says when one is done. Claim rewards in the Quests panel (Q, or the 📜 button, which shows a red dot when something is ready); one free swap a day for an unfinished quest. Claiming all three opens a bonus chest: 3 to 10 Gems, or from level 5 a 30% chance of your scarcest tool. Logged as `DailyQuest` and `QuestChest` SKUs plus a `DailyQuestDone` custom event.
- **Decorations** (*07 Town Building*, Township baseline): 12 Coin decorations (paths, fences, hedges, flower beds, trees, hay bales, lamp posts, benches, picnic tables, a pond and a fountain) unlock from level 2 to 10 and give a little XP. Buy one from the Town panel and a green ghost appears in front of you; walk to move it, Turn to rotate it, Place to put it down. It snaps to a 4-stud grid, must sit on your own land (the start area or a cleared expansion) and can't overlap a building, field or another decoration (the ghost turns red). Tap a placed decoration to turn it or sell it back for 25%. Up to 60 per farm, 12 of them big (2 x 2 tiles and up), to keep the plot inside the part budget.
- **Tool drops** (*02 Farming*): from level 5 each field harvest rolls once on one table for a Shovel (3%), Axe (2%), Saw (1.5%) or a building or Barn material (2% each group), better for long crops (up to x3). After 40 harvests in a row without a tool, the next one gives the tool you have fewest of. Order deliveries also have a 5% chance at the scarcest tool. Tools sit in the Tool Shed at the bottom of the Barn panel and take no Barn space; the four MVP land clearings don't need them yet (Shovels start at expansion 20 on the Township baseline).
- **Prize Crops lite** (*02 Farming*, first-pass): when a crop is planted (so a speed-up never buys a roll), the server rolls for a **Sunkissed** (2%) or **Heirloom** (0.2%) crop; none during the first-session guide. On harvest one unit goes to the 10-slot **Prize Basket** (bottom of the Barn panel, no Barn space) and sells at the Prize Stand for x3 or x15 the crop's price. With the basket full it's an ordinary unit. An Heirloom find is announced to everyone on the server, and every find goes on the **Notice Board** in the Town Square (last 8, this server only). Show up to 3 on the **Prize Shelf** by your Barn (tap Show in the Barn panel; Take down puts it back in the basket). Selling a Prize Crop takes two taps. A Prize Crop in the basket also counts as a normal unit for orders and factories when the Barn is short (Barn units are used first, then the least valuable Prize Crop); shelved ones don't, and Barn Sell never touches them.
- **Shop** (*10 Monetization*, *09 Roblox Architecture* §10; G or the 💎 HUD button): three Gem packs (30 / 65 / 175 Gems), a one-time Starter Pack from level 5 (100 Gems + a Shovel, an Axe and a Saw) and the **Big Barn** game pass (+50 Barn space). Robux prices are read from Roblox at runtime. Only the server prompts; `ProcessReceipt` grants, records the receipt id (newest 200 kept) and saves before confirming, and rolls back if the save fails so Roblox retries. Product and pass ids are 0 (shown as "Coming soon") until they are created on the Creator Dashboard and filled in `Config/Products.luau`.
- **Analytics** (*19 Analytics & Metrics* §4, through `TelemetryService`, server-side only): every Coins, Gems, XP and Tools change is summed per currency, flow and SKU and sent every 120 s, on level-up and on leaving (rate-limit budget); custom fields are level band, context and cohort tag (`early_payer`), never ids. Custom events: `SessionStart` (minutes away, gap bucket), `SessionEnd` (minutes played, social or solo), `OrderFulfilled`, `DailyQuestDone`, `GemSkipUsed`, `StorageFull` (at most every 5 min), `FactoryBuilt`, `ExpansionUnlocked`, `PurchasePromptResult`. `PlayerLevel` progression (`L07`), the `Shop` funnel (Opened, Prompted, Granted) and the tutorial's onboarding funnel.
- **Town Square and neighbors** (*14 Multiplayer Features* A1, A2, *08 Social & Events*): the middle of the hub is a round plaza with a fountain, benches and three boards: the Notice Board (Prize Crop news), the Neighbors board (everyone on the server and their level) and a Market board placeholder. Friends who join get a plot next to each other. A Friends Nearby column down the left edge shows your friends on the server; tap one to visit their farm. The Neighbors panel (N, the 👋 button or the Neighbors board) lists everyone with their level and where they are, with Visit and Send home buttons, your farm's settings for visitors (Open, Friends, Closed) and helpers (Nobody, Friends, Anyone), the Notice Board's news with Visit buttons, and buttons to the Town Square and home. A Home button shows whenever you're off your farm. The server checks every visit: blocked players (your Roblox block list) and visitors your settings don't allow are moved to the Town Square, and a visitor sent home can't come back for 10 minutes. Avatars don't collide with each other. In Studio everyone counts as a friend so a local 2-player server can test the friends-only rules. Invite uses Roblox's own invite prompt.
- **Puzzle Porch and heart gifts** (*Features/F12 Crop Pop Puzzle*): a little game cabinet under a porch roof on the west side of the Town Square; tap it (you walk over) to open Crop Pop. The farm fires a client-only `ReplicatedStorage.CropPopOpen` BindableEvent that Crop Pop's client listens to. Friends in the Neighbors panel get a ❤ button that sends a Crop Pop heart through Crop Pop's `ServerStorage.CropPopGiftHeart(fromPlayer, toUserId) -> (ok, message?)`; Crop Pop owns the daily limit and the pending gift.
- **Helping Hands** (*14 Multiplayer Features* B1, MVP scope: water and harvest): from level 3, tap a field on a neighbor's farm (you walk to it first) to harvest it if it's ready, or water it if it's growing. Watering takes 10% off the time left, once per crop, and the soil darkens. Everything harvested goes to the owner's Barn (refused if it's full). The owner's Helpers setting (default Friends) and both players' block lists decide who may help. The game pays the helper, never the owner: 1 Coin and 1 XP for watering, 10% of the field's sell value (at least 1 Coin) and the crop's XP for harvesting, and a 2% chance of their scarcest tool; when the owner is working their own farm at the same time both get +5 XP (Teamwork). One daily budget per helper: 40 actions, at most 15 on one farm (the 🤝 counter shows what's left while you visit). Rewards need a Roblox account at least 3 days old. Studio skips the account-age and level gates.
- **Good Neighbors and the Welcome Boost** (*14 Multiplayer Features* G1, G3): each friend on the server who is level 5+ and did something in the last 5 minutes adds +5% Coins to your Order Board deliveries (at most +10%); a green chip shows it. When a friend joins you (following you into the game, or from your Invite through Roblox's Friend Referral, `ReferredByPlayerId`, or the invite's LaunchData), you both get a 15-minute **Welcome Boost**: crops you plant grow 10% faster. The joiner always gets it; the friend they joined gets it when the joiner is level 5+, and each pair gets it once per UTC day. Inviting itself earns nothing. In Studio the second player to join counts as joining the first.
- **Content bank for the weekly updates** (*18 MVP & Roadmap* §4, Township baseline): levels 13 to 16 are built ahead and held back by the live level cap (`Levels.cap`, 12; `Levels.built`, 16). XP past the cap is banked; raise `cap` on update day (week 1: 13) and players level up when they next join or earn XP. Banked so far: the XP rows and rewards for 13 to 16, **Strawberries** (13) and **Tomatoes** (15) with their own field looks, the **Wool Scarf** (Textile Mill, 14, from Yarn), the **Garden Villa** house (copies at 14, 15, 16) and two Community Buildings, the **Clock Tower** (13, Cap +60) and the **Greenhouse** (14, Cap +65). Until then they show as locked ("level 13"). The level 15 and 16 Community Buildings and the Snack Factory (14) come next; Main Street has 32 House lots, exactly enough for every copy through level 16.
- **Paperwork from anywhere:** Orders (O), Barn (B), Buildings (F) and Town (T) panels from the HUD. Buildings lists every factory and pen with its status.
- **Saving:** one profile per player in a DataStore, with a session lock, autosave every 90 s, save on leave and on shutdown, schema version and migrations.
- **Server decides everything:** the client only sends intents (plant this field, deliver card 2). Every remote is rate-limited and checked, hands-on actions check that your avatar is near, and all Coins, Gems and XP go through one service.

## Art

The plot is dressed with our own cartoon models in the spirit of Township's look: chunky shapes, big colorful roofs, cream trim, bright crops and cute animals, all built from Studio Parts in code so no assets need uploading. They live in `src/shared/Art/` (mapped to `ReplicatedStorage.FarmShared.Art`):

| Module | Models |
|---|---|
| `Palette` | World colors (shared tokens match the UI palette in `uitheme/`) |
| `Kit` | Part builder, roofs, windows, doors, fences, trees, bushes, the Sprout Tag, scaffolds, `fade` and `weld` helpers |
| `Crops` | Field beds and every crop at 4 growth stages (seeded, sprout, growing, ready) |
| `Animals` | Cows, Chickens and Sheep, their products, and the Cow Barn, Chicken Coop and Sheep Fold |
| `Factories` | Bakery, Feed Mill, Dairy, Sugar Mill, Textile Mill, each with an output table and a moving part |
| `Buildings` | Barn, Order Board, loading dock, delivery truck, plot gate |
| `Houses` / `Community` | The 7 House types and 9 Community Buildings |
| `ItemProps` / `Icons` | A small prop for every Barn item, shown on factory output tables; `Icons.viewport(id, size)` puts one in a ViewportFrame as a UI icon |
| `Motion` | The factories' moving parts (turned by the client's `FactoryMotion` while a factory is busy) |
| `Decor` | The 12 decorations players place: paths, fences, hedges, flower beds, trees, hay, pond, lamp, bench, picnic table, fountain |
| `Lighting` | Sunny afternoon lighting, color grade, bloom and haze |

Part budgets (Design/15 §5) are checked by `tests/art.luau`: crop stage ≤ 12, bed ≤ 4, animal ≤ 12, pen ≤ 40, factory ≤ 80, House and Community Building ≤ 40, item prop ≤ 8, and a full level-12 plot under 2,500. To look at the models without Studio, see `tools/artpreview/README.md`.

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
| `../uitheme/src` | `ReplicatedStorage.UiTheme` (shared UI look, see Design/25 UI Style Guide) |
| `src/server` | `ServerScriptService.FarmServer` (`Main` is the Script) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.FarmClient` (`Main` is the LocalScript) |

Shared modules use Luau's string requires (`require("./Config/Crops")`) so the same files run in Roblox and in the Lune tests.

**Saving in Studio:** turn on *Game Settings > Security > Enable Studio Access to API Services* to test real saves (they go to a separate `_DEV` store). Without it, the game warns and plays on an unsaved farm.

**Screen tour (Studio only, `]` key):** steps through the HUD alone, Barn, Orders, Shop, Buildings, Town, the seed picker for field 1 and Debug, printing `[Tour] n/8 <screen> at <width>x<height>` to Output. Set the device emulator to a phone first to check the mobile layout.

**Debug panel (Studio only, `` ` `` key):** try Reach 0 / 16 / 32 / 48, walk speed 16 / 20 / 24, and shorter timers (x0.25 makes Wheat take 30 s, as in the prototype checklist). Its buttons also replay the guide, fake an absence, build everything, grant +500 Gems, +5,000 Coins and 5 of each tool, give **+1 level** (which also opens the content bank's levels on that Studio server), and **fuzz every remote** (*09* §12 exploit checks): each client-to-server handler gets junk arguments (NaN, infinities, negative and fractional numbers, empty and 10,000-character strings, tables, an Instance), first in every slot and then one slot at a time, about 3,500 calls. Output lists every handler that threw (a bug: its checks should reject first) and every call that returned ok (check by hand). The farm is restored afterwards. Remotes with no arguments, Shop prompts and avatar moves are skipped.

## Tests

```sh
lune run tests/run.luau     # config integrity, timers, levels, order generation, saves, compile check
stylua --check src tests    # formatting
```

CI runs both and a Rojo build on every pull request that touches `farm/`.

Data safety (`tests/datasafety.luau`): a played farm touching every save block, Crop Pop's included, must pass `SaveCheck` and come back from JSON (what a DataStore keeps) unchanged. Every past save version has a fixture in `tests/fixtures/` that must load into today's layout. When a migration lands, add the old version's fixture. On every save the server runs `SaveCheck` and, if something can't be stored (NaN, an array with holes, number keys in a dictionary, a cycle, over 4 MB), warns with the exact field.

## Not in the greybox yet

Overview camera and the Errand queue, tool drops and tool orders, pen upgrades, builders, placing and moving buildings (Main Street lots are assigned for now), decorations, land expansion past the fourth (it needs tools), the FTUE's visit step and camera swoop, helping with animals, factories and construction (Helping Hands is water and harvest only in the MVP), and the Train Station. Selene linting and `luau-lsp` strict type checks should be added to CI next.

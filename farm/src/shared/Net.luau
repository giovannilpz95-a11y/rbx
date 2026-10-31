--!strict
-- Remote names shared by server and client. NetService creates them under
-- ReplicatedStorage.FarmRemotes at boot.

return table.freeze({
	-- Client -> server (intents only; the server decides every amount)
	Farm_Plant = "Farm_Plant", -- fieldId, cropId
	Farm_Harvest = "Farm_Harvest", -- fieldId
	Farm_SpeedUp = "Farm_SpeedUp", -- fieldId (Gems)
	Farm_SpeedUpAll = "Farm_SpeedUpAll", -- cropId: every growing field of that crop
	Factory_Build = "Factory_Build", -- factoryId
	Factory_Queue = "Factory_Queue", -- factoryId, recipeId
	Factory_Collect = "Factory_Collect", -- factoryId
	Factory_SpeedUp = "Factory_SpeedUp", -- factoryId: construction, else the running job (Gems)
	Factory_BuySlot = "Factory_BuySlot", -- factoryId (Gems)
	Pen_Build = "Pen_Build", -- penId
	Pen_BuyAnimal = "Pen_BuyAnimal", -- penId
	Pen_Feed = "Pen_Feed", -- penId
	Pen_Collect = "Pen_Collect", -- penId
	Pen_SpeedUp = "Pen_SpeedUp", -- penId: construction, else every producing animal (Gems)
	Town_BuildHouse = "Town_BuildHouse", -- houseId
	Town_BuildCommunity = "Town_BuildCommunity", -- communityId
	Town_SpeedUp = "Town_SpeedUp", -- "House", lot | "Community", id | "Land", stage (Gems)
	Town_BuyMaterial = "Town_BuyMaterial", -- materialId, building or Barn (Gems)
	Town_Expand = "Town_Expand", -- (the next land expansion)
	Decor_Place = "Decor_Place", -- decorId, x, z (plot-local studs), quarter turns
	Decor_Rotate = "Decor_Rotate", -- index in data.decor
	Decor_Sell = "Decor_Sell", -- index in data.decor
	Order_Fulfill = "Order_Fulfill", -- slotIndex
	Order_Discard = "Order_Discard", -- slotIndex
	Order_SkipWait = "Order_SkipWait", -- slotIndex: a new card now (Gems)
	Barn_Sell = "Barn_Sell", -- itemId, qty
	Barn_Upgrade = "Barn_Upgrade", -- (the next upgrade)
	Shop_Prompt = "Shop_Prompt", -- product key (server looks up the id and prompts)
	Shop_PromptPass = "Shop_PromptPass", -- game pass key
	Shop_Opened = "Shop_Opened", -- (analytics: step 1 of the Shop funnel)
	Prize_Sell = "Prize_Sell", -- basket index (the Prize Stand)
	Prize_Shelve = "Prize_Shelve", -- basket index -> Prize Shelf
	Prize_Unshelve = "Prize_Unshelve", -- shelf slot -> basket
	Visit_Go = "Visit_Go", -- targetUserId: walk onto a neighbor's plot (teleport to their gate)
	Visit_Home = "Visit_Home", -- back to your own plot
	Visit_Square = "Visit_Square", -- to the Town Square
	Visit_SendHome = "Visit_SendHome", -- visitorUserId: send a visitor off your plot
	Help_Water = "Help_Water", -- ownerUserId, fieldId: water a growing field on a neighbor's plot
	Help_Harvest = "Help_Harvest", -- ownerUserId, fieldId: harvest a ready field into the owner's Barn
	Help_Blimp = "Help_Blimp", -- ownerUserId, row, slot: load a neighbor's flagged blimp crate from your Barn
	Social_SetPrivacy = "Social_SetPrivacy", -- "Open" | "Friends" | "Closed"
	Social_SetHelpers = "Social_SetHelpers", -- "Nobody" | "Friends" | "Anyone"
	Social_GiftHeart = "Social_GiftHeart", -- toUserId: send a friend a Crop Pop heart (Crop Pop's daily limit)
	Social_SetBlocked = "Social_SetBlocked", -- { userId } from the player's Roblox block list
	Tutorial_Next = "Tutorial_Next", -- "Got it" on a step the player ends by tapping
	Tutorial_Skip = "Tutorial_Skip", -- end the guide early
	Missing_Buy = "Missing_Buy", -- "Recipe", factoryId, recipeId | "Order", slot | "Community", id | "Barn" (Gems)
	Settings_Set = "Settings_Set", -- key, value (shared/Settings checks both)
	Records_Claim = "Records_Claim", -- recordId: the next tier of a Town Record (Gems and XP)
	Quest_Claim = "Quest_Claim", -- index: a finished Daily Quest's reward
	Quest_Reroll = "Quest_Reroll", -- index: swap an unfinished quest (once a day, free)
	Quest_Chest = "Quest_Chest", -- the bonus chest for all three
	SeedCart_Buy = "SeedCart_Buy", -- slot: buy one of the Seed Cart's four slots
	Quarry_Restore = "Quarry_Restore", -- (start reopening the Quarry)
	Quarry_SpeedUp = "Quarry_SpeedUp", -- (finish reopening now, Gems)
	Quarry_Dig = "Quarry_Dig", -- row, col: one Pickaxe swing (shared/Quarry)
	Quarry_Free = "Quarry_Free", -- (the day's free Pickaxes at the gate)
	Guild_Build = "Guild_Build", -- (build the Tinker's Guild with Bars)
	Guild_SpeedUp = "Guild_SpeedUp", -- (finish building it now, Gems)
	Guild_Upgrade = "Guild_Upgrade", -- factoryId, stat: one upgrade (shared/Guild)
	Blimp_Repair = "Blimp_Repair", -- (start repairing the Blimp Mast, shared/Blimp)
	Blimp_SpeedUp = "Blimp_SpeedUp", -- (finish the repair now, Gems)
	Blimp_Fill = "Blimp_Fill", -- row, slot: load a crate from the Barn
	Blimp_Flag = "Blimp_Flag", -- row, slot: ask for help with a crate (one per row; again to take it off)
	Blimp_Send = "Blimp_Send", -- (send the Cargo Blimp off with the rows loaded so far)
	Blimp_Skip = "Blimp_Skip", -- (call the next blimp now, Gems)
	Layout_Move = "Layout_Move", -- key, x, z, r: move one of your buildings (shared/Layout)
	Express_Load = "Express_Load", -- index: load a Town Express crate from the Barn (at the hub station)
	Debug_SetTimeScale = "Debug_SetTimeScale", -- scale (Studio only)
	Debug_RestartTutorial = "Debug_RestartTutorial", -- (Studio only)
	Debug_BuildAll = "Debug_BuildAll", -- finish every building, ignoring gates (Studio only)
	Debug_TestNeighbor = "Debug_TestNeighbor", -- make (or go to) a test neighbor's farm (Studio only)
	Debug_Away = "Debug_Away", -- show the away summary as if gone 2 h, and a new day's gift (Studio only)
	Debug_Grant = "Debug_Grant", -- Gems, Coins and tools for testing paid paths (Studio only)
	Debug_Blimp = "Debug_Blimp", -- the Blimp Mast repaired and the Cargo Blimp docked now (Studio only)
	Debug_Quarry = "Debug_Quarry", -- Bars, ore, Pickaxes, an open Quarry and Population (Studio only)
	Debug_Fuzz = "Debug_Fuzz", -- junk arguments into every remote handler, farm restored after (Studio only)
	Debug_LevelUp = "Debug_LevelUp", -- open the content bank's levels and give one level's XP (Studio only)
	Debug_Express = "Debug_Express", -- the Town Express in the station now, for a full window (Studio only)
	Debug_ExpressLeave = "Debug_ExpressLeave", -- the Town Express leaves now (Studio only)
	Debug_ExpressGoods = "Debug_ExpressGoods", -- goods for the next 3 Town Express crates (Studio only)
	Debug_Records = "Debug_Records", -- raise Town Records to their next medal (Studio only)
	Client_Ready = "Client_Ready",

	-- Server -> client
	State_Snapshot = "State_Snapshot", -- full owner state
	Toast = "Toast", -- message
	Reward_Popup = "Reward_Popup", -- { kind, ... } cosmetic; numbers already applied
})

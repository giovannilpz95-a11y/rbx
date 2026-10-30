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
	Prize_Sell = "Prize_Sell", -- basket index (the Prize Stand)
	Prize_Shelve = "Prize_Shelve", -- basket index -> Prize Shelf
	Prize_Unshelve = "Prize_Unshelve", -- shelf slot -> basket
	Tutorial_Next = "Tutorial_Next", -- "Got it" on a step the player ends by tapping
	Tutorial_Skip = "Tutorial_Skip", -- end the guide early
	Debug_SetTimeScale = "Debug_SetTimeScale", -- scale (Studio only)
	Debug_RestartTutorial = "Debug_RestartTutorial", -- (Studio only)
	Debug_BuildAll = "Debug_BuildAll", -- finish every building, ignoring gates (Studio only)
	Debug_Away = "Debug_Away", -- show the away summary as if gone 2 h, and a new day's gift (Studio only)
	Client_Ready = "Client_Ready",

	-- Server -> client
	State_Snapshot = "State_Snapshot", -- full owner state
	Toast = "Toast", -- message
	Reward_Popup = "Reward_Popup", -- { kind, ... } cosmetic; numbers already applied
})

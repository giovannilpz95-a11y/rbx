--!strict
-- Remote names shared by server and client. NetService creates them under
-- ReplicatedStorage.FarmRemotes at boot.

return table.freeze({
	-- Client -> server (intents only; the server decides every amount)
	Farm_Plant = "Farm_Plant", -- fieldId, cropId
	Farm_Harvest = "Farm_Harvest", -- fieldId
	Farm_SpeedUp = "Farm_SpeedUp", -- fieldId (Gems)
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
	Town_SpeedUp = "Town_SpeedUp", -- "House", lot | "Community", id (Gems)
	Town_BuyMaterial = "Town_BuyMaterial", -- materialId (Gems)
	Order_Fulfill = "Order_Fulfill", -- slotIndex
	Order_Discard = "Order_Discard", -- slotIndex
	Order_SkipWait = "Order_SkipWait", -- slotIndex: a new card now (Gems)
	Barn_Sell = "Barn_Sell", -- itemId, qty
	Debug_SetTimeScale = "Debug_SetTimeScale", -- scale (Studio only)
	Client_Ready = "Client_Ready",

	-- Server -> client
	State_Snapshot = "State_Snapshot", -- full owner state
	Toast = "Toast", -- message
	Reward_Popup = "Reward_Popup", -- { kind, ... } cosmetic; numbers already applied
})

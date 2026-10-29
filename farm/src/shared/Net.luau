--!strict
-- Remote names shared by server and client. NetService creates them under
-- ReplicatedStorage.FarmRemotes at boot.

return table.freeze({
	-- Client -> server (intents only; the server decides every amount)
	Farm_Plant = "Farm_Plant", -- fieldId, cropId
	Farm_Harvest = "Farm_Harvest", -- fieldId
	Factory_Build = "Factory_Build", -- factoryId
	Factory_Queue = "Factory_Queue", -- factoryId, recipeId
	Factory_Collect = "Factory_Collect", -- factoryId
	Order_Fulfill = "Order_Fulfill", -- slotIndex
	Order_Discard = "Order_Discard", -- slotIndex
	Barn_Sell = "Barn_Sell", -- itemId, qty
	Debug_SetTimeScale = "Debug_SetTimeScale", -- scale (Studio only)
	Client_Ready = "Client_Ready",

	-- Server -> client
	State_Snapshot = "State_Snapshot", -- full owner state
	Toast = "Toast", -- message
	Reward_Popup = "Reward_Popup", -- { kind, ... } cosmetic; numbers already applied
})

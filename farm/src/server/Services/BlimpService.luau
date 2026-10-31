--!strict
-- Airship Freight (Features/F04, shared/Blimp): repair the Blimp Mast once, then the Cargo
-- Blimp docks on a cycle with 3 rows of crates. Loading a crate pays Coins and XP at once;
-- sending the blimp pays every full row's bonus (Coins and Sky Miles) and, when every crate is
-- loaded, the Full Hold chest. If the loading window runs out it leaves with nothing.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Blimp = require(Shared.Blimp)
local Config = require(Shared.Config.Blimp)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Speedup = require(Shared.Speedup)
local Tools = require(Shared.Config.Tools)
local QuarryConfig = require(Shared.Config.Quarry)
local Timer = require(Shared.Timer)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local BlimpService = {}

-- The flagged crates still to load, for the Help Board in the Neighbors panel: "12 Milk, 5
-- Bread" on the owner's BlimpHelp attribute ("" when there's nothing to help with)
function BlimpService.helpText(data: { [string]: any }): string
	local blimp = data.blimp
	if blimp.leavesAt == nil or blimp.load == nil then
		return ""
	end
	local asks = {}
	for _, row in blimp.load.rows do
		for _, crate in row do
			if crate.flagged and crate.filledBy == nil then
				table.insert(asks, string.format("%d %s", crate.qty, Items[crate.item].displayName))
			end
		end
	end
	return table.concat(asks, ", ")
end

local function changed(player: Player)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
	local data = DataService.get(player)
	if data and typeof(player) == "Instance" then
		player:SetAttribute("BlimpHelp", BlimpService.helpText(data))
	end
end
BlimpService.changed = changed

function BlimpService.repair(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = Blimp.canRepair(data, now)
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", Config.repairCoins, "blimp_repair") then
		return false, string.format("Repairing the Blimp Mast costs %d Coins", Config.repairCoins)
	end
	Blimp.repair(data, now, Random.new():NextInteger(1, 2147483646), Clock.getTimeScale())
	EconomyService.add(player, "XP", Config.repairXp, "blimp_repair")
	TelemetryService.custom(player, "BlimpRepair", 0, "Blimp")
	changed(player)
	return true
end

-- Gems finish the repair now; the first blimp comes in with it.
function BlimpService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.blimp.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_blimp") then
		return false, "Not enough Gems"
	end
	Blimp.finishRepair(data, now)
	BlimpService.tick(player)
	changed(player)
	return true
end

-- Load a crate from the owner's Barn: its Coins and XP at once.
function BlimpService.fill(player: Player, row: any, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local crate, reason = Blimp.canFill(data, row, slot, Clock.now())
	if crate == nil then
		return false, reason
	end
	local name = Items[crate.item].displayName
	if not InventoryService.remove(player, { [crate.item] = crate.qty }) then
		return false, string.format("That crate needs %d %s", crate.qty, name)
	end
	Blimp.fill(crate, player.UserId)
	local coins, xp = Blimp.crateRewards(crate)
	EconomyService.add(player, "Coins", coins, "blimp_crate")
	EconomyService.add(player, "XP", xp, "blimp_crate")
	changed(player)
	return true
end

function BlimpService.flag(player: Player, row: any, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = Blimp.flag(data, row, slot, Clock.now())
	if not ok then
		return false, reason
	end
	changed(player)
	return true
end

-- Put a prize where it belongs: tools in the Tool Shed, everything else in the Barn (rewards
-- go in even past the Barn's cap, like the level-up gifts)
local function give(data: { [string]: any }, item: string, qty: number)
	if Tools.tools[item] or item == QuarryConfig.pickaxe then
		data.toolShed.items[item] = (data.toolShed.items[item] or 0) + qty
	else
		data.inventory.items[item] = (data.inventory.items[item] or 0) + qty
	end
end

local function prizeName(item: string, qty: number): string
	local tool = Tools.tools[item]
	local name = if tool
		then (if qty == 1 then tool.displayName else tool.plural)
		elseif item == QuarryConfig.pickaxe then (if qty == 1 then "Pickaxe" else "Pickaxes")
		elseif Items[item] then Items[item].displayName
		else item
	return string.format("%d %s", qty, name)
end
BlimpService.prizeName = prizeName

function BlimpService.send(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local payout = Blimp.send(data, Clock.now(), Clock.getTimeScale())
	if payout == nil then
		return false, "The Cargo Blimp isn't here"
	end
	if payout.coins > 0 then
		EconomyService.add(player, "Coins", payout.coins, "blimp_rows")
	end
	local parts = {}
	if #payout.rows > 0 then
		table.insert(
			parts,
			string.format(
				"%d %s loaded: +%d Coins, +%d Sky Miles",
				#payout.rows,
				if #payout.rows == 1 then "row" else "rows",
				payout.coins,
				payout.miles
			)
		)
	else
		table.insert(parts, "The Cargo Blimp left without a full row, so no row bonus.")
	end
	if payout.chest then
		local names = {}
		for _, prize in payout.chest do
			give(data, prize.item, prize.qty)
			table.insert(names, prizeName(prize.item, prize.qty))
		end
		table.insert(parts, "Full Hold chest: " .. table.concat(names, ", "))
	end
	TelemetryService.custom(player, "BlimpSent", #payout.rows, "Blimp")
	changed(player)
	NetService.popup(player, { kind = "Crier", text = table.concat(parts, ". ") })
	return true
end

-- Gems call the next blimp now; it docks straight away.
function BlimpService.skip(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local cost = Blimp.skipCost(data, now)
	if data.blimp.leavesAt ~= nil or data.blimp.arrivesAt == nil or not Blimp.isRepaired(data, now) then
		return false
	end
	if cost > 0 and not EconomyService.spend(player, "Gems", cost, "skip_blimp") then
		return false, "Not enough Gems"
	end
	Blimp.skip(data, now)
	BlimpService.tick(player)
	changed(player)
	return true
end

-- Dock a blimp that's due, and send off one whose time ran out. Runs every second for each
-- player in the game, so a blimp only lands while its owner is here.
function BlimpService.tick(player: Player): string?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	local event = Blimp.tick(data, Clock.now(), Clock.getTimeScale())
	if event == "docked" then
		NetService.toast(
			player,
			string.format(
				"The Cargo Blimp has docked at your Blimp Mast. Load its crates within %s.",
				Timer.format(data.blimp.leavesAt - Clock.now())
			)
		)
		changed(player)
	elseif event == "expired" then
		NetService.toast(player, "The Cargo Blimp's time ran out and it left with no row bonus.")
		changed(player)
	end
	return event
end

function BlimpService.init()
	NetService.on(Net.Blimp_Repair, 1, 2, BlimpService.repair)
	NetService.on(Net.Blimp_SpeedUp, 1, 2, BlimpService.speedUp)
	NetService.on(Net.Blimp_Fill, 3, 6, BlimpService.fill)
	NetService.on(Net.Blimp_Flag, 2, 4, BlimpService.flag)
	NetService.on(Net.Blimp_Send, 1, 2, BlimpService.send)
	NetService.on(Net.Blimp_Skip, 1, 2, BlimpService.skip)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				BlimpService.tick(player)
				-- Keep the Help Board's line in step (it isn't saved, so set it after a join too)
				local data = DataService.get(player)
				local help = if data then BlimpService.helpText(data) else ""
				if player:GetAttribute("BlimpHelp") ~= help then
					player:SetAttribute("BlimpHelp", help)
				end
			end
		end
	end)
end

return BlimpService

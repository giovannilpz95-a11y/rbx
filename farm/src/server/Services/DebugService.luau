--!strict
-- Studio-only shortcuts for playtesting. Every handler refuses outside Studio.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local Factories = require(Shared.Config.Factories)
local BarnRules = require(Shared.BarnRules)
local Blimp = require(Shared.Blimp)
local Levels = require(Shared.Config.Levels)
local Net = require(Shared.Net)
local Profile = require(Shared.Profile)
local Quarry = require(Shared.Quarry)
local QuarryConfig = require(Shared.Config.Quarry)
local Progression = require(Shared.Progression)
local Records = require(Shared.Records)
local Shop = require(Shared.Shop)
local Tools = require(Shared.Config.Tools)
local Town = require(Shared.Config.Town)
local Layout = require(Shared.Layout)
local Lots = require(Shared.Lots)
local TownRules = require(Shared.TownRules)

local Clock = require(script.Parent.Parent.Util.Clock)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)

local DebugService = {}

-- Every factory, pen and Community Building, and one House of each type, finished now,
-- ignoring level, Population and Coins (for checking models and tap targets).
function DebugService.buildAll(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	for _, factory in data.factories do
		factory.built = true
		factory.constructionReadyAt = nil
	end
	for id, pen in data.pens do
		if not pen.built then
			pen.built = true
			for _ = 1, Animals.pens[id].startAnimals do
				table.insert(pen.animals, {})
			end
		end
		pen.constructionReadyAt = nil
	end
	for id in Town.houses do
		local lot = TownRules.freeLot(data, #PlotService.LAYOUT.houseLots)
		if TownRules.copiesBuilt(data, id) == 0 and lot then
			table.insert(data.town.houses, { type = id, lot = lot })
		end
	end
	for id in Town.community do
		data.town.community[id] = {}
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

-- Every open House lot filled with a finished Cottage, ignoring copy limits and Coins (for
-- testing what happens once the lots run out: the next House goes up at an open spot).
function DebugService.fillLots(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local open = TownRules.houseLotCount(data, Clock.now())
	local added = 0
	while true do
		local lot = TownRules.freeLot(data, open)
		if lot == nil then
			break
		end
		table.insert(data.town.houses, { type = "Cottage", lot = lot })
		added += 1
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.toast(player, string.format("Dev: added %d Cottages. All %d open House lots are taken now", added, open))
	return true
end

-- Population for testing late content: the farm's smallest Houses become the biggest House
-- type, finished, until Population reaches the target. The target is at least POPULATION and
-- always clears the biggest factory requirement in the content bank (the Homewares Shop needs
-- 3,130), rounded up to the next 500.
DebugService.POPULATION = 3000

function DebugService.populationTarget(): number
	local need = DebugService.POPULATION
	for _, def in Factories do
		if def.unlockLevel <= Levels.built then
			need = math.max(need, math.ceil((def.population + 1) / 500) * 500)
		end
	end
	return need
end

function DebugService.population(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local now = Clock.now()
	local target = DebugService.populationTarget()
	local best, bestPop = nil, 0
	for id, def in Town.houses do
		if def.population > bestPop then
			best, bestPop = id, def.population
		end
	end
	local houses = table.clone(data.town.houses)
	table.sort(houses, function(a, b)
		local pa = Town.houses[a.type] and Town.houses[a.type].population or 0
		local pb = Town.houses[b.type] and Town.houses[b.type].population or 0
		return pa < pb
	end)
	local changed = {}
	for _, house in houses do
		if TownRules.population(data, now) >= target then
			break
		end
		if house.type ~= best or house.readyAt ~= nil then
			house.type = best
			house.readyAt = nil
			table.insert(changed, house.lot)
		end
	end
	-- Still short (too few Houses to swap): new ones of the biggest type at open spots
	local added = 0
	while TownRules.population(data, now) < target and added < 40 do
		local spot = PlotService.findOpenSpot(player, data, "house", PlotService.nearPlayer(player))
		if spot == nil then
			break
		end
		local lot = #Lots.houses
		for _, house in data.town.houses do
			lot = math.max(lot, house.lot)
		end
		lot += 1
		data.layout[Layout.key("house", lot)] = spot
		table.insert(data.town.houses, { type = best, lot = lot })
		added += 1
		PlotService.refresh(player) -- so the next search sees this one standing
	end
	DataService.markDirty(player, true)
	for _, lot in changed do
		PlotService.relocate(player, Layout.key("house", lot))
	end
	PlotService.refresh(player)
	NetService.toast(
		player,
		string.format(
			"Dev: %d Houses became %s and %d more went up. Population %d",
			#changed,
			Town.houses[best].displayName,
			added,
			TownRules.population(data, now)
		)
	)
	return true
end

DebugService.GRANT = { gems = 500, coins = 5000, tools = 5 }

-- For testing the Quarry, Smelters and Tinker's Guild (Features/F01) without digging or
-- smelting: Bars in the Barn, Barn upgrades until it has `barnRoom` free (so the Bars don't
-- block collecting), ore in the Ore Shed, Pickaxes, the Quarry open, and finished House copies
-- until Population reaches POPULATION.
DebugService.QUARRY = { bars = 20, ore = 50, pickaxes = 50, population = 1200, barnRoom = 150 }
local BARS = { "CopperBar", "SilverBar", "GoldBar", "PlatinumBar" }

function DebugService.quarry(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local now = Clock.now()
	local give = DebugService.QUARRY
	local items = data.inventory.items
	for _, bar in BARS do
		items[bar] = (items[bar] or 0) + give.bars
	end
	-- Free Barn upgrades until there's room again (capped, in case the steps run out)
	local inv = data.inventory
	local upgrades = 0
	while Shop.barnCapacity(data) - InventoryService.used(data) < give.barnRoom and upgrades < 200 do
		inv.upgrades = (inv.upgrades or 0) + 1
		inv.barnCapacity = BarnRules.capacity(inv.upgrades)
		upgrades += 1
	end
	for id in QuarryConfig.ores do
		data.oreShed[id] = (data.oreShed[id] or 0) + give.ore
	end
	local tools = data.toolShed.items
	tools[QuarryConfig.pickaxe] = (tools[QuarryConfig.pickaxe] or 0) + give.pickaxes
	if data.quarry.readyAt == nil then
		Quarry.restore(data, now, Random.new():NextInteger(1, 2147483646))
	elseif data.quarry.readyAt > now then
		data.quarry.readyAt = now
	end
	-- More House copies, cycling through the types, until Population is high enough
	local types = {}
	for id in Town.houses do
		table.insert(types, id)
	end
	table.sort(types)
	local i = 0
	while TownRules.population(data, now) < give.population and i < 200 do
		local lot = TownRules.freeLot(data, #PlotService.LAYOUT.houseLots)
		if lot == nil then
			break
		end
		table.insert(data.town.houses, { type = types[i % #types + 1], lot = lot })
		i += 1
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.toast(
		player,
		string.format(
			"Dev: +%d of each Bar, +%d of each ore, +%d Pickaxes, Quarry open, Population %d",
			give.bars,
			give.ore,
			give.pickaxes,
			TownRules.population(data, now)
		)
	)
	return true
end

-- Airship Freight (Features/F04): the Blimp Mast repaired and the Cargo Blimp docked now,
-- ignoring level, land and Coins. Pressed while it's docked, it sends it off (no rewards) and
-- brings a fresh load in.
function DebugService.blimp(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local now = Clock.now()
	local blimp = data.blimp
	if blimp.readyAt == nil then
		Blimp.repair(data, now, Random.new():NextInteger(1, 2147483646))
	end
	Blimp.finishRepair(data, now)
	if blimp.leavesAt ~= nil then
		blimp.leavesAt = now
		Blimp.tick(data, now)
	end
	blimp.arrivesAt = now
	Blimp.tick(data, now, Clock.getTimeScale())
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
	NetService.toast(player, "Dev: the Cargo Blimp is docked at your Blimp Mast (West Meadow)")
	return true
end

-- Gems, Coins and a few of each tool, for checking speed-ups, the Shop's paid paths and
-- anything that costs more than a test farm has. Logged under the "debug" reason.
function DebugService.grant(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local grant = DebugService.GRANT
	EconomyService.add(player, "Gems", grant.gems, "debug")
	EconomyService.add(player, "Coins", grant.coins, "debug")
	for id in Tools.tools do
		data.toolShed.items[id] = (data.toolShed.items[id] or 0) + grant.tools
	end
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		string.format("Dev grant: +%d Gems, +%d Coins, +%d of each tool", grant.gems, grant.coins, grant.tools)
	)
	return true
end

-- The content bank (Config/Levels): open the levels past the live cap, up to Levels.built, on
-- this Studio server, and give the XP for one more level each press (logged as "debug").
function DebugService.levelUp(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	Progression.preview(Levels.built)
	local info = Progression.info(data.currencies.XP)
	if info.atCap then
		return false, string.format("Already at level %d, the last built level", info.level)
	end
	EconomyService.add(player, "XP", info.xpToNext - info.xpIntoLevel, "debug")
	NetService.toast(player, string.format("Dev: content bank open to level %d", Levels.built))
	return true
end

-- Remotes the fuzzer leaves alone: they take no arguments (so junk is ignored and the real
-- action runs), prompt a purchase, move the avatar, or are Studio tools themselves.
local FUZZ_SKIP = {
	Tutorial_Next = true,
	Tutorial_Skip = true,
	Town_Expand = true,
	Barn_Upgrade = true,
	Shop_Opened = true,
	Shop_Prompt = true,
	Shop_PromptPass = true,
	Visit_Home = true,
	Visit_Square = true,
	Client_Ready = true,
}

-- Junk an exploiter could send (09 Roblox Architecture §12 exploit checks): wrong types,
-- NaN, infinities, out-of-range and fractional numbers, empty, long and odd strings, and
-- tables where a value is expected.
local function junkValues(player: Player): { any }
	local deep = {}
	local node = deep
	for _ = 1, 50 do
		node.next = {}
		node = node.next
	end
	return {
		0 / 0,
		math.huge,
		-math.huge,
		-1,
		0,
		0.5,
		1e12,
		"",
		string.rep("x", 65),
		string.rep("x", 10000),
		"../../",
		"F1\0",
		true,
		{},
		{ 1, 2, 3 },
		deep,
		player, -- an Instance where a string or number is expected
		Vector3.new(0 / 0, 0, 0),
	}
end

-- Put `target` back to match `source`, keeping existing tables (other services may hold
-- references to parts of the profile)
local function restoreInto(target: { [any]: any }, source: { [any]: any })
	for key in target do
		if source[key] == nil then
			target[key] = nil
		end
	end
	for key, value in source do
		if type(value) == "table" and type(target[key]) == "table" then
			restoreInto(target[key], value)
		else
			target[key] = Profile.deepCopy(value)
		end
	end
end

-- Fire every client -> server handler with junk (the same junk in every argument slot,
-- then junk in one slot with nils elsewhere). Counts handlers that throw (a bug: the
-- check should reject first) and calls that return ok (check those by hand). The farm is
-- restored afterwards, so nothing a junk call changed is kept.
function DebugService.fuzz(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local backup = Profile.deepCopy(data)
	local calls, errors, accepted = 0, {}, {}
	local junk = junkValues(player)
	local function try(name: string, handler: any, args: { any }, label: string)
		calls += 1
		local ok, result = pcall(handler, player, table.unpack(args, 1, 4))
		if not ok then
			table.insert(errors, string.format("%s(%s): %s", name, label, tostring(result)))
		elseif result == true then
			table.insert(accepted, string.format("%s(%s)", name, label))
		end
	end
	for name, handler in NetService.handlers() do
		if FUZZ_SKIP[name] or name:sub(1, 6) == "Debug_" then
			continue
		end
		for i, value in junk do
			try(name, handler, { value, value, value, value }, "all=" .. i)
			for slot = 1, 4 do
				local args = {}
				args[slot] = value
				try(name, handler, args, string.format("arg%d=%d", slot, i))
			end
		end
	end
	restoreInto(data, backup)
	DataService.markDirty(player, true)
	PlotService.refresh(player)

	print(string.format("[Fuzz] %d calls, %d errors, %d accepted", calls, #errors, #accepted))
	for _, line in errors do
		warn("[Fuzz] error " .. line)
	end
	for _, line in accepted do
		print("[Fuzz] accepted " .. line)
	end
	NetService.toast(
		player,
		string.format("Fuzz: %d calls, %d errors, %d accepted (see Output)", calls, #errors, #accepted)
	)
	return true
end

-- Town Records: raise each counted record to its next medal's goal (shared/Records.debugFill)
function DebugService.records(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	local ready = Records.debugFill(data, Clock.now())
	DataService.markDirty(player, true)
	NetService.toast(player, string.format("Dev: %d Town Records ready to claim on the Farmer Card (P)", ready))
	return true
end

function DebugService.init()
	NetService.on(Net.Debug_BuildAll, 1, 2, DebugService.buildAll)
	NetService.on(Net.Debug_Grant, 2, 4, DebugService.grant)
	NetService.on(Net.Debug_Quarry, 1, 2, DebugService.quarry)
	NetService.on(Net.Debug_Blimp, 1, 2, DebugService.blimp)
	NetService.on(Net.Debug_Fuzz, 1, 1, DebugService.fuzz)
	NetService.on(Net.Debug_LevelUp, 2, 4, DebugService.levelUp)
	NetService.on(Net.Debug_Records, 2, 4, DebugService.records)
	NetService.on(Net.Debug_FillLots, 1, 2, DebugService.fillLots)
	NetService.on(Net.Debug_Population, 1, 2, DebugService.population)
end

return DebugService

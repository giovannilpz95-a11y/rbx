-- The Tool Trader (src/shared/ToolTrader, Config/ToolTrader): building it, its slots, the
-- offers it draws, trading and dumping, the power tools as Barn items, the Planetarium that
-- needs them and the model. Called from tests/run.luau.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local ArtToolTrader = require("../src/shared/Art/ToolTrader")
local Config = require("../src/shared/Config/ToolTrader")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Layout = require("../src/shared/Layout")
local Market = require("../src/shared/Market")
local Missing = require("../src/shared/Missing")
local OrderGen = require("../src/shared/OrderGen")
local Profile = require("../src/shared/Profile")
local ToolTrader = require("../src/shared/ToolTrader")
local Town = require("../src/shared/Config/Town")
local Unlocks = require("../src/shared/Unlocks")

local HOUR = 3600

local function farm(level: number): { [string]: any }
	local data = Profile.template()
	data.level = level
	data.tutorial.step = 0
	return data
end

local function count(map: { [string]: number }?): number
	local n = 0
	for _, qty in map or {} do
		n += qty
	end
	return n
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("tool trader: Township's Tool Exchange numbers", function()
		eq(Config.unlockLevel, 60, "at level 60")
		eq(Config.buildCoins, 12000, "12,000 Coins")
		eq(Config.population, 7100, "Population 7,100")
		eq(Config.buildSeconds, 12 * HOUR, "12 h")
		eq(Config.buildXp, 500, "500 XP")
		eq(#Config.slotCoins, ArtToolTrader.SLOTS, "three slots")
		eq(Config.slotCoins[2], 8000, "the second slot")
		eq(Config.slotCoins[3], 15000, "the third slot")
		eq(Config.toolsPerOffer[2], 4, "at most 4 tools an offer")
		eq(Config.dumpSeconds, HOUR, "an hour after a dump")
		eq(Config.tools.Jackhammer.unlockLevel, 62, "Jackhammers from 62")
		for _, id in Config.materials do
			ok(Town.materials[id] ~= nil, id .. " is a building material")
		end
		for id, tool in Config.tools do
			local item = Items[id]
			ok(item ~= nil, id .. " is an item")
			eq(item.kind, "Material", id .. " is a material")
			eq(item.sellPrice, 200, id .. " sells for 200 Coins, as in Township")
			ok(not Market.tradeable(id), id .. " can't go on the Market")
			eq(Missing.unitPrice(id), nil, id .. " can't be bought with Gems")
			ok(tool.displayName ~= "", id .. " has a name")
		end
	end)

	test("tool trader: build, offers, trade, dump, slots", function()
		local data = farm(59)
		eq(data.toolTrader.slots, 1, "a new save has the trader block")
		ok(not ToolTrader.canBuild(data, 9000), "not before 60")
		data.level = 60
		local okLow, why = ToolTrader.canBuild(data, 7000)
		ok(not okLow and why ~= nil, "needs Population 7,100")
		ok(ToolTrader.canBuild(data, 7100), "can build at 60 with Population 7,100")
		ToolTrader.build(data, 100, 777)
		eq(data.toolTrader.readyAt, 100 + Config.buildSeconds, "building timer")
		ok(not ToolTrader.canBuild(data, 9000), "only built once")
		ok(not ToolTrader.settle(data, 101), "no offers while building")
		ok(not ToolTrader.canTrade(data, 1, 101), "no trading while building")
		ok(ToolTrader.finishBuild(data, 200), "speed up")
		ok(ToolTrader.settle(data, 200), "the first offer arrives")
		ok(not ToolTrader.settle(data, 200), "settling twice changes nothing")
		local offer = ToolTrader.offer(data, 1) :: ToolTrader.Offer
		ok(offer.tools ~= nil and offer.cost ~= nil, "an offer of tools for materials")
		eq(ToolTrader.offer(data, 2), nil, "slot 2 isn't open")
		ok(not ToolTrader.canTrade(data, 2, 200), "only open slots trade")
		ok(not ToolTrader.canTrade(data, "1", 200), "a bad argument is refused")
		ok(ToolTrader.canTrade(data, 1, 200), "slot 1 can trade")
		local traded = ToolTrader.trade(data, 1)
		eq(traded, offer, "returns what was traded")
		eq(data.toolTrader.trades, 1, "trade counted")
		ok(
			ToolTrader.offer(data, 1) ~= offer and (ToolTrader.offer(data, 1) :: any).tools ~= nil,
			"a new offer at once"
		)

		ToolTrader.dump(data, 1, 300)
		eq((ToolTrader.offer(data, 1) :: any).waitUntil, 300 + HOUR, "a dump waits an hour")
		ok(not ToolTrader.canTrade(data, 1, 300), "nothing to trade while waiting")
		ok(not ToolTrader.canDump(data, 1, 300), "nothing to dump while waiting")
		ok(not ToolTrader.settle(data, 300 + HOUR - 1), "still waiting")
		ok(ToolTrader.skip(data, 1, 400), "Gems bring it now")
		ok((ToolTrader.offer(data, 1) :: any).tools ~= nil, "a new offer after the skip")
		ok(not ToolTrader.skip(data, 1, 400), "nothing to skip with an offer waiting")
		ToolTrader.dump(data, 1, 500)
		ok(ToolTrader.settle(data, 500 + HOUR), "the wait runs out")
		ok((ToolTrader.offer(data, 1) :: any).tools ~= nil, "a new offer after the wait")

		eq(ToolTrader.nextSlotCoins(data), 8000, "the second slot's price")
		ok(ToolTrader.canBuySlot(data, 600), "can buy a slot")
		ToolTrader.buySlot(data, 600)
		ok((ToolTrader.offer(data, 2) :: any).tools ~= nil, "the new slot gets an offer")
		ToolTrader.buySlot(data, 600)
		eq(data.toolTrader.slots, 3, "three slots")
		eq(ToolTrader.nextSlotCoins(data), nil, "no fourth")
		ok(not ToolTrader.canBuySlot(data, 600), "can't buy a fourth")
		ToolTrader.buySlot(data, 600)
		eq(data.toolTrader.slots, 3, "still three")
	end)

	test("tool trader: offers stay in Township's bounds", function()
		local data = farm(60)
		ToolTrader.build(data, 0, 4242)
		local seenTwo, seenSaw, seenDrill = false, false, false
		for _ = 1, 300 do
			local offer = ToolTrader.draw(data)
			local tools, cost = offer.tools :: { [string]: number }, offer.cost :: { [string]: number }
			local n = count(tools)
			ok(n >= Config.toolsPerOffer[1] and n <= Config.toolsPerOffer[2], "2 to 4 tools")
			local m = count(cost)
			ok(m >= n * Config.perTool[1] and m <= n * Config.perTool[2], "4 to 6 materials a tool")
			eq(tools.Jackhammer, nil, "no Jackhammers before 62")
			local kinds = 0
			for id, qty in cost do
				ok(table.find(Config.materials, id) ~= nil and qty > 0, "asks for building materials")
				kinds += 1
			end
			ok(kinds == 1 or kinds == 2, "one or two materials")
			seenTwo = seenTwo or kinds == 2
			seenSaw = seenSaw or tools.PowerSaw ~= nil
			seenDrill = seenDrill or tools.PowerDrill ~= nil
		end
		ok(seenTwo and seenSaw and seenDrill, "the draws vary")
		data.level = 62
		local hammer = false
		for _ = 1, 100 do
			hammer = hammer or (ToolTrader.draw(data).tools :: any).Jackhammer ~= nil
		end
		ok(hammer, "Jackhammers from 62")
		local a, b = farm(60), farm(60)
		ToolTrader.build(a, 0, 99)
		ToolTrader.build(b, 0, 99)
		eq(
			ToolTrader.describe(ToolTrader.draw(a).cost :: any, tostring),
			ToolTrader.describe(ToolTrader.draw(b).cost :: any, tostring),
			"the same seed, the same offer"
		)
		eq(
			ToolTrader.describe({ PowerSaw = 2, PowerDrill = 1 }, function(id)
				return Items[id].displayName
			end),
			"1 Power Drill, 2 Power Saw",
			"offer text"
		)
	end)

	test("tool trader: the Planetarium needs its tools; tools never go on orders", function()
		local planetarium = Town.community.Planetarium
		eq(planetarium.unlockLevel, 60, "Planetarium at 60")
		eq(planetarium.capBonus, 470, "Cap +470")
		eq(planetarium.materials.PowerDrill, 8, "8 Power Drills")
		eq(planetarium.materials.PowerSaw, 5, "5 Power Saws")
		eq(
			Missing.price(Missing.list(planetarium.materials, function()
				return 0
			end)),
			nil,
			"the missing tools can't be bought with Gems"
		)
		local data = farm(61)
		data.toolTrader.readyAt = 0
		local pool = OrderGen.makeablePool(data)
		for id in Config.tools do
			ok(table.find(pool, id) == nil, id .. " not on orders")
		end
		local found = false
		for _, entry in Unlocks.at(60) do
			found = found or entry.id == "ToolTrader"
		end
		ok(found, "the level-up screen names the Tool Trader")
	end)

	test("tool trader: wired into the server and client", function()
		local net = fs.readFile("src/server/Services/NetService.luau")
		ok(string.find(net, "toolTrader = data.toolTrader", 1, true) ~= nil, "the snapshot carries toolTrader")
		local main = fs.readFile("src/server/Main.server.luau")
		ok(string.find(main, "ToolTraderService.init()", 1, true) ~= nil, "the service starts")
		local client = fs.readFile("src/client/Main.client.luau")
		ok(string.find(client, "ToolTraderUi.init()", 1, true) ~= nil, "the panel registers")
		local reach = fs.readFile("src/client/Controllers/ReachController.luau")
		ok(string.find(reach, '"ToolTrader"', 1, true) ~= nil, "the counter opens the panel")
		local panels = fs.readFile("src/client/UI/Panels.luau")
		ok(string.find(panels, "buildNeeds()", 1, true) ~= nil, "Community cards list the tools they need")
	end)

	test("tool trader: the model, its states and its footprint", function()
		local _ = roblox
		local root = Instance.new("Model")
		local origin = CFrame.new(-6, 0, 12) * Kit.yaw(270)
		local parts = ArtToolTrader.build(root, origin)
		local n = Kit.countParts(root)
		ok(
			n <= ArtToolTrader.PARTS_MAX,
			string.format("Tool Trader has %d parts, budget %d", n, ArtToolTrader.PARTS_MAX)
		)
		eq(parts.body:GetAttribute("Interact"), "ToolTrader", "the counter opens the panel")
		ok(parts.body.CanQuery and parts.body.CanCollide, "a solid tap target")
		local fp = Layout.KINDS.trader
		eq(fp.w, ArtToolTrader.SIZE, "Layout footprint width")
		eq(fp.d, ArtToolTrader.SIZE, "Layout footprint depth")
		Kit.eachPart(root, function(p)
			local c = origin:PointToObjectSpace(p.CFrame.Position)
			ok(
				math.abs(c.X) <= ArtToolTrader.SIZE / 2 and math.abs(c.Z) <= ArtToolTrader.SIZE / 2,
				p.Name .. " inside the footprint"
			)
			local col = p.Color
			ok(not (col.R > 0.98 and col.G > 0.98 and col.B > 0.98), p.Name .. " not pure white")
			ok(p.CanTouch == false, p.Name .. " CanTouch off")
		end)
		local walls = root:FindFirstChild("Walls", true) :: BasePart
		local sign = root:FindFirstChild("LotSign", true) :: BasePart
		local crate = root:FindFirstChild("Crate3", true) :: BasePart
		ArtToolTrader.setState(root, "Lot")
		ok(walls.Transparency == 1 and not walls.CanCollide and sign.Transparency < 1, "an empty lot first")
		eq(crate.Transparency, 1, "no crates on the lot")
		ArtToolTrader.setState(root, "Open")
		ok(walls.Transparency < 1 and walls.CanCollide and sign.Transparency == 1, "the workshop once built")
		ArtToolTrader.setSlots(root, 2)
		ok((root:FindFirstChild("Crate2", true) :: BasePart).Transparency < 1, "two crates")
		eq(crate.Transparency, 1, "the third waits for its slot")
		ArtToolTrader.setSlots(root, 3)
		ok(crate.Transparency < 1, "three crates")
	end)
end

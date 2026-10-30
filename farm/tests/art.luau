-- Art model checks: every model builds outside Roblox, stays inside its part budget
-- (Design/15 3D World & Avatar Play §5, Design/16 Model Catalog), and follows the palette
-- rules (no pure black or white). Called from tests/run.luau.

local roblox = require("@lune/roblox")

-- The Art modules use Roblox's globals; Lune keeps them in @lune/roblox.
Instance = roblox.Instance
Vector3 = roblox.Vector3
CFrame = roblox.CFrame
Color3 = roblox.Color3
Enum = roblox.Enum
ColorSequence = roblox.ColorSequence
NumberSequence = roblox.NumberSequence
NumberRange = roblox.NumberRange
Vector2 = roblox.Vector2

local ArtAnimals = require("../src/shared/Art/Animals")
local ArtBuildings = require("../src/shared/Art/Buildings")
local ArtCommunity = require("../src/shared/Art/Community")
local ArtCrops = require("../src/shared/Art/Crops")
local ArtDecor = require("../src/shared/Art/Decor")
local Decor = require("../src/shared/Config/Decor")
local ArtFactories = require("../src/shared/Art/Factories")
local ArtHouses = require("../src/shared/Art/Houses")
local ArtItemProps = require("../src/shared/Art/ItemProps")
local ArtMotion = require("../src/shared/Art/Motion")
local ArtTownSquare = require("../src/shared/Art/TownSquare")
local Crops = require("../src/shared/Config/Crops")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Town = require("../src/shared/Config/Town")

local PENS = { "CowBarn", "ChickenCoop", "SheepFold" }
local FACTORIES = { "Bakery", "FeedMill", "Dairy", "SugarMill", "TextileMill" }
local PLOT_PARTS_MAX = 2500 -- whole plot at full expansion (15 §5)

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	local function within(root: Instance, max: number, what: string): number
		local n = Kit.countParts(root)
		ok(n > 0, what .. " built no parts")
		ok(n <= max, string.format("%s has %d parts, budget %d", what, n, max))
		return n
	end

	local function paletteRules(root: Instance, what: string)
		Kit.eachPart(root, function(p)
			local c = p.Color
			local black = c.R < 0.02 and c.G < 0.02 and c.B < 0.02
			local white = c.R > 0.98 and c.G > 0.98 and c.B > 0.98
			ok(not black and not white, what .. ": " .. p.Name .. " uses pure black or white")
			ok(p.CanTouch == false, what .. ": " .. p.Name .. " should have CanTouch off")
		end)
	end

	local function bed(): BasePart
		local p = Instance.new("Part")
		p.Size = Vector3.new(8, 1, 8)
		p.CFrame = CFrame.new(0, 0.5, 0)
		return p
	end

	test("art: a field bed stays within 4 parts", function()
		local b = bed()
		ArtCrops.dressBed(b)
		within(b, ArtCrops.BED_PARTS_MAX, "field bed")
	end)

	test("art: every crop builds all 4 stages within budget", function()
		for id, def in Crops do
			for stage = 1, 4 do
				local m = ArtCrops.build(id, stage, CFrame.new(0, 1, 0), def.color)
				within(m, ArtCrops.STAGE_PARTS_MAX, id .. " stage " .. stage)
				paletteRules(m, id)
				eq(m.Name, "Crop", "crop model name")
			end
		end
	end)

	test("art: a ready Prize Crop shimmers in its tier's colour", function()
		for tier in ArtCrops.PRIZE_COLORS do
			local crop = ArtCrops.build("Wheat", 4, CFrame.new(0, 1, 0), nil)
			local ring = ArtCrops.prizeShimmer(crop, tier, CFrame.new(0, 1, 0), 8)
			ok(ring ~= nil and ring:IsDescendantOf(crop), tier .. " ring in the crop model")
			ok((ring :: BasePart):FindFirstChildOfClass("ParticleEmitter") ~= nil, tier .. " sparkles")
			eq((ring :: BasePart).CanQuery, false, tier .. " ring lets taps through")
		end
		eq(ArtCrops.prizeShimmer(Instance.new("Model"), "Plain", CFrame.new(), 8), nil, "unknown tier")
	end)

	test("art: crop stages follow growth", function()
		eq(ArtCrops.stageFor(0, false), 1, "just planted")
		eq(ArtCrops.stageFor(0.3, false), 2, "sprout")
		eq(ArtCrops.stageFor(0.8, false), 3, "growing")
		eq(ArtCrops.stageFor(0.1, true), 4, "sped up to ready")
		for _, id in { "Wheat", "Corn", "Carrots", "Sugarcane", "Cotton" } do
			ok(ArtCrops.hasCustomLook(id), id .. " has its own look")
		end
	end)

	test("art: animals and pens stay within budget", function()
		for _, id in PENS do
			local a = ArtAnimals.animal(id, CFrame.new())
			within(a, ArtAnimals.ANIMAL_PARTS_MAX, id .. " animal")
			paletteRules(a, id)
			within(ArtAnimals.product(id, CFrame.new()), 4, id .. " product")
			local pen = Instance.new("Model")
			ArtAnimals.pen(id, CFrame.new(), pen)
			within(pen, ArtAnimals.PEN_PARTS_MAX, id .. " pen")
			paletteRules(pen, id)
			ok(ArtAnimals.FLOOR_COLOR[id] ~= nil, id .. " floor color")
		end
	end)

	test("art: factories have their tap targets and stay within budget", function()
		for _, id in FACTORIES do
			ok(ArtFactories.has(id), id .. " has a model")
			local m = Instance.new("Model")
			local parts = ArtFactories.build(id, m, CFrame.new())
			within(m, ArtFactories.PARTS_MAX, id)
			paletteRules(m, id)
			eq(parts.body.Name, "Body", id .. " body")
			eq(parts.outputTable.Name, "OutputTable", id .. " table")
			ok(parts.body.CanQuery and parts.outputTable.CanQuery, id .. " targets are tappable")
			ok(parts.window:IsDescendantOf(m) and parts.chimney:IsDescendantOf(m), id .. " window and chimney")
			-- The plot puts the table at LAYOUT.factoryOutputOffset (10 studs in front)
			ok(math.abs(parts.outputTable.CFrame.Position.Z - ArtFactories.TABLE_Z) < 0.01, id .. " table position")
		end
	end)

	test("art: every decoration builds inside its footprint and budget", function()
		for id, def in Decor.items do
			ok(ArtDecor.has(id), "decoration model for " .. id)
			local root = Instance.new("Part")
			root.CanTouch = false
			ArtDecor.build(id, root, CFrame.new())
			local max = if ArtDecor.isPath(id) then ArtDecor.PATH_PARTS_MAX else ArtDecor.PARTS_MAX
			-- Count only the parts under root
			local n = Kit.countParts(root) - 1
			ok(n > 0 and n <= max, string.format("%s has %d parts, budget %d", id, n, max))
			paletteRules(root, id)
			local hw, hd = def.size[1] * Decor.tile / 2, def.size[2] * Decor.tile / 2
			Kit.eachPart(root, function(p)
				if p ~= root then
					local c = p.CFrame.Position
					ok(math.abs(c.X) <= hw and math.abs(c.Z) <= hd, id .. ": " .. p.Name .. " inside its footprint")
					ok(p.CanQuery, id .. ": " .. p.Name .. " can be tapped")
				end
			end)
		end
	end)

	test("art: every factory's moving part works and returns to rest", function()
		for _, id in FACTORIES do
			local m = Instance.new("Model")
			ArtFactories.build(id, m, CFrame.new(10, 0, 5) * Kit.yaw(90))
			local rig = ArtMotion.bind(id, m)
			ok(rig ~= nil, id .. " has a motion rig")
			local r = rig :: ArtMotion.Rig
			ok(#r.parts > 0, id .. " moves some parts")
			local before = {}
			for i, p in r.parts do
				before[i] = { cf = p.CFrame, color = p.Color }
			end
			ArtMotion.pose(r, 0.7)
			local changed = false
			for i, p in r.parts do
				local was = before[i]
				if (p.CFrame.Position - was.cf.Position).Magnitude > 0.01 or not p.CFrame:FuzzyEq(was.cf, 1e-3) then
					changed = true
				end
				if p.Color ~= was.color then
					changed = true
				end
				if r.spec.kind == "spin" then
					-- Spinning keeps every part the same distance from the pivot
					local d0 = (was.cf.Position - r.pivot.Position).Magnitude
					local d1 = (p.CFrame.Position - r.pivot.Position).Magnitude
					ok(math.abs(d0 - d1) < 1e-3, id .. ": " .. p.Name .. " stays on its axis")
				elseif r.spec.kind == "bob" then
					ok(p.CFrame.Position.Y > was.cf.Position.Y, id .. ": " .. p.Name .. " lifts up")
				end
			end
			ok(changed, id .. " moves at t = 0.7")
			ArtMotion.reset(r)
			for i, p in r.parts do
				ok(
					(p.CFrame.Position - before[i].cf.Position).Magnitude < 1e-3,
					id .. ": " .. p.Name .. " back at rest"
				)
				ok(p.Color == before[i].color, id .. ": " .. p.Name .. " colour back")
			end
		end
		eq(ArtMotion.bind("NoSuchFactory", Instance.new("Model")), nil, "unknown factory")
	end)

	test("art: every item has a small prop for its icon", function()
		local half = ArtItemProps.SIZE / 2 + 0.3
		for id in Items do
			ok(ArtItemProps.has(id), "prop for " .. id)
			local m = ArtItemProps.build(id)
			eq(m.Name, id, id .. " model name")
			within(m, ArtItemProps.PARTS_MAX, id .. " prop")
			paletteRules(m, id)
			Kit.eachPart(m, function(p)
				ok(p.CanQuery == false, id .. ": " .. p.Name .. " lets taps through")
				-- Each part's centre stays inside the icon box, standing on the ground
				local c = p.CFrame.Position
				ok(math.abs(c.X) <= half and math.abs(c.Z) <= half, id .. ": " .. p.Name .. " inside the box")
				ok(c.Y >= -0.1 and c.Y <= ArtItemProps.SIZE + 0.3, id .. ": " .. p.Name .. " height")
			end)
		end
		within(ArtItemProps.build("NoSuchItem"), ArtItemProps.PARTS_MAX, "fallback crate")
	end)

	test("art: Barn, Order Board, truck and gate stay within budget", function()
		local m = Instance.new("Model")
		local barn = ArtBuildings.barn(m, CFrame.new(), 14, 16)
		eq(barn.Name, "Barn", "barn body")
		within(m, ArtBuildings.BARN_PARTS_MAX, "Barn")
		paletteRules(m, "Barn")

		local board = Instance.new("Part")
		board.Size = Vector3.new(0.5, 7, 10)
		board.CFrame = CFrame.new(0, 6, 0)
		ArtBuildings.orderBoard(board, 6)
		within(board, ArtBuildings.BOARD_PARTS_MAX, "Order Board")

		local truck = Instance.new("Part")
		truck.Size = Vector3.new(6, 3, 10)
		truck.CFrame = CFrame.new(0, 2.5, 0)
		ArtBuildings.truck(truck)
		within(truck, ArtBuildings.TRUCK_PARTS_MAX, "truck")
		eq(truck:GetAttribute("Hidden"), true, "truck root hidden")
		Kit.eachPart(truck, function(p)
			if p ~= truck then
				ok(not p.Anchored and p:FindFirstChildOfClass("WeldConstraint") ~= nil, "truck part welded: " .. p.Name)
			end
		end)

		local g = Instance.new("Model")
		local sign = ArtBuildings.gate(g, CFrame.new())
		eq(sign.Name, "GateSign", "gate sign")
		within(g, 25, "gate")
	end)

	test("art: every House and Community Building builds within budget", function()
		for id in Town.houses do
			ok(ArtHouses.has(id), "house model for " .. id)
			for _, size in { 8, 10 } do
				local m = Instance.new("Model")
				local body = ArtHouses.build(id, m, CFrame.new(), { size = size })
				ok(body:IsDescendantOf(m), id .. " body")
				within(m, ArtHouses.PARTS_MAX, id .. " at " .. size)
				paletteRules(m, id)
			end
		end
		for id in Town.community do
			ok(ArtCommunity.has(id), "community model for " .. id)
			local m = Instance.new("Model")
			ArtCommunity.build(id, m, CFrame.new(), 12)
			within(m, ArtCommunity.PARTS_MAX, id)
			paletteRules(m, id)
		end
	end)

	test("art: the Town Square stays within its budget, with its three boards and the Puzzle Porch", function()
		local m = Instance.new("Model")
		local square = ArtTownSquare.build(m, CFrame.new())
		within(square.model, ArtTownSquare.PARTS_MAX, "Town Square")
		paletteRules(square.model, "Town Square")
		for _, name in { "Notice", "Neighbors", "Market" } do
			ok(square.boards[name] ~= nil and square.boards[name].CanQuery, name .. " board is a tap target")
		end
		ok(square.porch.CanQuery and square.porch.Name == "PuzzlePorch", "the Puzzle Porch is a tap target")
	end)

	test("art: Kit.fade keeps glass see-through and hidden roots hidden", function()
		local m = Instance.new("Model")
		local b = Kit.builder(m, CFrame.new(), false)
		local glass =
			b.block("Glass", Vector3.new(1, 1, 1), Vector3.zero, Color3.fromRGB(100, 150, 200), { transparency = 0.4 })
		local root = b.block("Root", Vector3.new(1, 1, 1), Vector3.zero, Color3.fromRGB(100, 150, 200))
		Kit.hide(root)
		Kit.fade(m, 1)
		eq(glass.Transparency, 1, "faded out")
		Kit.fade(m, 0)
		ok(math.abs(glass.Transparency - 0.4) < 1e-6, "glass back to 0.4")
		eq(root.Transparency, 1, "root stays hidden")
	end)

	test("art: a fully built MVP plot stays inside the plot part budget", function()
		local total = 0
		local function add(root: Instance, copies: number)
			total += Kit.countParts(root) * copies
		end
		-- 22 fields with ready Corn (the tallest MVP stage) on dressed beds
		local b = bed()
		ArtCrops.dressBed(b)
		add(b, 22)
		add(ArtCrops.build("Corn", 4, CFrame.new(), nil), 22)
		for _, id in PENS do
			local pen = Instance.new("Model")
			ArtAnimals.pen(id, CFrame.new(), pen)
			add(pen, 1)
			add(ArtAnimals.animal(id, CFrame.new()), 6)
			add(ArtAnimals.product(id, CFrame.new()), 6)
		end
		-- Every factory with a full output tray (8 goods) of its biggest prop
		local biggestProp = 0
		for id in Items do
			biggestProp = math.max(biggestProp, Kit.countParts(ArtItemProps.build(id)))
		end
		for _, id in FACTORIES do
			local m = Instance.new("Model")
			ArtFactories.build(id, m, CFrame.new())
			add(m, 1)
			total += biggestProp * 8
		end
		-- Barn, board, dock, truck, gate, decoration: use their budgets
		total += ArtBuildings.BARN_PARTS_MAX + ArtBuildings.BOARD_PARTS_MAX + 4 + ArtBuildings.TRUCK_PARTS_MAX + 25 + 40
		-- Every House a level-12 player can own, and every Community Building
		for id, def in Town.houses do
			local copies = 0
			for _, level in def.copyLevels do
				if level <= 12 then
					copies += 1
				end
			end
			local m = Instance.new("Model")
			ArtHouses.build(id, m, CFrame.new(), { size = 8 })
			add(m, copies)
		end
		for id in Town.community do
			local m = Instance.new("Model")
			ArtCommunity.build(id, m, CFrame.new(), 12)
			add(m, 1)
		end
		print(string.format("      full level-12 plot estimate: %d parts", total))
		ok(total <= PLOT_PARTS_MAX, string.format("full plot estimate %d parts, budget %d", total, PLOT_PARTS_MAX))
	end)
end

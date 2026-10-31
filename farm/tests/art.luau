-- Art model checks: every model builds outside Roblox, stays inside its part budget
-- (Design/15 3D World & Avatar Play §5, Design/16 Model Catalog), and follows the palette
-- rules (no pure black or white). Called from tests/run.luau.

local fs = require("@lune/fs")
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
local ArtMarket = require("../src/shared/Art/Market")
local ArtMerge = require("../src/shared/Art/Merge")
-- What Merge offers as soon as it loads, before any test calls into it (a function defined
-- inside another one would only show up after that one ran)
local MERGE_AT_LOAD = { ArtMerge.leader, ArtMerge.mergeShell, ArtMerge.countShell, ArtMerge.parts }
local ArtRail = require("../src/shared/Art/Rail")
local Decor = require("../src/shared/Config/Decor")
local Records = require("../src/shared/Config/Records")
local Trophies = require("../src/shared/Config/Trophies")
local ArtFactories = require("../src/shared/Art/Factories")
local Palette = require("../src/shared/Art/Palette")
local ArtFolk = require("../src/shared/Art/Folk")
local ArtGuild = require("../src/shared/Art/Guild")
local ArtHouses = require("../src/shared/Art/Houses")
local ArtItemProps = require("../src/shared/Art/ItemProps")
local ArtMotion = require("../src/shared/Art/Motion")
local ArtPickups = require("../src/shared/Art/Pickups")
local ArtQuarry = require("../src/shared/Art/Quarry")
local ArtBlimp = require("../src/shared/Art/Blimp")
local ArtTown = require("../src/shared/Art/Town")
local Land = require("../src/shared/Config/Land")
local ArtTownSquare = require("../src/shared/Art/TownSquare")
local Animals = require("../src/shared/Config/Animals")
local Crops = require("../src/shared/Config/Crops")
local Factories = require("../src/shared/Config/Factories")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Levels = require("../src/shared/Config/Levels")
local Recipes = require("../src/shared/Config/Recipes")
local Tools = require("../src/shared/Config/Tools")
local Town = require("../src/shared/Config/Town")

local PENS = { "CowBarn", "ChickenCoop", "SheepFold" }
-- Every factory up to the highest built level, in unlock order
local FACTORIES = {}
for id, def in Factories do
	if def.unlockLevel <= Levels.built then
		table.insert(FACTORIES, id)
	end
end
table.sort(FACTORIES, function(a, b)
	return Factories[a].order < Factories[b].order
end)
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

	test("art: the VIP gold fence builds inside one tile and its budget", function()
		local root = Instance.new("Part")
		ok(ArtDecor.has("GoldFence"), "gold fence model")
		ArtDecor.build("GoldFence", root, CFrame.new())
		local n = Kit.countParts(root) - 1
		ok(n > 0 and n <= ArtDecor.PARTS_MAX, "gold fence has " .. n .. " parts")
		Kit.eachPart(root, function(p)
			local c = p.CFrame.Position
			ok(p == root or (math.abs(c.X) <= 2 and math.abs(c.Z) <= 2), "gold fence: " .. p.Name .. " inside its tile")
		end)
	end)

	-- A Luau table literal with a repeated key keeps the last one silently, so an id reused for
	-- a new decoration would replace the older one's entry and model. Scan the sources instead.
	test("art: decoration ids and builders are never defined twice", function()
		for _, file in
			{
				{ "src/shared/Config/Decor.luau", "\n\t([%w_]+) = {" },
				{ "src/shared/Art/Decor.luau", "\n\t([%w_]+) = function" },
			}
		do
			local seen = {}
			for id in string.gmatch(fs.readFile(file[1]), file[2]) do
				ok(not seen[id], file[1] .. " defines " .. id .. " twice")
				seen[id] = true
			end
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

	test("art: every Town Record has a gold trophy inside its footprint and budget", function()
		for _, record in Records.list do
			local def = Trophies.byRecord[record.id]
			ok(def ~= nil, "trophy for " .. record.id)
			if def == nil then
				continue
			end
			ok(ArtDecor.has(def.id), "trophy model for " .. def.id)
			ok(Decor.items[def.id] == nil, def.id .. " is never sold in the shop")
			local root = Instance.new("Part")
			root.CanTouch = false
			ArtDecor.build(def.id, root, CFrame.new())
			local n = Kit.countParts(root) - 1
			ok(n > 0 and n <= ArtDecor.PARTS_MAX, string.format("%s has %d parts", def.id, n))
			paletteRules(root, def.id)
			local hw, hd = def.size[1] * Decor.tile / 2, def.size[2] * Decor.tile / 2
			Kit.eachPart(root, function(p)
				if p ~= root then
					local c = p.CFrame.Position
					ok(math.abs(c.X) <= hw and math.abs(c.Z) <= hd, def.id .. ": " .. p.Name .. " inside its footprint")
					ok(p.CanQuery, def.id .. ": " .. p.Name .. " can be tapped")
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

	test("art: empty fields look freshly dug, and tools have props", function()
		local m = ArtCrops.tilled(CFrame.new(0, 1, 0))
		eq(m.Name, "Crop", "tilled model name")
		within(m, ArtCrops.STAGE_PARTS_MAX, "tilled field")
		paletteRules(m, "tilled field")
		for id in Tools.tools do
			ok(ArtItemProps.has(id), "prop for tool " .. id)
			local prop = ArtItemProps.build(id)
			within(prop, ArtItemProps.PARTS_MAX, id .. " prop")
			paletteRules(prop, id)
			Kit.eachPart(prop, function(p)
				local c = p.CFrame.Position
				ok(math.abs(c.X) <= 1.5 and c.Y >= -0.1 and c.Y <= 2.5, id .. ": " .. p.Name .. " inside the icon box")
			end)
		end
	end)

	test("art: pens show feed, the crate lid, and animals carry what their motion needs", function()
		for _, id in PENS do
			local pen = Instance.new("Model")
			ArtAnimals.pen(id, CFrame.new(), pen)
			local feed = pen:FindFirstChild("Feed", true) :: BasePart
			local lid = pen:FindFirstChild("Lid", true) :: BasePart
			ok(feed ~= nil and lid ~= nil, id .. " has a trough and a crate")
			local closed = lid.CFrame
			ArtAnimals.setPenState(pen, false, true)
			eq(feed.Transparency, 1, id .. " hungry: empty trough")
			ok(lid.CFrame.Position.Y > closed.Position.Y, id .. " lid swings up while products wait")
			Kit.fade(pen, 0)
			ArtAnimals.setPenState(pen, true, false)
			eq(feed.Transparency, 0, id .. " fed: feed shows")
			ok(lid.CFrame.Position:FuzzyEq(closed.Position, 1e-3), id .. " lid closed")

			local animal = ArtAnimals.animal(id, CFrame.new(3, 0.6, 2))
			local rig = ArtMotion.bindAnimal(animal, 0)
			ok(rig ~= nil, id .. " animal has a motion rig")
			local r = rig :: ArtMotion.AnimalRig
			local first = r.parts[1]
			local rest = first.CFrame
			for _, mood in { "hungry", "eating", "ready" } do
				for _, t in { 0.3, 1.1, 2.7 } do
					ArtMotion.poseAnimal(r, mood, t)
					ok(
						(first.CFrame.Position - rest.Position).Magnitude < 1,
						id .. " " .. mood .. " stays near its spot"
					)
				end
			end
			ArtMotion.resetAnimal(r)
			ok(first.CFrame.Position:FuzzyEq(rest.Position, 1e-4), id .. " animal back at rest")
		end
	end)

	test("art: pen gates swing and upgrade looks stay within budget", function()
		for _, id in PENS do
			local pen = Instance.new("Model")
			ArtAnimals.pen(id, CFrame.new(), pen)
			local base = within(pen, ArtAnimals.PEN_PARTS_MAX, id .. " pen")
			local gate = pen:FindFirstChild("Gate", true) :: BasePart
			ok(gate ~= nil, id .. " has a gate")
			local shut = ArtMotion.gateCFrame(gate, 0) :: CFrame
			local open = ArtMotion.gateCFrame(gate, 1) :: CFrame
			ok(shut.Position:FuzzyEq(gate.CFrame.Position, 1e-3), id .. " gate shut at 0")
			ok(open.Position.Z > shut.Position.Z + 0.5, id .. " gate swings inward")
			local trough = pen:FindFirstChild("Trough", true) :: BasePart
			local built = trough.Color
			for level = 1, ArtAnimals.PEN_LEVEL_MAX do
				ArtAnimals.setPenLevel(pen, id, level)
				local n = Kit.countParts(pen)
				ok(
					n - base <= ArtAnimals.UPGRADE_PARTS_MAX,
					string.format("%s level %d adds %d parts", id, level, n - base)
				)
				paletteRules(pen, id .. " level " .. level)
			end
			eq(trough.Color, ArtAnimals.ACCENT[id], id .. " trough painted at level 5")
			ok(pen:FindFirstChild("Upgrade") ~= nil, id .. " has its level 5 add-ons")
			ArtAnimals.setPenLevel(pen, id, 1)
			eq(trough.Color, built, id .. " trough back to bare wood")
			eq(Kit.countParts(pen), base, id .. " level 1 has no add-ons")
		end
	end)

	test("art: Barn looks, overflow, Tool Shed and held tools", function()
		eq(ArtBuildings.barnLookFor(3), 1, "look 1 up to upgrade 3")
		eq(ArtBuildings.barnLookFor(4), 2, "look 2 from upgrade 4")
		local m = Instance.new("Model")
		local barn = ArtBuildings.barn(m, CFrame.new(), 14, 16)
		local base = Kit.countParts(m)
		ArtBuildings.setBarnLook(barn, 2)
		ArtBuildings.setBarnOverflow(barn, 1)
		within(m, ArtBuildings.BARN_PARTS_MAX, "Barn look 2, full")
		paletteRules(m, "Barn look 2")
		ArtBuildings.setBarnOverflow(barn, 0.75)
		eq(#(barn:FindFirstChild("Overflow") :: Instance):GetChildren(), 3, "three crates at 75%")
		ArtBuildings.setBarnLook(barn, 1)
		ArtBuildings.setBarnOverflow(barn, 0.5)
		eq(Kit.countParts(m), base, "back to look 1 with no pile")

		local shedModel = Instance.new("Model")
		local shed = ArtBuildings.toolShed(shedModel, CFrame.new())
		eq(shed.Name, "ToolShed", "shed tap target")
		local bare = Kit.countParts(shedModel)
		ArtBuildings.setToolShedTools(shed, { Shovel = 2, Axe = 1, Saw = 4 })
		within(shedModel, ArtBuildings.TOOLSHED_PARTS_MAX, "Tool Shed with every tool")
		paletteRules(shedModel, "Tool Shed")
		ArtBuildings.setToolShedTools(shed, { Shovel = 1 })
		eq(#shed:GetChildren() > 0 and Kit.countParts(shedModel) > bare, true, "a Shovel shows")
		ArtBuildings.setToolShedTools(shed, {})
		eq(Kit.countParts(shedModel), bare, "no tools, bare pegboard")

		for _, id in { "Tool_Scythe", "Tool_SeedBag", "Tool_WateringCan" } do
			ok(ArtItemProps.hasHeld(id), id .. " exists")
			local tool = ArtItemProps.held(id) :: Model
			within(tool, ArtItemProps.PARTS_MAX, id)
			paletteRules(tool, id)
		end
		eq(ArtItemProps.held("Nope"), nil, "unknown held tool")
	end)

	test("art: wool regrows, ready crops sparkle and harvests fly to the Barn", function()
		eq(ArtMotion.woolScale("hungry", 0.5), 0.6, "just shorn")
		eq(ArtMotion.woolScale("ready", 0), 1, "full fleece when ready")
		ok(math.abs(ArtMotion.woolScale("eating", 0.5) - 0.8) < 1e-6, "half grown")
		eq(ArtMotion.woolScale("eating", 3), 1, "clamped")
		local sheep = ArtAnimals.animal("SheepFold", CFrame.new())
		local rig = ArtMotion.bindAnimal(sheep, 0) :: ArtMotion.AnimalRig
		ok(#rig.wool >= 3, "sheep wool puffs found")
		local full = rig.wool[1].Size
		ArtMotion.setWool(rig, 0.6)
		ok(rig.wool[1].Size:FuzzyEq(full * 0.6, 1e-4), "wool shrinks")
		eq(
			#(ArtMotion.bindAnimal(ArtAnimals.animal("CowBarn", CFrame.new()), 0) :: ArtMotion.AnimalRig).wool,
			0,
			"cows have no wool"
		)

		local crop = ArtCrops.build("Wheat", 4, CFrame.new(), nil)
		ok(ArtCrops.readySparkle(crop) ~= nil, "ready sparkle added")
		within(crop, ArtCrops.STAGE_PARTS_MAX, "ready Wheat with sparkle")

		local from, to = Vector3.new(0, 1, 0), Vector3.new(20, 5, 10)
		local p0 = ArtMotion.harvestPath(from, to, 0)
		local p1, s1 = ArtMotion.harvestPath(from, to, 1)
		ok(p0:FuzzyEq(from, 1e-4), "starts at the field")
		ok(p1:FuzzyEq(to, 1e-4), "ends at the Barn")
		ok(s1 < 0.5, "shrinks into the Barn")
		local top = ArtMotion.harvestPath(from, to, 0.25)
		ok(top.Y > from.Y + 2, "hops up first")
		ok(ArtMotion.cropSway(1.3).Position:FuzzyEq(Vector3.zero, 1e-6), "sway only rotates")
	end)

	test("art: finished buildings and decorations merge into one part at runtime", function()
		-- A stand-in for GeometryService: one plain part where the union would be
		local calls = 0
		local stub = {
			UnionAsync = function(_self, primary: BasePart, parts: { BasePart }, _options)
				calls += 1
				local u = Instance.new("Part")
				u.CFrame = primary.CFrame * CFrame.new(0, 2, 0)
				u.Size = Vector3.new(4, 4, 4)
				return { u }
			end,
		}
		local failing = {
			UnionAsync = function()
				error("CSG failed")
			end,
		}
		local function house(): (Model, BasePart)
			local folder = Instance.new("Folder")
			local m = Instance.new("Model")
			local body = ArtHouses.build("Cottage", m, CFrame.new(), { size = 8 })
			body:SetAttribute("Interact", "Town")
			local gui = Instance.new("BillboardGui")
			gui.Name = "Label"
			gui.Parent = body
			m.Parent = folder
			return m, body
		end

		-- Every House and Community Building has something to merge and few parts left over
		for id in Town.houses do
			local m = Instance.new("Model")
			local body = ArtHouses.build(id, m, CFrame.new(), { size = 8 })
			local merge = ArtMerge.split(m, body)
			ok(#merge > 0, id .. " has parts to merge")
			ok(ArtMerge.count(m, body) <= 3, id .. " merges down to 3 parts or fewer")
		end
		for id, def in Town.community do
			if def.townHallStorey then
				continue -- builds onto the Town Hall
			end
			local m = Instance.new("Model")
			local body = ArtCommunity.build(id, m, CFrame.new(), 12)
			ok(ArtMerge.count(m, body) <= 8, id .. " merges down to 8 parts or fewer")
		end

		for i = 1, 4 do
			eq(type(MERGE_AT_LOAD[i]), "function", "every Merge function is there as soon as the module loads")
		end

		local m, body = house()
		local _, keep = ArtMerge.split(m, body)
		local union = ArtMerge.merge(m, body, nil, stub)
		ok(union ~= body, "merged")
		eq(calls, 1, "one union per building")
		eq(union.Name, "Body", "the union takes the body's name")
		eq(union:GetAttribute("Interact"), "Town", "and its tap target")
		eq(union.Parent, m, "in the building's model")
		eq(Kit.countParts(m), 1 + #keep, "the merged parts are gone")
		local label = union:FindFirstChild("Label") :: BillboardGui
		ok(label ~= nil and label.Adornee ~= nil and label.Adornee.Name == "BodyAnchor", "label kept at the old body")
		ok(body.Parent == nil, "the old body is gone")

		local m2, body2 = house()
		local before = Kit.countParts(m2)
		eq(ArtMerge.merge(m2, body2, nil, failing), body2, "a failed union leaves the building as it was")
		eq(Kit.countParts(m2), before, "every part stays")

		local m3, body3 = house()
		m3.Parent = nil -- rebuilt while the union was being made
		eq(ArtMerge.merge(m3, body3, nil, stub), body3, "a building taken away keeps its parts")
		eq(ArtMerge.merge(m3, body3, nil, nil), body3, "no GeometryService outside Roblox: nothing happens")

		-- Decorations: the look under the invisible tap root becomes one "Look", and the
		-- lamp's Neon lantern stays its own part
		local folder = Instance.new("Folder")
		local root = Instance.new("Part")
		root.Parent = folder
		ArtDecor.build("LampPost", root, CFrame.new())
		local look = ArtMerge.mergeUnder(root, stub)
		ok(look ~= nil and look.Name == "Look" and look.Parent == root, "decoration look merged under its root")
		ok(look ~= nil and look.CanCollide, "the lamp post still blocks the avatar")
		ok(root:FindFirstChild("Lantern") ~= nil, "the glowing lantern stays separate")

		-- Factories: walls, roof and trim merge around the body; the gimmick, output table and
		-- glow parts stay so they can move, take taps and light up
		for _, id in FACTORIES do
			local fm = Instance.new("Model")
			fm.Parent = folder
			local parts = ArtFactories.build(id, fm, CFrame.new())
			local before = Kit.countParts(fm)
			local animParts = Kit.countParts(parts.anim)
			local glows = {}
			for _, glow in { "OvenGlow", "NeonSign", "FurnaceGlow" } do
				if fm:FindFirstChild(glow, true) then
					table.insert(glows, glow)
				end
			end
			local expected = ArtMerge.count(fm, parts.body, ArtFactories.MERGE_SKIP)
			local union = ArtMerge.merge(fm, parts.body, { skip = ArtFactories.MERGE_SKIP }, stub)
			ok(union ~= parts.body and union.Parent == fm, id .. " merged")
			ok(Kit.countParts(fm) < before - 10, id .. " merge saves parts")
			eq(Kit.countParts(fm), expected, id .. " part count matches the estimate")
			eq(Kit.countParts(parts.anim), animParts, id .. " gimmick untouched")
			ok(fm:FindFirstChild("OutputTable", true) ~= nil, id .. " keeps its output table")
			ok(fm:FindFirstChild("TableTop", true) ~= nil, id .. " keeps the table top")
			for _, glow in glows do
				ok(fm:FindFirstChild(glow, true) ~= nil, id .. " keeps its " .. glow)
			end
		end

		-- Pens: fences and shelter become one walk-through, tap-through "Shell"; the floor,
		-- gate, feed, crate lid, animals and the coop's solid house stay as they are
		for id in ArtAnimals.ACCENT do
			local pen = Instance.new("Model")
			pen.Parent = folder
			local floor = Instance.new("Part")
			floor.Name = "Floor"
			floor.Parent = pen
			ArtAnimals.pen(id, CFrame.new(), pen)
			local animal = ArtAnimals.animal(id, CFrame.new(), "Animal_1")
			animal.Parent = pen
			local before = Kit.countParts(pen)
			local expected = ArtMerge.countShell(pen, ArtAnimals.SHELL_SKIP)
			ok(expected < before - 10, id .. " shell merge saves parts")
			local shell = ArtMerge.mergeShell(pen, ArtAnimals.SHELL_SKIP, stub)
			ok(shell ~= nil and shell.Name == "Shell" and shell.Parent == pen, id .. " shell merged")
			ok(
				shell ~= nil and not shell.CanCollide and not shell.CanQuery,
				id .. " shell lets avatars and taps through"
			)
			eq(Kit.countParts(pen), expected, id .. " part count matches the estimate")
			for _, name in { "Floor", "Gate", "Feed", "Lid" } do
				ok(pen:FindFirstChild(name, true) ~= nil, id .. " keeps its " .. name)
			end
			eq(
				Kit.countParts(pen:FindFirstChild("Animal_1") :: Instance),
				Kit.countParts(animal),
				id .. " animal untouched"
			)
			if id == "ChickenCoop" then
				ok(pen:FindFirstChild("House", true) ~= nil, "the coop's solid house stays")
			end
		end
	end)

	test("art: train set and Market stall build within budget", function()
		local function hinged(root: Instance, name: string)
			local found = 0
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") and d.Name == name then
					found += 1
					ok(typeof(d:GetAttribute("HingeCFrame")) == "CFrame", name .. " has a hinge")
				end
			end
			ok(found > 0, name .. " exists")
		end
		local function inside(root: Instance, half: Vector3, what: string)
			Kit.eachPart(root, function(p)
				local c = p.CFrame.Position
				ok(
					math.abs(c.X) <= half.X and math.abs(c.Z) <= half.Z,
					what .. ": " .. p.Name .. " inside its footprint"
				)
			end)
		end

		local m = Instance.new("Model")
		local station, board, crane = ArtRail.station(m, CFrame.new())
		eq(station.Name, "TrainStation", "station model")
		eq(board.Name, "DepartureBoard", "departure board")
		ok(crane:IsDescendantOf(station), "crane belongs to the station")
		within(m, ArtRail.STATION_PARTS_MAX, "Train Station")
		paletteRules(m, "Train Station")
		inside(m, ArtRail.STATION_SIZE / 2, "Train Station")
		hinged(crane, "Jib")
		hinged(station, "ClockHand")

		local e = Instance.new("Model")
		ArtRail.engine(e, CFrame.new())
		within(e, ArtRail.ENGINE_PARTS_MAX, "Engine")
		paletteRules(e, "Engine")
		ok(e:FindFirstChild("Stack", true) ~= nil, "engine has a smokestack for puffs")

		local c = Instance.new("Model")
		local car, sign = ArtRail.cargoCar(c, CFrame.new())
		eq(sign.Name, "ItemSign", "cargo car sign")
		local base = Kit.countParts(c)
		for n = 0, ArtRail.CAR_CRATES do
			ArtRail.setCarCrates(car, n)
			eq(Kit.countParts(c), base + n, n .. " crates shown")
		end
		ArtRail.setCarCrates(car, 9)
		eq(Kit.countParts(c), base + ArtRail.CAR_CRATES, "never more than the slots")
		within(c, ArtRail.CAR_PARTS_MAX, "Cargo car")
		paletteRules(c, "Cargo car")

		local h = Instance.new("Model")
		ArtRail.helpCrate(h, CFrame.new())
		within(h, ArtRail.HELPCRATE_PARTS_MAX, "Help Crate")
		hinged(h, "HelpFlag")
		for _, kind in ArtRail.TRACK_TYPES do
			local t = Instance.new("Model")
			ArtRail.track(kind, t, CFrame.new())
			within(t, ArtRail.TRACK_PARTS_MAX, kind .. " track")
			paletteRules(t, kind .. " track")
			-- the Curve bends out of the straight pieces' strip, toward -Z
			local half = if kind == "Curve" then Vector3.new(10, 0, 8) else Vector3.new(ArtRail.TRACK_LENGTH / 2, 0, 4)
			inside(t, half, kind .. " track")
		end
		local x = Instance.new("Model")
		ArtRail.track("Crossing", x, CFrame.new())
		hinged(x, "Barrier")
		-- The Town Express track: the same pieces at EXPRESS_SCALE, so the giant train's wheels
		-- sit on its rails
		local scaled = Instance.new("Model")
		ArtRail.track("Straight", scaled, CFrame.new(), ArtRail.EXPRESS_SCALE)
		inside(scaled, Vector3.new(ArtRail.TRACK_LENGTH / 2, 0, 4) * ArtRail.EXPRESS_SCALE, "Express track")
		local railZ = 0
		Kit.eachPart(scaled, function(p)
			if p.Name == "Rail" then
				railZ = math.max(railZ, p.CFrame.Position.Z)
			end
		end)
		ok(
			math.abs(railZ - ArtRail.GAUGE / 2 * ArtRail.EXPRESS_SCALE) < 0.01,
			"Express track gauge scales with the train"
		)

		-- The Town Express: hub station with tier flags, and a giant train from the same builders
		local xs = Instance.new("Model")
		local express, expressBoard = ArtRail.expressStation(xs, CFrame.new())
		eq(expressBoard.Name, "ExpressBoard", "Express server board")
		within(xs, ArtRail.EXPRESS_PARTS_MAX, "Express station")
		paletteRules(xs, "Express station")
		inside(xs, ArtRail.EXPRESS_SIZE / 2, "Express station")
		hinged(express, "Bell")
		local function raised(): number
			local n = 0
			for _, d in express:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "TierFlag" and d.CFrame == d:GetAttribute("HighCFrame") then
					n += 1
				end
			end
			return n
		end
		eq(raised(), 0, "no tier flags up at the start")
		ArtRail.setExpressProgress(express, 0.6)
		eq(raised(), 2, "25% and 50% flags up at 60%")
		ArtRail.setExpressProgress(express, 1)
		eq(raised(), #ArtRail.EXPRESS_TIERS, "every flag up when the train is full")
		local small, big = Instance.new("Model"), Instance.new("Model")
		ArtRail.engine(small, CFrame.new())
		ArtRail.engine(big, CFrame.new(), ArtRail.EXPRESS_SCALE)
		eq(Kit.countParts(big), Kit.countParts(small), "the giant engine has the same parts")
		local function top(m: Instance): number
			local y = 0
			Kit.eachPart(m, function(p)
				y = math.max(y, p.CFrame.Position.Y + p.Size.Y / 2)
			end)
			return y
		end
		ok(math.abs(top(big) / top(small) - ArtRail.EXPRESS_SCALE) < 0.01, "and is EXPRESS_SCALE times as tall")
		local gc = Instance.new("Model")
		local giantCar = ArtRail.cargoCar(gc, CFrame.new(), ArtRail.EXPRESS_SCALE)
		ArtRail.setCarCrates(giantCar, 2)
		local crate = giantCar:FindFirstChild("Crate", true) :: BasePart
		ok(math.abs(crate.Size.Y - 2 * ArtRail.EXPRESS_SCALE) < 0.01, "giant cars carry giant crates")

		-- Event Tent: closed and open
		local et = Instance.new("Model")
		local tent, eventSign = ArtTown.eventTent(et, CFrame.new())
		eq(eventSign.Name, "EventSign", "event sign")
		within(et, ArtTown.TENT_PARTS_MAX, "Event Tent")
		paletteRules(et, "Event Tent")
		inside(et, ArtTown.TENT_SIZE / 2, "Event Tent")
		local function bunting(): number
			local n = 0
			for _, d in tent:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Bunting" and d.Transparency == 0 then
					n += 1
				end
			end
			return n
		end
		eq(bunting(), 0, "no bunting while closed")
		ArtTown.setEventTent(tent, true, Palette.plum)
		ok(bunting() > 0, "bunting while open")
		local flap = tent:FindFirstChild("Flap") :: BasePart
		eq(flap.CFrame, flap:GetAttribute("OpenCFrame"), "flaps tied back")
		ArtTown.setEventTent(tent, false)
		eq(bunting(), 0, "closed again")

		-- Factory queue crates
		local fm = Instance.new("Model")
		ArtFactories.build("Bakery", fm, CFrame.new())
		local plain = Kit.countParts(fm)
		ArtFactories.setQueue(fm, 2)
		eq(Kit.countParts(fm), plain + 2, "two jobs waiting, two crates")
		ArtFactories.setQueue(fm, 99)
		eq(Kit.countParts(fm), plain + ArtFactories.QUEUE_SHOWN, "never more than QUEUE_SHOWN")
		ArtFactories.setQueue(fm, 0)
		eq(Kit.countParts(fm), plain, "an empty queue shows none")

		local s = Instance.new("Model")
		local stall, price = ArtMarket.stall(s, CFrame.new(), "Teal")
		eq(price.Name, "PriceBoard", "stall price board")
		within(s, ArtMarket.STALL_PARTS_MAX, "Market stall")
		paletteRules(s, "Market stall")
		inside(s, ArtMarket.STALL_SIZE / 2, "Market stall")
		for i = 1, ArtMarket.SLOTS do
			ok(ArtMarket.slot(stall, i) ~= nil, "stall slot " .. i)
		end
		ok(ArtMarket.slot(stall, ArtMarket.SLOTS + 1) == nil, "no slot past the last")
		for name, color in ArtMarket.COLORS do
			ArtMarket.setStallColor(stall, name)
			local painted = 0
			for _, d in stall:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Awning" and d.Color == color then
					painted += 1
				end
			end
			eq(painted, 4, name .. " awning stripes")
		end
		local p = Instance.new("Model")
		ArtMarket.pennant(p, CFrame.new())
		within(p, ArtMarket.PENNANT_PARTS_MAX, "pennant")
		hinged(p, "Pennant")
	end)

	test("art: Blimp Mast, Cargo Blimp and its crates", function()
		local plot = Instance.new("Model")
		local origin = CFrame.new(40, 0, 10) * Kit.yaw(90)
		local parts = ArtBlimp.build(plot, origin)
		ok(parts.body.Name == "Body" and parts.body.CanCollide, "the office is the solid tap target")
		ok(parts.board.Name == "TimerBoard", "timer board")
		ok(parts.blimp.PrimaryPart ~= nil, "the blimp pivots on its root")
		local mastParts = Kit.countParts(plot) - Kit.countParts(parts.blimp)
		ok(mastParts <= ArtBlimp.MAST_PARTS_MAX, "mast has " .. mastParts .. " parts")
		within(parts.blimp, ArtBlimp.BLIMP_PARTS_MAX, "blimp")
		paletteRules(plot, "Blimp Mast")
		-- The mast and office stay on their 4 x 3 tile footprint
		Kit.eachPart(plot, function(p)
			if p:FindFirstAncestor("Blimp") == nil then
				local c = origin:PointToObjectSpace(p.CFrame.Position)
				ok(
					math.abs(c.X) <= ArtBlimp.WIDTH / 2 and math.abs(c.Z) <= ArtBlimp.DEPTH / 2,
					"mast: " .. p.Name .. " inside its footprint"
				)
			end
		end)
		-- A full hold: two filled crates and a flagged one per row
		local rows = {}
		for r = 1, ArtBlimp.ROWS do
			rows[r] = { { filled = true }, { filled = true }, { flagged = true } }
		end
		ArtBlimp.setCargo(plot, rows)
		local cargo = parts.blimp:FindFirstChild("Cargo") :: Model
		ok(cargo ~= nil, "cargo hangs under the blimp")
		within(cargo, ArtBlimp.CARGO_PARTS_MAX, "cargo")
		local crates = 0
		for _, d in cargo:GetChildren() do
			if d.Name == "Crate" then
				crates += 1
				ok(d:GetAttribute("Row") ~= nil and d:GetAttribute("Slot") ~= nil, "crate knows its row and slot")
			end
		end
		eq(crates, ArtBlimp.ROWS * ArtBlimp.PER_ROW, "nine crates")
		ArtBlimp.setCargo(plot, { { {} } })
		eq(Kit.countParts(parts.blimp:FindFirstChild("Cargo") :: Model), 1, "cargo rebuilt each call")
		-- States: broken hides the cup and shows the fallen sock; only Docked shows the blimp
		ArtBlimp.setState(plot, "Broken")
		eq((plot:FindFirstChild("Cup", true) :: BasePart).Transparency, 1, "broken mast has no cup")
		eq((plot:FindFirstChild("FallenSock", true) :: BasePart).Transparency, 0, "broken mast shows the fallen sock")
		eq((parts.blimp:FindFirstChild("Gondola", true) :: BasePart).Transparency, 1, "no blimp while broken")
		ArtBlimp.setState(plot, "Docked")
		eq((plot:FindFirstChild("Cup", true) :: BasePart).Transparency, 0, "repaired mast has its cup")
		eq((plot:FindFirstChild("FallenSock", true) :: BasePart).Transparency, 1, "and the sock is back up")
		eq((parts.blimp:FindFirstChild("Gondola", true) :: BasePart).Transparency, 0, "docked blimp shows")
		eq(parts.beacon.Material, Enum.Material.Neon, "beacon lit")
		local nose = parts.blimp:FindFirstChild("Nose", true) :: BasePart
		local cup = plot:FindFirstChild("Cup", true) :: BasePart
		ok((nose.CFrame.Position - cup.CFrame.Position).Magnitude < 3, "docked nose sits at the cup")
		ArtBlimp.setState(plot, "Away")
		eq((parts.blimp:FindFirstChild("Gondola", true) :: BasePart).Transparency, 1, "away: no blimp")
		ok(not (parts.blimp:FindFirstChild("Gondola", true) :: BasePart).CanQuery, "and nothing to tap")
	end)

	test("art: Town Hall, locked land, Puzzle Porch, townsfolk, pickups and the Quarry", function()
		for storeys = 1, 3 do
			local m = Instance.new("Model")
			local body, sign = ArtTown.townHall(m, CFrame.new(), storeys)
			eq(body.Name, "TownHall", "Town Hall body")
			eq(sign.Name, "PlotSign", "plot sign")
			within(m, ArtTown.TOWNHALL_PARTS_MAX, "Town Hall, " .. storeys .. " storeys")
			paletteRules(m, "Town Hall")
			local bell = m:FindFirstChild("Bell", true) :: BasePart
			ok(bell ~= nil and typeof(bell:GetAttribute("HingeCFrame")) == "CFrame", "bell can swing")
			eq(#m:GetDescendants() > 0 and Kit.countParts(m) > 0, true, "built")
		end
		local one, three = Instance.new("Model"), Instance.new("Model")
		ArtTown.townHall(one, CFrame.new(), 1)
		ArtTown.townHall(three, CFrame.new(), 3)
		local function height(m: Instance): number
			local top = 0
			Kit.eachPart(m, function(p)
				top = math.max(top, p.CFrame.Position.Y)
			end)
			return top
		end
		ok(height(three) > height(one) + 5, "storeys make it taller")

		local quarry = Instance.new("Model")
		local parts = ArtQuarry.build(quarry, CFrame.new())
		ok(parts.body:IsDescendantOf(quarry), "Quarry body")
		eq(#parts.boards:GetChildren(), 3, "Quarry boards")
		within(quarry, ArtQuarry.PARTS_MAX, "Quarry")
		paletteRules(quarry, "Quarry")
		ArtQuarry.setOpen(quarry, true)
		for _, board in parts.boards:GetChildren() do
			eq((board :: BasePart).Transparency, 1, "an open Quarry hides its boards")
		end
		ArtQuarry.setOpen(quarry, false)
		eq((parts.boards:GetChildren()[1] :: BasePart).Transparency, 0, "a closed Quarry shows its boards")

		local guild = Instance.new("Model")
		local guildBody = ArtGuild.build(guild, CFrame.new())
		ok(guildBody:IsDescendantOf(guild), "Guild body")
		within(guild, ArtGuild.PARTS_MAX, "Tinker's Guild")
		paletteRules(guild, "Tinker's Guild")

		local post = Instance.new("Model")
		eq(ArtTown.signpost(post, CFrame.new()).Name, "Board", "signpost board")
		within(post, ArtTown.SIGNPOST_PARTS_MAX, "signpost")
		paletteRules(post, "signpost")
		for _, id in ArtTown.OBSTACLE_TYPES do
			local m = Instance.new("Model")
			ArtTown.obstacle(id, m, CFrame.new())
			within(m, ArtTown.OBSTACLE_PARTS_MAX, id)
			paletteRules(m, id)
		end
		local min, max = Vector3.new(-48, 0, -96), Vector3.new(48, 0, -48)
		local road = { Vector3.new(8, 0, -77), Vector3.new(16, 0, -48) }
		local spots = ArtTown.scatter(min, max, 16, { road })
		local again = ArtTown.scatter(min, max, 16, { road })
		ok(#spots >= 8 and #spots <= 40, "a sensible scatter: " .. #spots)
		eq(#again, #spots, "same land, same scatter")
		for i, spot in spots do
			ok(spot.at:FuzzyEq(again[i].at, 1e-6), "scatter is stable")
			ok(spot.at.X >= min.X + 3 and spot.at.X <= max.X - 3, "inside the land")
			ok(not (spot.at.X > 5 and spot.at.X < 19 and spot.at.Z > -80), "kept off the road")
			ok(
				ArtTown.OBSTACLE_TYPES[1] ~= nil and table.find(ArtTown.OBSTACLE_TYPES, spot.id) ~= nil,
				"known obstacle"
			)
		end

		local porchRoot = Instance.new("Model")
		local porch = ArtTown.porch(porchRoot, CFrame.new())
		within(porch, ArtTown.PORCH_PARTS_MAX, "Puzzle Porch")
		paletteRules(porch, "Puzzle Porch")

		for _, role in ArtFolk.ROLES do
			local f = ArtFolk.build(role, CFrame.new(5, 0, 5))
			within(f, ArtFolk.PARTS_MAX, role)
			paletteRules(f, role)
			local rig = ArtMotion.bindFolk(f, 0) :: ArtMotion.FolkRig
			ok(rig ~= nil, role .. " has a rig")
			local head = f:FindFirstChild("Head") :: BasePart
			local rest = head.CFrame.Position
			for _, t in { 0.2, 0.9, 1.7 } do
				ArtMotion.poseFolk(rig, t)
				ok((head.CFrame.Position - rest).Magnitude < 0.6, role .. " stays in place")
			end
			if role == "Builder" then
				ok(rig.arm ~= nil, "the Builder has a hammer arm")
			end
		end
		eq(ArtMotion.bellAngle(0), 0, "bell at rest before")
		eq(ArtMotion.bellAngle(ArtMotion.BELL_SECONDS), 0, "bell at rest after")
		ok(math.abs(ArtMotion.bellAngle(0.15)) > 5, "bell swings")

		for _, kind in ArtPickups.KINDS do
			local m = ArtPickups.build(kind)
			within(m, ArtPickups.PARTS_MAX, kind .. " pickup")
			paletteRules(m, kind)
		end
		local from, dir = Vector3.new(0, 1, 0), Vector3.new(1, 0, 0)
		local p0, _, s0 = ArtMotion.pickupPath(from, dir, 0)
		local p1, _, s1 = ArtMotion.pickupPath(from, dir, 1)
		ok(p0:FuzzyEq(from, 1e-4), "pickup starts at the avatar")
		ok(p1.Y > from.Y + 6, "pickup floats away")
		ok(s0 < 1 and s1 < 0.5, "pickup grows in and shrinks out")
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
		for id, def in Town.community do
			if def.townHallStorey then
				continue -- builds onto the Town Hall
			end
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
		ok(square.porch.Parent == square.porchModel, "the cabinet is part of the Puzzle Porch")
		for _, part in square.porchModel:GetDescendants() do
			-- the whole porch takes taps, not just the cabinet's body (the screen covers its front)
			ok(not part:IsA("BasePart") or (part :: BasePart).CanQuery, part.Name .. " on the porch is a tap target")
		end
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

	test("art: a fully built plot (every level with content) stays inside the plot part budget", function()
		local total = 0
		local function add(root: Instance, copies: number)
			total += Kit.countParts(root) * copies
		end
		-- 22 fields with ready Corn (the tallest MVP stage) on dressed beds
		local b = bed()
		ArtCrops.dressBed(b)
		add(b, 22)
		add(ArtCrops.build("Corn", 4, CFrame.new(), nil), 22)
		-- Every pen up to the highest built level, copies (Cow Barns 2 and 3) looking like their
		-- original
		local pensMerged, pensBuilt = 0, 0
		for id, def in Animals.pens do
			if def.unlockLevel > Levels.built then
				continue
			end
			local kind = def.copyOf or id
			local pen = Instance.new("Model")
			ArtAnimals.pen(kind, CFrame.new(), pen)
			ArtAnimals.setPenLevel(pen, kind, ArtAnimals.PEN_LEVEL_MAX)
			-- A working pen's fences and shelter are merged on the server (Art/Merge mergeShell)
			local shell = ArtMerge.countShell(pen, ArtAnimals.SHELL_SKIP)
			total += shell
			pensMerged += shell
			pensBuilt += Kit.countParts(pen)
			add(ArtAnimals.animal(kind, CFrame.new()), 6)
			add(ArtAnimals.product(kind, CFrame.new()), 6)
		end
		-- Every factory with a full output tray (its trayCapacity of goods) of the biggest
		-- prop it makes
		for _, id in FACTORIES do
			local m = Instance.new("Model")
			local parts = ArtFactories.build(id, m, CFrame.new())
			-- A working factory is merged around its body on the server (Art/Merge)
			total += ArtMerge.count(m, parts.body, ArtFactories.MERGE_SKIP)
			total += ArtFactories.QUEUE_SHOWN
			local makes = Factories[id].makes or id
			local biggestProp = 0
			for recipeId, recipe in Recipes do
				if recipe.factory == makes then
					biggestProp = math.max(biggestProp, Kit.countParts(ArtItemProps.build(recipeId)))
				end
			end
			ok(biggestProp > 0, id .. " makes something with a prop")
			total += biggestProp * Factories[id].trayCapacity
		end
		-- Barn, board, dock, truck, gate: use their budgets
		total += ArtBuildings.BARN_PARTS_MAX + ArtBuildings.BOARD_PARTS_MAX + 4 + ArtBuildings.TRUCK_PARTS_MAX + 25
		total += ArtBuildings.TOOLSHED_PARTS_MAX
		total += ArtQuarry.PARTS_MAX
		-- The Blimp Mast with the Cargo Blimp docked and a full load of crates
		total += ArtBlimp.PARTS_MAX
		-- The Tinker's Guild, merged like a town building once it's built
		local guild = Instance.new("Model")
		total += ArtMerge.count(guild, ArtGuild.build(guild, CFrame.new()))
		-- Town Hall at full height, the Puzzle Porch and the four guides
		total += ArtTown.TOWNHALL_PARTS_MAX + ArtTown.PORCH_PARTS_MAX + 4 * ArtFolk.PARTS_MAX
		-- Decorations: the server merges each one's look (Art/Merge), so a full set of placed
		-- decorations costs the costliest merged big and small ones, times their caps
		local big, small = 0, 0
		for id, def in Decor.items do
			local root = Instance.new("Part")
			ArtDecor.build(id, root, CFrame.new())
			local n = 0
			local any = false
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") then
					if ArtMerge.keepsSeparate(d) then
						n += 1
					else
						any = true
					end
				end
			end
			n += if any then 1 else 0
			if def.size[1] * def.size[2] >= Decor.bigTiles then
				big = math.max(big, n)
			else
				small = math.max(small, n)
			end
		end
		local decor = big * Decor.maxBig + small * (Decor.maxPlaced - Decor.maxBig)
		total += decor
		-- Every House copy a player at the highest built level can own, and every Community
		-- Building, so the budget stays honest as the content bank grows. Finished ones are
		-- merged on the server (Art/Merge): one union plus the parts that stay separate.
		local unmerged, merged = 0, 0
		for id, def in Town.houses do
			local copies = 0
			for _, level in def.copyLevels do
				if level <= Levels.built then
					copies += 1
				end
			end
			local m = Instance.new("Model")
			local body = ArtHouses.build(id, m, CFrame.new(), { size = 8 })
			merged += ArtMerge.count(m, body) * copies
			unmerged += Kit.countParts(m) * copies
		end
		for id, def in Town.community do
			if def.townHallStorey then
				continue -- the Town Hall above is counted at full height
			end
			local m = Instance.new("Model")
			local body = ArtCommunity.build(id, m, CFrame.new(), 12)
			merged += ArtMerge.count(m, body)
			unmerged += Kit.countParts(m)
		end
		total += merged
		-- The outer ring (expansions 5+) still wild: a level-cap farm may not have cleared it,
		-- so count its sparse obstacles and signposts too
		local wild = 0
		for _, rect in Land.rects do
			if rect.stage >= Land.outerRingStage then
				local spots = ArtTown.scatter(
					Vector3.new(rect.minX, 0, rect.minZ),
					Vector3.new(rect.maxX, 0, rect.maxZ),
					Land.outerRingSpacing
				)
				wild += #spots * ArtTown.OBSTACLE_PARTS_MAX + ArtTown.SIGNPOST_PARTS_MAX + 1
			end
		end
		total += wild
		print(string.format("      outer ring still wild: %d parts", wild))
		print(
			string.format(
				"      town buildings: %d parts once merged (%d as built); decorations: %d",
				merged,
				unmerged,
				decor
			)
		)
		print(string.format("      pen shells: %d parts once merged (%d as built)", pensMerged, pensBuilt))
		print(string.format("      full level-%d plot estimate: %d parts", Levels.built, total))
		ok(total <= PLOT_PARTS_MAX, string.format("full plot estimate %d parts, budget %d", total, PLOT_PARTS_MAX))
	end)
end

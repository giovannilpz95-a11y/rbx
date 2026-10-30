--!strict
-- Field beds and crops at each growth stage. Design/16 Model Catalog §2.1, Design/12 (4
-- stages: seeded, sprout, growing, ready).
--
-- Each stage is one small Model of Parts laid out on the bed's three planting rows, so a
-- field changes look by swapping one Model. Parts-only budget (no uploaded meshes yet):
-- bed ≤ 4 parts, any crop stage ≤ 12 parts.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtCrops = {}

ArtCrops.ROWS = { -2.5, 0, 2.5 } -- planting rows along local X, at these Z offsets
ArtCrops.STAGE_PARTS_MAX = 12
ArtCrops.BED_PARTS_MAX = 4

-- Which stage a growing field shows: 1 seeded, 2 sprout, 3 growing, 4 ready.
function ArtCrops.stageFor(progress: number, ready: boolean): number
	if ready then
		return 4
	elseif progress < 0.25 then
		return 1
	elseif progress < 0.6 then
		return 2
	end
	return 3
end

-- Dress a field bed part (8 x 1 x 8 soil block): three raised planting ridges. The ridges are
-- children of the bed, so taps on them still reach the bed. 3 parts (4 with the bed).
function ArtCrops.dressBed(bed: BasePart)
	local top = bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)
	local b = Kit.builder(bed, top, true)
	for _, z in ArtCrops.ROWS do
		b.block("Ridge", Vector3.new(7, 0.3, 1.7), Vector3.new(0, 0.15, z), Palette.soilLight, { shadow = false })
	end
end

type Build = (b: Kit.Builder, color: Color3) -> ()

local GRASSY = { Wheat = true, Corn = true, Sugarcane = true }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- S1 Seeded (shared by every crop): seed lines on the ridges and a seed-packet stake at the
-- front corner in the crop's color. 5 parts.
local function seeded(b: Kit.Builder, color: Color3)
	for _, z in ArtCrops.ROWS do
		b.block("Seeds", Vector3.new(6.2, 0.15, 0.5), Vector3.new(0, 0.37, z), Palette.seed, { shadow = false })
	end
	b.block("Stake", Vector3.new(0.25, 1.6, 0.25), Vector3.new(-3.4, 0.8, -3.6), Palette.wood)
	b.block("Packet", Vector3.new(1, 1.1, 0.2), Vector3.new(-3.4, 1.5, -3.75), color)
end

-- S2 Sprout (shared, two leaf shapes): three little sprouts per row. 9 parts.
local function sprout(grassy: boolean): Build
	return function(b, _color)
		for _, z in ArtCrops.ROWS do
			for _, x in { -2.3, 0, 2.3 } do
				if grassy then
					b.block(
						"Sprout",
						Vector3.new(0.35, 1.1, 0.35),
						CFrame.new(x, 0.85, z) * CFrame.Angles(0, 0, math.rad(12)),
						Palette.sprout,
						{ shadow = false }
					)
				else
					b.block(
						"Sprout",
						Vector3.new(0.9, 0.35, 0.9),
						CFrame.new(x, 0.6, z) * CFrame.Angles(0, math.rad(45), 0),
						Palette.sprout,
						{ shadow = false }
					)
				end
			end
		end
	end
end

local GROWING: { [string]: Build } = {}
local READY: { [string]: Build } = {}

-- Wheat: green tufts, then chunky golden bundles with fat grain heads (16 §2.1).
GROWING.Wheat = function(b)
	for i, z in ArtCrops.ROWS do
		b.block("Stalks", Vector3.new(6.6, 1.2, 1.1), Vector3.new(0, 0.9, z), Palette.wheatGreen)
		b.block(
			"Tips",
			Vector3.new(6.2, 0.4, 0.8),
			Vector3.new((i - 2) * 0.2, 1.65, z),
			Palette.leafLight,
			{ shadow = false }
		)
	end
end
READY.Wheat = function(b)
	for i, z in ArtCrops.ROWS do
		b.block("Stalks", Vector3.new(6.8, 1.5, 1.1), Vector3.new(0, 1.05, z), Palette.wheat)
		for j, x in { -2.3, 0, 2.3 } do
			local lean = if (i + j) % 2 == 0 then 8 else -8
			b.block(
				"Ears",
				Vector3.new(1.5, 1.5, 1.5),
				CFrame.new(x, 2.3, z) * CFrame.Angles(0, math.rad(45), math.rad(lean)),
				Palette.wheatHead
			)
		end
	end
end

-- Corn: young stalks, then four tall clumps with crossed leaves and a big yellow cob.
GROWING.Corn = function(b)
	for _, x in { -2, 2 } do
		for _, z in { -2, 2 } do
			b.block("Stalk", Vector3.new(0.8, 2.4, 0.8), Vector3.new(x, 1.5, z), Palette.cornLeaf)
			b.block(
				"Leaves",
				Vector3.new(2.2, 0.35, 0.7),
				CFrame.new(x, 2.2, z) * CFrame.Angles(0, math.rad(if x * z > 0 then 40 else -40), 0),
				Palette.leafLight,
				{ shadow = false }
			)
		end
	end
end
READY.Corn = function(b)
	for _, x in { -2, 2 } do
		for _, z in { -2, 2 } do
			b.block("Stalk", Vector3.new(1, 4.6, 1), Vector3.new(x, 2.6, z), Palette.cornLeaf)
			b.block(
				"Leaves",
				Vector3.new(3.4, 0.35, 1),
				CFrame.new(x, 4.2, z) * CFrame.Angles(0, math.rad(if x * z > 0 then 35 else -35), math.rad(12)),
				Palette.leafLight,
				{ shadow = false }
			)
			b.block(
				"Cob",
				Vector3.new(1.2, 2, 1.2),
				CFrame.new(x + 0.15, 2.7, z - 0.9) * CFrame.Angles(math.rad(-18), 0, 0),
				Palette.corn
			)
		end
	end
end

-- Carrots: small frilly fans, then leafy fans over bright orange shoulders.
GROWING.Carrots = function(b)
	for _, z in ArtCrops.ROWS do
		for _, x in { -2.3, 0, 2.3 } do
			b.block(
				"Top",
				Vector3.new(1, 0.8, 1),
				CFrame.new(x, 0.75, z) * CFrame.Angles(0, math.rad(45), 0),
				Palette.carrotTop,
				{ shadow = false }
			)
		end
	end
end
READY.Carrots = function(b)
	for _, z in ArtCrops.ROWS do
		b.block("Shoulders", Vector3.new(6.6, 0.8, 1.5), Vector3.new(0, 0.6, z), Palette.carrot)
		for j, x in { -2.2, 0, 2.2 } do
			b.block(
				"Top",
				Vector3.new(1.1, 1.5, 1.1),
				CFrame.new(x, 1.6, z + 0.15) * CFrame.Angles(0, math.rad(45), math.rad((j - 2) * 14)),
				Palette.leafLight
			)
		end
	end
end

-- Sugarcane: short canes, then tall green and plum canes, each with a leafy tuft.
GROWING.Sugarcane = function(b)
	for _, z in ArtCrops.ROWS do
		for _, x in { -1.8, 1.8 } do
			b.post("Cane", 2.6, 0.6, Vector3.new(x, 1.6, z), Palette.cane)
		end
	end
end
READY.Sugarcane = function(b)
	for i, z in ArtCrops.ROWS do
		for j, x in { -1.7, 1.7 } do
			local tilt = if (i + j) % 2 == 0 then 6 else -6
			local color = if (i + j) % 2 == 0 then Palette.cane else Palette.canePlum
			local at = CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.rad(tilt))
			b.post("Cane", 4.6, 0.75, at * CFrame.new(0, 2.3, 0), color)
			b.block(
				"Tuft",
				Vector3.new(1.9, 1, 1.9),
				at * CFrame.new(0, 4.8, 0) * CFrame.Angles(0, math.rad(45), 0),
				Palette.leafLight
			)
		end
	end
end

-- Cotton: low woody shrubs, then shrubs topped with fluffy cream bolls.
GROWING.Cotton = function(b)
	for _, z in ArtCrops.ROWS do
		b.block("Shrub", Vector3.new(6.2, 1.1, 1.2), Vector3.new(0, 0.85, z), Palette.cottonShrub)
	end
end
READY.Cotton = function(b)
	for _, z in ArtCrops.ROWS do
		b.block("Shrub", Vector3.new(6.4, 1.4, 1.3), Vector3.new(0, 1, z), Palette.cottonShrub)
		for _, x in { -2.2, 0, 2.2 } do
			b.ball("Boll", 1.5, Vector3.new(x, 2.05, z), Palette.cotton)
		end
	end
end

-- Strawberries (level 13): low leafy mounds with white flowers, then the same mounds hung
-- with fat red berries.
GROWING.Strawberries = function(b)
	for _, z in ArtCrops.ROWS do
		b.block("Mound", Vector3.new(6.2, 0.9, 1.3), Vector3.new(0, 0.75, z), Palette.leaf)
		for _, x in { -2, 0.2, 2.2 } do
			b.ball("Flower", 0.6, Vector3.new(x, 1.3, z - 0.3), Palette.cream, { shadow = false })
		end
	end
end
READY.Strawberries = function(b, color)
	for i, z in ArtCrops.ROWS do
		b.block("Mound", Vector3.new(6.4, 1, 1.4), Vector3.new(0, 0.8, z), Palette.leaf)
		for j, x in { -2.2, 0, 2.2 } do
			b.ball("Berry", 1.1, Vector3.new(x, 1.2, z - 0.7 + ((i + j) % 2) * 0.2), color)
		end
	end
end

-- Tomatoes (level 15): staked vines, then a tall hedge of vine heavy with round tomatoes.
GROWING.Tomatoes = function(b)
	for _, z in ArtCrops.ROWS do
		b.block("Vine", Vector3.new(6.2, 1.6, 0.9), Vector3.new(0, 1.2, z), Palette.leafLight)
		for _, x in { -2.6, 2.6 } do
			b.block("Stake", Vector3.new(0.25, 2.6, 0.25), Vector3.new(x, 1.6, z + 0.5), Palette.wood)
		end
	end
end
READY.Tomatoes = function(b, color)
	for i, z in ArtCrops.ROWS do
		b.block("Vine", Vector3.new(6.4, 2.6, 1), Vector3.new(0, 1.7, z), Palette.leaf)
		for j, x in { -2.2, 0, 2.2 } do
			b.ball("Tomato", 1.05, Vector3.new(x, if (i + j) % 2 == 0 then 2.3 else 1.5, z - 0.6), color)
		end
	end
end

-- Pine Trees (level 18): rows of little saplings, then four tall pines in the outer rows, each
-- three tapering tiers of needles like the RoundPine decoration.
GROWING.PineTrees = function(b)
	for _, z in ArtCrops.ROWS do
		for _, x in { -2, 2 } do
			b.ball("Sapling", 1.3, Vector3.new(x, 0.95, z), Palette.treeTopDark)
		end
	end
end
READY.PineTrees = function(b)
	local rows = ArtCrops.ROWS
	for i, z in { rows[1], rows[3] } do
		for j, x in { -1.8, 1.8 } do
			local lift = if (i + j) % 2 == 0 then 0.6 else 0
			for k, d in { 2.6, 1.9, 1.1 } do
				local color = if k == 2 then Palette.leaf else Palette.treeTopDark
				b.ball("Pine", d, Vector3.new(x, 0.3 + k * 1.25 + lift, z), color)
			end
		end
	end
end

-- Potatoes (level 22): bushy green rows with pale flowers, then the rows dug up with
-- potatoes on the soil.
GROWING.Potatoes = function(b)
	for _, z in ArtCrops.ROWS do
		b.block("Leaves", Vector3.new(6.2, 1.2, 1.4), Vector3.new(0, 0.9, z), Palette.leaf)
		b.ball("Flower", 0.6, Vector3.new(-1, 1.6, z), Palette.flowerWhite, { shadow = false })
	end
end
READY.Potatoes = function(b, color)
	for i, z in ArtCrops.ROWS do
		b.block("Leaves", Vector3.new(6.2, 0.9, 1.2), Vector3.new(0, 0.75, z + 0.3), Palette.leafLight)
		for j, x in { -1.6, 1.6 } do
			b.ball("Potato", if (i + j) % 2 == 0 then 1.2 else 1, Vector3.new(x, 0.6, z - 0.55), color)
		end
	end
end

-- Cocoa (level 25): little cocoa saplings, then four small cocoa trees, each with a fat golden pod
-- hanging from its trunk.
GROWING.Cocoa = function(b)
	for _, x in { -2, 2 } do
		for _, z in { -2, 2 } do
			b.post("Trunk", 1.2, 0.35, Vector3.new(x, 1, z), Palette.trunk)
			b.ball("Leaves", 1.5, Vector3.new(x, 1.9, z), Palette.leaf)
		end
	end
end
READY.Cocoa = function(b, color)
	for _, x in { -2, 2 } do
		for _, z in { -2, 2 } do
			b.post("Trunk", 2.6, 0.5, Vector3.new(x, 1.7, z), Palette.trunk)
			b.ball("Canopy", 2.6, Vector3.new(x, 3.5, z), Palette.leaf)
			b.ball("Pod", 0.9, Vector3.new(x - 0.35, 1.8, z - 0.35), Palette.bread:Lerp(color, 0.3), { shadow = false })
		end
	end
end

-- Crops past the content bank: green rows, then rows of fruit in the crop's own color.
local function genericGrowing(b: Kit.Builder, _color: Color3)
	for _, z in ArtCrops.ROWS do
		b.block("Leaves", Vector3.new(6.2, 1, 1.3), Vector3.new(0, 0.8, z), Palette.leafLight)
	end
end
local function genericReady(b: Kit.Builder, color: Color3)
	for _, z in ArtCrops.ROWS do
		b.block("Leaves", Vector3.new(6.4, 1, 1.4), Vector3.new(0, 0.8, z), Palette.leaf)
		for _, x in { -2.2, 0, 2.2 } do
			b.ball("Fruit", 1.2, Vector3.new(x, 1.5, z - 0.3), color)
		end
	end
end

-- An empty field, freshly dug: dark turned soil in the furrows and a couple of clods, so a
-- free field stands out from a planted one at a distance. A Model named "Crop" like build's. 5 parts.
function ArtCrops.tilled(top: CFrame): Model
	local model = Kit.model("Crop")
	local b = Kit.builder(model, top, false)
	local quiet = { shadow = false }
	for _, z in ArtCrops.ROWS do
		b.block("Turned", Vector3.new(6.6, 0.08, 1.4), Vector3.new(0, 0.33, z), Palette.soilDark, quiet)
	end
	b.ball("Clod", 0.5, Vector3.new(-2.4, 0.4, 1.25), Palette.soilDark, quiet)
	b.ball("Clod", 0.4, Vector3.new(2.1, 0.38, -1.25), Palette.soil, quiet)
	return model
end

-- Build one crop stage as a Model named "Crop". `top` is the CFrame of the bed's top centre.
-- `color` is the crop's config color (used for seed packets and generic crops).
function ArtCrops.build(cropId: string, stage: number, top: CFrame, color: { number }?): Model
	local model = Kit.model("Crop")
	model:SetAttribute("CropId", cropId)
	model:SetAttribute("Stage", stage)
	local b = Kit.builder(model, top, true)
	local tint = if color then rgb(color) else Palette.lime
	if stage <= 1 then
		seeded(b, tint)
	elseif stage == 2 then
		sprout(GRASSY[cropId] == true)(b, tint)
	elseif stage == 3 then
		(GROWING[cropId] or genericGrowing)(b, tint)
	else
		(READY[cropId] or genericReady)(b, tint)
	end
	return model
end

-- Crops that have their own growing and ready looks (the rest use the generic rows).
function ArtCrops.hasCustomLook(cropId: string): boolean
	return READY[cropId] ~= nil
end

-- The shimmer over a ready Prize Crop (Design/02 Farming, Prize Crops lite): a soft glowing
-- ring around the bed and a slow drift of sparkles, gold for Sunkissed, gem-teal for
-- Heirloom. 1 part plus a ParticleEmitter, added to the crop model so it goes when the crop
-- does. `top` is the bed's top centre; `size` the bed's width.
ArtCrops.PRIZE_COLORS = {
	Sunkissed = Palette.coins,
	Heirloom = Palette.gems,
}

function ArtCrops.prizeShimmer(crop: Model, tier: string, top: CFrame, size: number): BasePart?
	local color = ArtCrops.PRIZE_COLORS[tier]
	if color == nil then
		return nil
	end
	local b = Kit.builder(crop, top, false)
	local ring = b.post(
		"PrizeGlow",
		0.12,
		size + 0.4,
		Vector3.new(0, 0.08, 0),
		color,
		{ material = Enum.Material.Neon, transparency = 0.55, shadow = false }
	)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "PrizeSparkles"
	sparkles.Color = ColorSequence.new(color, Palette.cream)
	sparkles.LightEmission = 0.8
	sparkles.Size = NumberSequence.new(0.35, 0)
	sparkles.Transparency = NumberSequence.new(0.1, 1)
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Rate = if tier == "Heirloom" then 8 else 4
	sparkles.Speed = NumberRange.new(1.5, 2.5)
	sparkles.SpreadAngle = Vector2.new(15, 15)
	sparkles.EmissionDirection = Enum.NormalId.Right -- the post's local X points up
	sparkles.Parent = ring
	return ring
end

-- A ready crop's sparkle (Model List: Ready sparkle): a few soft lime-and-cream glints
-- drifting up off the crop, never more than about 6 at once. Prize Crops have their own
-- shimmer instead. The client's CropMotion adds the gentle sway.
function ArtCrops.readySparkle(crop: Model): ParticleEmitter?
	local host = crop:FindFirstChildWhichIsA("BasePart")
	if host == nil then
		return nil
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "ReadySparkles"
	sparkles.Color = ColorSequence.new(Palette.lime, Palette.cream)
	sparkles.LightEmission = 0.6
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Transparency = NumberSequence.new(0.15, 1)
	sparkles.Lifetime = NumberRange.new(1.2, 1.8)
	sparkles.Rate = 3
	sparkles.Speed = NumberRange.new(0.3, 0.6)
	sparkles.Acceleration = Vector3.new(0, 1.2, 0)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = host
	return sparkles
end

return ArtCrops

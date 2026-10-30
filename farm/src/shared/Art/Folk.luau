--!strict
-- Peg-folk (16 Model Catalog §2.15, Model List - Town & Factories §9): the townsfolk, built on
-- one shared rig like a painted wooden peg doll, about 4 studs tall: a round body, a big head
-- with dot eyes, two stubby arms, hair or a hat, and one prop that says what they do. ≤ 8 parts.
-- The four guides from the tutorial and the Builder who works at scaffolds. All original.
-- Each figure is a Model whose bottom centre stands at `cf`, facing local -Z; the client's
-- FolkMotion gives them an idle bob (and the Builder a hammer swing) from the Role attribute.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtFolk = {}

ArtFolk.PARTS_MAX = 8

local QUIET = { shadow = false }

type Look = {
	skin: Color3,
	outfit: Color3,
	top: (b: Kit.Builder) -> (), -- hair or hat
	prop: (b: Kit.Builder) -> (), -- held in the right hand (local +X)
}

local HEAD_Y = 3.3

-- The shared rig: a round body standing on the ground, a big head with two dot eyes, and two
-- stubby arms. 6 parts.
local function rig(b: Kit.Builder, look: Look)
	b.post("Body", 2.6, 1.7, Vector3.new(0, 1.3, 0), look.outfit)
	b.ball("Head", 1.6, Vector3.new(0, HEAD_Y, 0), look.skin)
	for _, x in { -0.3, 0.3 } do
		b.ball("Eye", 0.26, Vector3.new(x, HEAD_Y + 0.1, -0.72), Palette.eye, QUIET)
	end
	for _, x in { -1, 1 } do
		local arm = b.block(
			"Arm",
			Vector3.new(0.45, 1.3, 0.45),
			CFrame.new(x * 1, 1.9, 0) * CFrame.Angles(0, 0, math.rad(x * 12)),
			look.outfit:Lerp(Palette.cocoa, 0.1),
			QUIET
		)
		arm.Name = if x < 0 then "LeftArm" else "RightArm"
	end
end

local LOOKS: { [string]: Look } = {
	-- Hattie Furrow, the farm guide: a wide straw sun hat with a lime band, sage overalls and
	-- a trowel
	Hattie = {
		skin = Palette.skinTan,
		outfit = Palette.leaf:Lerp(Palette.cream, 0.35),
		top = function(b)
			b.post("Hat", 0.2, 2.6, Vector3.new(0, HEAD_Y + 0.55, 0), Palette.straw, QUIET)
		end,
		prop = function(b)
			b.block("Trowel", Vector3.new(0.3, 1, 0.15), CFrame.new(1.05, 1.1, -0.35), Palette.metal, QUIET)
		end,
	},
	-- Pip Tally, the orders guide: a teal courier cap, a mustard jacket and a clipboard
	Pip = {
		skin = Palette.skinDeep,
		outfit = Palette.roofMustard,
		top = function(b)
			b.block("Cap", Vector3.new(1.5, 0.45, 1.8), Vector3.new(0, HEAD_Y + 0.65, -0.15), Palette.roofTeal, QUIET)
		end,
		prop = function(b)
			b.block("Clipboard", Vector3.new(0.9, 1.1, 0.12), CFrame.new(1.05, 1.5, -0.45), Palette.cream, QUIET)
		end,
	},
	-- Auntie Crumb, the factories guide: a plum headscarf, a cream apron dress and a big
	-- wooden spoon
	Crumb = {
		skin = Palette.skinLight,
		outfit = Palette.cream:Lerp(Palette.flowerPink, 0.25),
		top = function(b)
			b.ball("Scarf", 1.75, Vector3.new(0, HEAD_Y + 0.25, 0.12), Palette.plum, QUIET)
		end,
		prop = function(b)
			b.block("Spoon", Vector3.new(0.25, 1.8, 0.25), CFrame.new(1.05, 1.9, -0.35), Palette.woodLight, QUIET)
		end,
	},
	-- Mort Mallet, the builder guide: a mustard hard hat, denim overalls and a wooden mallet
	Mort = {
		skin = Palette.skinUmber,
		outfit = Palette.glassDeep:Lerp(Palette.sheepFace, 0.4),
		top = function(b)
			b.ball("HardHat", 1.7, Vector3.new(0, HEAD_Y + 0.35, 0), Palette.roofMustard, QUIET)
		end,
		prop = function(b)
			b.block("Mallet", Vector3.new(0.9, 0.6, 0.6), CFrame.new(1.05, 0.9, -0.35), Palette.woodDark, QUIET)
		end,
	},
	-- The Builder (one per active build): a mustard hard hat, an orange work vest and a hammer
	Builder = {
		skin = Palette.skinTan,
		outfit = Palette.carrot,
		top = function(b)
			b.ball("HardHat", 1.7, Vector3.new(0, HEAD_Y + 0.35, 0), Palette.roofMustard, QUIET)
		end,
		prop = function(b)
			b.block("Hammer", Vector3.new(0.6, 0.35, 0.35), CFrame.new(1.05, 1.15, -0.45), Palette.stoneDark, QUIET)
		end,
	},
}

ArtFolk.ROLES = { "Hattie", "Pip", "Crumb", "Mort", "Builder" }

function ArtFolk.has(role: string): boolean
	return LOOKS[role] ~= nil
end

-- One figure of `role`, its bottom centre at `cf` facing local -Z. Parts don't take taps or
-- collide, so they never get in the way of building or walking.
function ArtFolk.build(role: string, cf: CFrame, name: string?): Model
	local model = Kit.model(name or ("Folk_" .. role))
	local look = LOOKS[role] or LOOKS.Builder
	local b = Kit.builder(model, cf, false)
	rig(b, look)
	look.top(b)
	look.prop(b)
	model:SetAttribute("Role", role)
	model:SetAttribute("BaseCFrame", cf)
	return model
end

return ArtFolk

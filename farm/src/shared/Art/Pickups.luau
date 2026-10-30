--!strict
-- Reward pickups (Model List - Town & Factories §11, Coin / Gem / XP pop props): small
-- spinning tokens that pop out in the world when you earn something, then float off toward
-- the HUD (the client's RewardPops). About 1.2 studs across, centred on `cf`. 2 parts each.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtPickups = {}

ArtPickups.PARTS_MAX = 2
ArtPickups.KINDS = { "Coins", "Gems", "XP" }

local GLOW = { shadow = false }

local BUILDERS: { [string]: (Kit.Builder) -> () } = {
	-- A gold coin standing on its edge, facing local -Z, with a lighter raised rim
	Coins = function(b)
		local face = CFrame.Angles(0, math.rad(90), 0)
		b.cyl("Coin", 0.22, 1.2, face, Palette.coins, GLOW)
		b.cyl("Rim", 0.26, 0.75, face, Palette.coins:Lerp(Palette.cream, 0.35), GLOW)
	end,
	-- A teal gem: a cube turned on its point, with a pale facet on top
	Gems = function(b)
		local point = CFrame.Angles(math.rad(45), 0, math.rad(45))
		b.block("Gem", Vector3.new(0.85, 0.85, 0.85), point, Palette.gems, GLOW)
		b.block(
			"Facet",
			Vector3.new(0.4, 0.4, 0.4),
			CFrame.new(0, 0.3, -0.2) * point,
			Palette.gems:Lerp(Palette.cream, 0.5),
			GLOW
		)
	end,
	-- A lime XP star: two crossed blocks, like a plus turned into a sparkle
	XP = function(b)
		b.block("Star", Vector3.new(1.3, 0.4, 0.25), CFrame.Angles(0, 0, math.rad(45)), Palette.xp, GLOW)
		b.block("Star", Vector3.new(1.3, 0.4, 0.25), CFrame.Angles(0, 0, math.rad(-45)), Palette.xp, GLOW)
	end,
}

function ArtPickups.has(kind: string): boolean
	return BUILDERS[kind] ~= nil
end

function ArtPickups.build(kind: string, cf: CFrame?): Model
	local model = Kit.model("Pickup_" .. kind)
	local builder = BUILDERS[kind] or BUILDERS.Coins
	builder(Kit.builder(model, cf or CFrame.new(), false))
	return model
end

return ArtPickups

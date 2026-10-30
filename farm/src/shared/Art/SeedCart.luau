--!strict
-- The Seed Cart (Design/13 Roblox Success Mechanics §3.7): a wooden market cart with two big
-- wheels, a striped awning, seed sacks and crates in the bed and a sign board on the front
-- for the restock countdown. Front at local -Z. Budget ≤ 30 parts. Pure, for the Lune tests.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtSeedCart = {}

ArtSeedCart.PARTS_MAX = 30

export type Cart = {
	model: Model,
	body: Part, -- the cart bed (tap target)
	sign: Part, -- the sign board: a SurfaceGui on its Front shows the countdown
}

function ArtSeedCart.build(parent: Instance, cf: CFrame): Cart
	local model = Kit.model("SeedCart", parent)
	local b = Kit.builder(model, cf, true)
	local turn = CFrame.Angles(0, math.rad(90), 0)
	local body = b.block("Body", Vector3.new(7, 1.6, 4), Vector3.new(0, 2.4, 0), Palette.wood, { collide = true })
	b.block("Trim", Vector3.new(7.3, 0.3, 4.3), Vector3.new(0, 3.25, 0), Palette.woodDark)
	for _, x in { -2.6, 2.6 } do
		b.cyl("Wheel", 0.5, 3.2, CFrame.new(x, 1.6, 0) * turn * CFrame.Angles(0, 0, math.rad(90)), Palette.woodDark)
		b.cyl("Hub", 0.6, 0.8, CFrame.new(x, 1.6, 0) * turn * CFrame.Angles(0, 0, math.rad(90)), Palette.metal)
	end
	b.block("Handle", Vector3.new(0.3, 0.3, 3), Vector3.new(-1.2, 2.2, -3.4), Palette.woodDark)
	b.block("Handle", Vector3.new(0.3, 0.3, 3), Vector3.new(1.2, 2.2, -3.4), Palette.woodDark)
	-- Awning on four poles, striped red and cream
	for _, x in { -3.2, 3.2 } do
		for _, z in { -1.7, 1.7 } do
			b.block("Pole", Vector3.new(0.3, 4.4, 0.3), Vector3.new(x, 5.3, z), Palette.cream)
		end
	end
	for i = 0, 3 do
		b.block(
			"Awning",
			Vector3.new(1.9, 0.3, 4.8),
			CFrame.new(-2.85 + i * 1.9, 7.7, 0) * CFrame.Angles(math.rad(8), 0, 0),
			if i % 2 == 0 then Palette.roofRed else Palette.cream
		)
	end
	-- The goods: two seed sacks, a crate of corn and a flower pot
	b.ball("Sack", 1.6, Vector3.new(-2, 3.9, 0.5), Palette.sack)
	b.ball("Sack", 1.4, Vector3.new(-0.6, 3.8, 0.9), Palette.straw)
	b.block("Crate", Vector3.new(1.6, 1, 1.6), Vector3.new(1.6, 3.9, 0.4), Palette.crate)
	b.ball("Corn", 0.8, Vector3.new(1.4, 4.5, 0.4), Palette.corn, { shadow = false })
	b.ball("Corn", 0.8, Vector3.new(1.9, 4.5, 0.6), Palette.corn, { shadow = false })
	b.post("Pot", 0.9, 0.9, Vector3.new(0.3, 3.7, -1), Palette.brick)
	b.ball("Flower", 0.8, Vector3.new(0.3, 4.4, -1), Palette.flowerPink, { shadow = false })
	-- Sign board along the front for the countdown
	b.block("SignFrame", Vector3.new(5.4, 1.6, 0.2), Vector3.new(0, 2.4, -2.1), Palette.woodDark)
	local sign = b.block("Sign", Vector3.new(5, 1.2, 0.2), Vector3.new(0, 2.4, -2.2), Palette.cream, { shadow = false })
	Kit.sproutTag(b, Vector3.new(3.2, 8.2, 1.7), 1.4, Palette.wood, Palette.lime)
	return { model = model, body = body, sign = sign }
end

return ArtSeedCart

--!strict
-- The Tinker's Guild on the plot (Features/F01 Quarry & Smelter): a two-storey workshop, a
-- fieldstone ground floor under a timber upper floor and a steep teal roof. A big brass cog
-- hangs on the front gable, a crane arm with a hook pokes out over the door and a workbench
-- stands outside. Faces local -Z; 10 x 12 studs like a factory. 40 parts or fewer.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtGuild = {}

ArtGuild.PARTS_MAX = 40
ArtGuild.WIDTH = 10
ArtGuild.DEPTH = 12

local TURN = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis from X to Z

-- Builds the Guild into `model` at `cf` (bottom-centre). Returns the body (tap target).
function ArtGuild.build(model: Model, cf: CFrame): BasePart
	local b = Kit.builder(model, cf, true)
	local w, d = ArtGuild.WIDTH, ArtGuild.DEPTH
	local front = -d / 2
	b.block("Plinth", Vector3.new(w + 0.6, 0.75, d + 0.6), Vector3.new(0, 0.375, 0), Palette.stoneDark)
	local body = b.block("Body", Vector3.new(w, 5, d), Vector3.new(0, 3.25, 0), Palette.stoneLight, { collide = true })
	local g = b.into(body, true)
	g.block("Upper", Vector3.new(w + 0.6, 4, d + 0.6), Vector3.new(0, 7.75, 0), Palette.cream)
	for _, x in { -w / 2 - 0.1, w / 2 + 0.1 } do
		g.block("Beam", Vector3.new(0.4, 4, 0.4), Vector3.new(x, 7.75, front - 0.35), Palette.woodDark)
	end
	g.block("Sill", Vector3.new(w + 0.8, 0.4, 0.4), Vector3.new(0, 5.85, front - 0.35), Palette.woodDark)
	Kit.gableRoof(g, "Roof", Vector3.new(0, 9.75, 0), w + 1.6, d + 1.6, 4.5, Palette.roofTeal, Palette.cream)
	local chimney = g.block("Chimney", Vector3.new(1.4, 3, 1.4), Vector3.new(3, 12.5, 3.6), Palette.brick)
	g.block("ChimneyCap", Vector3.new(1.8, 0.4, 1.8), Vector3.new(3, 14.2, 3.6), Palette.stoneDark)
	-- The brass cog on the gable: a disc, a hub and four teeth
	local cog = Vector3.new(0, 11.4, front - 0.5)
	g.cyl("Cog", 0.4, 2.8, CFrame.new(cog) * TURN, Palette.coins, { shadow = false })
	g.cyl("CogHub", 0.6, 0.9, CFrame.new(cog + Vector3.new(0, 0, -0.1)) * TURN, Palette.woodDark, { shadow = false })
	for i = 0, 3 do
		g.block(
			"Tooth",
			Vector3.new(0.7, 3.6, 0.35),
			CFrame.new(cog) * CFrame.Angles(0, 0, math.rad(45 * i)),
			Palette.coins,
			{ shadow = false }
		)
	end
	Kit.window(g, "Window", CFrame.new(-2.4, 7.6, front - 0.3), 2.4, 2, Palette.woodDark, Palette.glass)
	Kit.window(g, "Window", CFrame.new(-2.4, 3.2, front), 2.4, 2, Palette.woodDark, Palette.glass)
	Kit.door(g, "Door", CFrame.new(2.2, 0.75, front), 2.6, 4, Palette.roofTeal, Palette.woodDark)
	-- The crane arm over the door, with its rope and hook
	g.block("Crane", Vector3.new(0.4, 0.4, 2.6), Vector3.new(2.2, 9.2, front - 1.6), Palette.woodDark)
	g.block("Rope", Vector3.new(0.12, 2.2, 0.12), Vector3.new(2.2, 7.9, front - 2.7), Palette.straw, { shadow = false })
	g.block("Hook", Vector3.new(0.5, 0.4, 0.2), Vector3.new(2.2, 6.7, front - 2.7), Palette.metal, { shadow = false })
	-- The workbench outside, with a vice and a Bar on it
	local bench = Vector3.new(-3.2, 0, front - 2.2)
	g.block("Bench", Vector3.new(3, 0.3, 1.2), bench + Vector3.new(0, 1.8, 0), Palette.wood)
	for _, x in { -1.2, 1.2 } do
		g.block("BenchLeg", Vector3.new(0.3, 1.65, 1), bench + Vector3.new(x, 0.82, 0), Palette.woodDark)
	end
	g.block("Vice", Vector3.new(0.6, 0.6, 0.6), bench + Vector3.new(-0.8, 2.25, 0), Palette.metal, { shadow = false })
	g.block("Bar", Vector3.new(0.9, 0.3, 0.45), bench + Vector3.new(0.6, 2.1, 0), Palette.coins, { shadow = false })
	Kit.sproutTag(g, Vector3.new(-3.4, 12.2, 3), 2.5, Palette.wood, Palette.lime)
	chimney.Name = "Chimney"
	return body
end

return ArtGuild

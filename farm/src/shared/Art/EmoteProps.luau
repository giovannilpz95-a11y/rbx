--!strict
-- Props held or worn for a farm emote (Config/Emotes), and the two Town Square photo spots.
-- Each prop is built around its own origin (where it attaches: the top of the head, or the
-- palm of the right hand) so the server can weld it to the avatar. A few parts each.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtEmoteProps = {}

export type Prop = { model: Model, attach: string, offset: CFrame }

local NO = { shadow = false }
local CARROT = Color3.fromRGB(242, 140, 40)
local LEAF = Palette.grassDark

-- name -> builder, the body part it goes on, and where on that part
local PROPS: { [string]: { attach: string, offset: CFrame, build: (Kit.Builder) -> () } } = {
	StrawHat = {
		attach = "Head",
		offset = CFrame.new(0, 0.55, 0),
		build = function(b)
			b.cyl("Brim", 0.12, 2.6, CFrame.Angles(0, 0, math.rad(90)), Palette.straw, NO)
			b.cyl("Crown", 0.6, 1.3, CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Palette.straw, NO)
			b.cyl("Band", 0.16, 1.34, CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Palette.roofRed, NO)
		end,
	},
	Carrot = {
		attach = "RightHand",
		offset = CFrame.new(0, -0.2, -0.3),
		build = function(b)
			b.cyl("Root", 1.4, 0.45, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0), CARROT, NO)
			b.block("Tip", Vector3.new(0.25, 0.25, 0.4), CFrame.new(0, 0, 0.85), CARROT, NO)
			b.block(
				"Leaf",
				Vector3.new(0.12, 0.7, 0.12),
				CFrame.new(0, 0.2, -0.85) * CFrame.Angles(math.rad(-25), 0, 0),
				LEAF,
				NO
			)
			b.block(
				"Leaf",
				Vector3.new(0.12, 0.6, 0.12),
				CFrame.new(0, 0.15, -0.85) * CFrame.Angles(math.rad(-60), 0, 0),
				LEAF,
				NO
			)
		end,
	},
	Crate = {
		attach = "Head",
		offset = CFrame.new(0, 2.1, 0),
		build = function(b)
			b.block("Box", Vector3.new(2.2, 1.5, 1.6), CFrame.new(), Palette.wood, NO)
			b.block("Slat", Vector3.new(2.3, 0.25, 1.7), CFrame.new(0, 0.4, 0), Palette.woodDark, NO)
			b.ball("Apple", 0.6, CFrame.new(-0.5, 0.95, 0), Palette.roofRed, NO)
			b.ball("Apple", 0.6, CFrame.new(0.3, 0.95, 0.2), Palette.roofRed, NO)
		end,
	},
	Chick = {
		attach = "RightHand",
		offset = CFrame.new(0, 0.35, -0.2),
		build = function(b)
			b.ball("Body", 0.9, CFrame.new(), Palette.straw, NO)
			b.ball("Head", 0.55, CFrame.new(0, 0.45, -0.25), Palette.straw, NO)
			b.block("Beak", Vector3.new(0.18, 0.12, 0.2), CFrame.new(0, 0.42, -0.58), CARROT, NO)
			b.block("Comb", Vector3.new(0.08, 0.18, 0.22), CFrame.new(0, 0.78, -0.25), Palette.roofRed, NO)
		end,
	},
	Wheat = {
		attach = "RightHand",
		offset = CFrame.new(0, 0.6, -0.2),
		build = function(b)
			for i = -1, 1 do
				local lean = CFrame.Angles(0, 0, math.rad(i * 12))
				b.block("Stalk", Vector3.new(0.1, 1.8, 0.1), lean * CFrame.new(0, 0.6, 0), Palette.straw, NO)
				b.block("Ear", Vector3.new(0.22, 0.6, 0.22), lean * CFrame.new(0, 1.6, 0), Palette.coins, NO)
			end
			b.block("Tie", Vector3.new(0.4, 0.15, 0.4), CFrame.new(0, 0, 0), Palette.roofRed, NO)
		end,
	},
	HayPuff = {
		attach = "UpperTorso",
		offset = CFrame.new(0, 0.6, -0.6),
		build = function(b)
			local anchor = b.block("Puff", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), Palette.straw, NO)
			anchor.Transparency = 1
			local burst = Instance.new("ParticleEmitter")
			burst.Name = "Hay"
			burst.Color = ColorSequence.new(Palette.straw, Palette.coins)
			burst.Size = NumberSequence.new(0.35, 0.1)
			burst.Transparency = NumberSequence.new(0, 1)
			burst.Lifetime = NumberRange.new(0.8, 1.4)
			burst.Speed = NumberRange.new(4, 7)
			burst.SpreadAngle = Vector2.new(70, 70)
			burst.Acceleration = Vector3.new(0, -12, 0)
			burst.Rotation = NumberRange.new(0, 360)
			burst.RotSpeed = NumberRange.new(-90, 90)
			burst.Rate = 24
			burst.EmissionDirection = Enum.NormalId.Top
			burst.Parent = anchor
		end,
	},
}

function ArtEmoteProps.has(name: string): boolean
	return PROPS[name] ~= nil
end

-- A prop built at the origin, unanchored and weightless, ready to weld
function ArtEmoteProps.build(name: string): Prop?
	local spec = PROPS[name]
	if spec == nil then
		return nil
	end
	local model = Kit.model("EmoteProp_" .. name)
	spec.build(Kit.builder(model, CFrame.new(), false))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	return { model = model, attach = spec.attach, offset = spec.offset }
end

function ArtEmoteProps.names(): { string }
	local out = {}
	for name in PROPS do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- The photo spots: a big prop to pose with and a wooden frame with a sign, facing local -Z
-- (where the photographer stands). `cf` is the centre of the spot on the ground.
function ArtEmoteProps.photoSpot(kind: string, parent: Instance, cf: CFrame): Model
	local model = Kit.model("PhotoSpot_" .. kind, parent)
	local b = Kit.builder(model, cf, true)
	if kind == "Pumpkin" then
		local orange = Color3.fromRGB(242, 140, 40)
		local rib = Color3.fromRGB(222, 118, 30)
		b.ball("Pumpkin", 7, CFrame.new(0, 3.2, 3), orange, { collide = true })
		b.ball("Rib", 6, CFrame.new(-2.2, 3, 3), rib)
		b.ball("Rib", 6, CFrame.new(2.2, 3, 3), rib)
		b.post("Stem", 1.6, 0.8, CFrame.new(0, 7.2, 3), Palette.woodDark)
		b.block("Leaf", Vector3.new(2, 0.2, 1.2), CFrame.new(1.2, 6.6, 3) * CFrame.Angles(0, 0, math.rad(-20)), LEAF)
	else
		-- A throne of hay bales: seat, back and arms, with a wheat crown on top
		b.block("Seat", Vector3.new(6, 2, 3.6), CFrame.new(0, 1, 3), Palette.straw, { collide = true })
		b.block("Back", Vector3.new(6, 4.4, 1.6), CFrame.new(0, 3.2, 4.6), Palette.straw, { collide = true })
		b.block("ArmL", Vector3.new(1.4, 1.4, 3.6), CFrame.new(-3.2, 2.5, 3), Palette.straw)
		b.block("ArmR", Vector3.new(1.4, 1.4, 3.6), CFrame.new(3.2, 2.5, 3), Palette.straw)
		b.block("Twine", Vector3.new(6.1, 0.2, 3.7), CFrame.new(0, 1.4, 3), Palette.woodDark)
		for i = -1, 1 do
			b.block("Crown", Vector3.new(0.5, 1.2, 0.5), CFrame.new(i * 1.4, 6, 4.6), Palette.coins)
		end
	end
	-- The frame: two posts and a beam with a sign, behind the prop
	b.block("PostL", Vector3.new(0.6, 10, 0.6), CFrame.new(-5.5, 5, 6.5), Palette.woodDark)
	b.block("PostR", Vector3.new(0.6, 10, 0.6), CFrame.new(5.5, 5, 6.5), Palette.woodDark)
	local beam = b.block("Beam", Vector3.new(12, 1.4, 0.4), CFrame.new(0, 10, 6.5), Palette.wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Palette.cream
	text.Text = "PHOTO SPOT"
	text.Parent = gui
	gui.Parent = beam
	return model
end

return ArtEmoteProps

-- Farm emotes and photo spots (Config/Emotes, Art/EmoteProps). Called from tests/run.luau.

local roblox = require("@lune/roblox")

local Config = require("../src/shared/Config/Emotes")

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("emotes: six farm emotes, each with its own animation and prop", function()
		local count, orders, animations = 0, {}, {}
		for id, def in Config.emotes do
			count += 1
			eq(def.id, id, "id matches its key")
			ok(orders[def.order] == nil, "order " .. def.order .. " is unique")
			orders[def.order] = true
			ok(animations[def.animation] == nil, id .. " has its own animation")
			animations[def.animation] = true
			ok(def.animation:match("^rbxassetid://%d+$") ~= nil, id .. " animation id")
			ok(#def.displayName > 0 and #def.icon > 0, id .. " has a name and icon")
		end
		eq(count, 6, "six emotes (Design/14 v1)")
		for i = 1, count do
			ok(orders[i], "orders run 1.." .. count)
		end
		ok(Config.emotes[Config.photoEmote] ~= nil, "the group pose is one of the emotes")
		ok(Config.cooldown >= Config.seconds, "an emote ends before the next can start")
	end)

	test("emotes: two photo spots, and a spot's pose can't be spammed", function()
		local n = 0
		for _ in Config.photoSpots do
			n += 1
		end
		eq(n, 2, "two photo spots (Design/14 v1)")
		ok(Config.photoCooldown > Config.seconds, "the next pose waits for this one to end")
		ok(Config.photoRadius >= 8, "the frame has room for a group")
	end)

	test("art: emote props and photo spots build, weightless and small", function()
		Instance = roblox.Instance
		UDim2 = roblox.UDim2 -- the photo spot's sign
		local ArtEmoteProps = require("../src/shared/Art/EmoteProps")
		local Kit = require("../src/shared/Art/Kit")
		for _, def in Config.emotes do
			ok(ArtEmoteProps.has(def.prop), def.id .. " prop exists")
			local prop = ArtEmoteProps.build(def.prop) :: any
			ok(prop.attach == "Head" or prop.attach == "RightHand" or prop.attach == "UpperTorso", "attach part")
			local parts = Kit.countParts(prop.model)
			ok(parts >= 1 and parts <= 12, string.format("%s %d parts", def.prop, parts))
			for _, p in prop.model:GetDescendants() do
				if p:IsA("BasePart") then
					ok(not p.Anchored and p.Massless and not p.CanCollide and not p.CanQuery, def.prop .. " weightless")
				end
			end
		end
		for kind in Config.photoSpots do
			local m = Instance.new("Model")
			local spot = ArtEmoteProps.photoSpot(kind, m, roblox.CFrame.new())
			local parts = Kit.countParts(spot)
			ok(parts >= 4 and parts <= 16, string.format("%s %d parts", kind, parts))
		end
	end)
end

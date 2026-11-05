-- The Wardrobe (Config/Wardrobe, shared/Wardrobe, Art/Outfits): buying, wearing, earned
-- pieces and the outfit art. Called from tests/run.luau.

local roblox = require("@lune/roblox")

local Config = require("../src/shared/Config/Wardrobe")
local EventConfig = require("../src/shared/Config/Events")
local Profile = require("../src/shared/Profile")
local Wardrobe = require("../src/shared/Wardrobe")

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("wardrobe: every piece is sold, earned or free, and slots are tidy", function()
		local free = 0
		for id, piece in Config.pieces do
			eq(piece.id, id, "id matches its key")
			ok(table.find(Config.slots, piece.slot) ~= nil, id .. " slot")
			local ways = (if piece.coins then 1 else 0)
				+ (if piece.gems then 1 else 0)
				+ (if piece.earn then 1 else 0)
				+ (if piece.free then 1 else 0)
			eq(ways, 1, id .. " has exactly one way to get it")
			ok(piece.coins == nil or piece.level ~= nil, id .. " Coin pieces open at a level")
			if piece.free then
				free += 1
			end
			if piece.earn and piece.earn.kind == "event" then
				ok(EventConfig.events[piece.earn.event or ""] ~= nil, id .. " names a real event")
				local def = EventConfig.events[piece.earn.event :: string]
				local top = def.milestones[#def.milestones].tokens
				ok(
					(piece.earn.earned or 0) > 0 and (piece.earn.earned :: number) < top,
					id .. " inside the prize track"
				)
			end
		end
		eq(free, 1, "one free piece to start with")
		for _, slot in Config.slots do
			local list = Wardrobe.sorted(slot)
			ok(#list >= 3, slot .. " has a few pieces")
			for i, piece in list do
				eq(piece.order, i, slot .. " orders run 1..n")
			end
			ok(Config.slotNames[slot] ~= nil and Config.slotIcons[slot] ~= nil, slot .. " name and icon")
		end
	end)

	test("wardrobe: buy, wear, take off and hide", function()
		local data = Profile.template()
		data.level = 1
		data.currencies.Coins = 10000
		data.currencies.Gems = 0
		ok(Wardrobe.owns(data, "StrawHat"), "the free hat")
		ok(not Wardrobe.owns(data, "FarmerCap"), "not the cap yet")
		local piece, why = Wardrobe.canBuy(data, "FarmerCap")
		ok(piece == nil and why ~= nil and why:find("level") ~= nil, "a level to wait for")
		data.level = 10
		piece = Wardrobe.canBuy(data, "FarmerCap")
		ok(piece ~= nil, "now for sale")
		eq(select(2, Wardrobe.canBuy(data, "RanchHat")), "Not enough Gems", "Gem pieces need Gems")
		eq(select(2, Wardrobe.canBuy(data, "BlueRosette")), nil, "earn-only pieces aren't sold")
		eq(select(2, Wardrobe.canBuy(data, "StrawHat")), nil, "the free one isn't sold")
		eq(select(2, Wardrobe.canBuy(data, 42)), nil, "junk")
		Wardrobe.give(data, "FarmerCap")
		eq(Wardrobe.outfit(data).Hat, "FarmerCap", "worn on buying")
		ok(Wardrobe.canBuy(data, "FarmerCap") == nil, "only once")

		eq(select(2, Wardrobe.wear(data, "Hat", "Sunbonnet")), "Get the Sunbonnet first", "only what you own")
		eq((Wardrobe.wear(data, "Neck", "StrawHat")), false, "a piece goes in its own slot")
		eq((Wardrobe.wear(data, "Feet", "StrawHat")), false, "junk slot")
		eq((Wardrobe.wear(data, "Hat", 5)), false, "junk id")
		ok((Wardrobe.wear(data, "Hat", "StrawHat")), "swap hats")
		eq(Wardrobe.outfit(data).Hat, "StrawHat", "the straw hat on")
		ok((Wardrobe.wear(data, "Hat", "")), "take it off")
		eq(Wardrobe.outfit(data).Hat, nil, "bare head")

		Wardrobe.wear(data, "Hat", "StrawHat")
		data.wardrobe.show = false
		eq(next(Wardrobe.outfit(data)), nil, "hidden: just the player's own avatar")
		Wardrobe.wear(data, "Hat", "FarmerCap")
		ok(data.wardrobe.show, "putting something on shows the outfit again")
		data.wardrobe.worn.Back = "StrawHat"
		eq(Wardrobe.outfit(data).Back, nil, "a piece in the wrong slot (old save) is skipped")
	end)

	test("wardrobe: pieces earned at the Fair, the Showcase and the event", function()
		local data = Profile.template()
		eq(#Wardrobe.grantEarned(data), 0, "nothing earned yet")
		data.fair.ribbons.Blue = 1
		data.showcase.wins = 1
		local fresh = Wardrobe.grantEarned(data)
		eq(table.concat(fresh, ","), "BlueRosette,SunflowerHat", "Blue Ribbon and Showcase win")
		eq(#Wardrobe.grantEarned(data), 0, "only once")
		data.event.id = "HarvestFair"
		data.event.earned = 700
		eq(table.concat(Wardrobe.grantEarned(data), ","), "PumpkinCap", "600 Ribbons earned")
		data.event.earned = 5000
		data.event.id = "Other"
		eq(#Wardrobe.grantEarned(data), 0, "another event's tokens don't count")
		ok(Wardrobe.earnText(Config.pieces.RibbonSash):find("Harvest Fair") ~= nil, "earn text names the event")
		ok(#Wardrobe.earnText(Config.pieces.BlueRosette) > 0, "earn text")
	end)

	test("art: every Wardrobe piece builds, weightless and small, for R15 and R6 sizes", function()
		Instance = roblox.Instance
		local ArtOutfits = require("../src/shared/Art/Outfits")
		local Kit = require("../src/shared/Art/Kit")
		local sizes = {
			Head = { roblox.Vector3.new(1.2, 1.2, 1.2), roblox.Vector3.new(2, 1, 1) },
			UpperTorso = { roblox.Vector3.new(2, 1.6, 1), roblox.Vector3.new(2, 2, 1) },
		}
		for id in Config.pieces do
			ok(ArtOutfits.has(id), id .. " has art")
			local attach = ArtOutfits.attach(id) :: string
			ok(sizes[attach] ~= nil, id .. " goes on the Head or UpperTorso")
			for _, size in sizes[attach] do
				local built = ArtOutfits.build(id, size) :: any
				local parts = Kit.countParts(built.model)
				ok(parts >= 1 and parts <= 12, string.format("%s %d parts", id, parts))
				for _, p in built.model:GetDescendants() do
					if p:IsA("BasePart") then
						ok(not p.Anchored and p.Massless and not p.CanCollide and not p.CanQuery, id .. " weightless")
						ok(p.CFrame.Position.Magnitude < 3, id .. " stays on the body")
					end
				end
			end
		end
		eq(
			#ArtOutfits.names(),
			(function()
				local n = 0
				for _ in Config.pieces do
					n += 1
				end
				return n
			end)(),
			"no art without a piece"
		)
	end)
end

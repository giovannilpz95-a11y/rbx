--!strict
-- Wardrobe rules (Config/Wardrobe), pure so Lune tests cover them. The save block is
-- data.wardrobe = { owned = { id -> true }, worn = { slot -> id }, show = true }.

local Config = require("./Config/Wardrobe")
local EventConfig = require("./Config/Events")

local Wardrobe = {}

function Wardrobe.sorted(slot: string): { Config.Piece }
	local list = {}
	for _, piece in Config.pieces do
		if piece.slot == slot then
			table.insert(list, piece)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function Wardrobe.owns(data: { [string]: any }, id: string): boolean
	local piece = Config.pieces[id]
	return piece ~= nil and (piece.free == true or data.wardrobe.owned[id] == true)
end

-- Is this earn-only piece's goal met by the farm right now?
local function met(data: { [string]: any }, earn: Config.Earn): boolean
	if earn.kind == "fairBlue" then
		return (data.fair.ribbons.Blue or 0) > 0
	elseif earn.kind == "showcaseWin" then
		return data.showcase.wins > 0
	elseif earn.kind == "event" then
		return data.event.id == earn.event and data.event.earned >= (earn.earned or 0)
	end
	return false
end

-- Hand over every earn-only piece whose goal is met. Returns the new pieces' ids, sorted.
function Wardrobe.grantEarned(data: { [string]: any }): { string }
	local fresh = {}
	for id, piece in Config.pieces do
		if piece.earn and not Wardrobe.owns(data, id) and met(data, piece.earn) then
			data.wardrobe.owned[id] = true
			table.insert(fresh, id)
		end
	end
	table.sort(fresh)
	return fresh
end

-- The currency and price of a piece for sale, or nil for an earn-only or free piece
function Wardrobe.price(piece: Config.Piece): (string?, number)
	if piece.coins then
		return "Coins", piece.coins
	elseif piece.gems then
		return "Gems", piece.gems
	end
	return nil, 0
end

-- Can this farm buy it? Returns the piece, or nil and a reason (nil reason = junk)
function Wardrobe.canBuy(data: { [string]: any }, id: any): (Config.Piece?, string?)
	local piece = if type(id) == "string" then Config.pieces[id] else nil
	if piece == nil then
		return nil, nil
	end
	local currency, price = Wardrobe.price(piece)
	if currency == nil then
		return nil, nil
	end
	if Wardrobe.owns(data, id) then
		return nil, "You already have the " .. piece.displayName
	end
	if piece.level and data.level < piece.level then
		return nil, string.format("The %s is for sale from level %d", piece.displayName, piece.level)
	end
	if data.currencies[currency] < price then
		return nil, string.format("Not enough %s", currency)
	end
	return piece, nil
end

-- After canBuy and the payment
function Wardrobe.give(data: { [string]: any }, id: string)
	data.wardrobe.owned[id] = true
	data.wardrobe.worn[Config.pieces[id].slot] = id
	data.wardrobe.show = true
end

-- Put a piece on (id) or take the slot's piece off (id ""). Returns false and a reason (nil
-- reason = junk).
function Wardrobe.wear(data: { [string]: any }, slot: any, id: any): (boolean, string?)
	if type(slot) ~= "string" or table.find(Config.slots, slot :: any) == nil or type(id) ~= "string" then
		return false, nil
	end
	if id == "" then
		data.wardrobe.worn[slot] = nil
		return true, nil
	end
	local piece = Config.pieces[id]
	if piece == nil or piece.slot ~= slot then
		return false, nil
	end
	if not Wardrobe.owns(data, id) then
		return false, "Get the " .. piece.displayName .. " first"
	end
	data.wardrobe.worn[slot] = id
	data.wardrobe.show = true
	return true, nil
end

-- What the avatar shows: slot -> piece id (nothing while the outfit is hidden)
function Wardrobe.outfit(data: { [string]: any }): { [string]: string }
	local out = {}
	if data.wardrobe.show == false then
		return out
	end
	for _, slot in Config.slots do
		local id = data.wardrobe.worn[slot]
		if type(id) == "string" and Wardrobe.owns(data, id) and Config.pieces[id].slot == slot then
			out[slot] = id
		end
	end
	return out
end

-- How an earn-only piece is earned, for the panel
function Wardrobe.earnText(piece: Config.Piece): string
	local earn = piece.earn
	if earn == nil then
		return ""
	elseif earn.kind == "fairBlue" then
		return "Win a Blue Ribbon at the County Fair"
	elseif earn.kind == "showcaseWin" then
		return "Win a Plot Showcase"
	end
	local def = EventConfig.events[earn.event or ""]
	if def == nil then
		return "Earned in an event"
	end
	return string.format("Earn %s %d %s in the %s", def.tokenIcon, earn.earned or 0, def.tokenName, def.displayName)
end

return Wardrobe

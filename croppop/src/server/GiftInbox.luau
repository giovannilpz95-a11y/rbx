--[[
	Heart gift boxes: one list per player of hearts their neighbors sent,
	kept outside the farm save so a gift reaches a player who is offline or
	on another server.

	A box store has two calls, both pcall-style (ok first):
		read(userId) -> (ok, box?)
		update(userId, transform) -> (ok, newBox?)
	`transform(box?)` returns the new box, or nil to leave it alone. It may run
	more than once (DataStore UpdateAsync retries), so it must not change
	anything outside itself.

	A box is a list of { from = userId, t = os.time() }, oldest first.
]]

local CropPop = require(game:GetService("ReplicatedStorage"):WaitForChild("CropPop"))

local Gifts = CropPop.Hearts.Gifts

local GiftInbox = {}

local DAY = 24 * 60 * 60

-- The live gifts in a saved box (drops malformed and expired ones).
function GiftInbox.clean(raw: any, now: number): { { from: number, t: number } }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, gift in raw do
		if
			type(gift) == "table"
			and type(gift.from) == "number"
			and type(gift.t) == "number"
			and now - gift.t < Gifts.KEEP_DAYS * DAY
		then
			table.insert(out, { from = gift.from, t = gift.t })
		end
		if #out >= Gifts.BOX_MAX then
			break
		end
	end
	return out
end

-- An in-memory store, for tests and Studio (one server, nothing saved).
function GiftInbox.memory()
	local boxes = {}
	return {
		read = function(userId: number)
			local box = boxes[userId]
			return true, if box then table.clone(box) else nil
		end,
		update = function(userId: number, transform)
			local current = boxes[userId]
			local new = transform(if current then table.clone(current) else nil)
			if new ~= nil then
				boxes[userId] = new
			end
			return true, new
		end,
	}
end

-- A store on a Roblox DataStore, keyed "u<userId>".
function GiftInbox.dataStore(store: any)
	return {
		read = function(userId: number)
			return pcall(function()
				return store:GetAsync("u" .. userId)
			end)
		end,
		update = function(userId: number, transform)
			return pcall(function()
				return store:UpdateAsync("u" .. userId, function(old)
					return transform(old)
				end)
			end)
		end,
	}
end

return GiftInbox

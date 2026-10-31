--!strict
-- Which Roblox badge a Town Record medal gives (Config/Badges), and every badge a save has
-- earned so far. Pure, so the tests check it.

local Config = require("./Config/Badges")

local Badges = {}

-- The badge for claiming `tier` (1-3) of a record, or nil when none is set up
function Badges.forMedal(recordId: string, tier: number): number?
	local slots = Config.records[recordId]
	local id = if slots then slots[tier] else nil
	if type(id) == "number" and id > 0 then
		return id
	end
	return nil
end

-- Every badge the save's claimed medals give, for players who claimed before it existed
function Badges.earned(data: { [string]: any }): { number }
	local out = {}
	for recordId, claimed in data.records.claimed do
		for tier = 1, claimed do
			local id = Badges.forMedal(recordId, tier)
			if id then
				table.insert(out, id)
			end
		end
	end
	table.sort(out)
	return out
end

return Badges

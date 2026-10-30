--[[
	Harvest Cup groups and scores, kept outside the farm save so players on
	different servers share a leaderboard (see Cup).

	A board has three calls, all pcall-style (ok first):
		join(cupKey) -> (ok, group?)              a group for a new entrant
		setScore(cupKey, group, userId, cups) -> (ok)
		top(cupKey, group, count) -> (ok, { { userId, cups } }?, players?)
	`top` is best first; `players` is how many are in the group.

	Groups fill in entry order: the nth player to enter a cup goes in group
	(n - 1) // GROUP_SIZE.
]]

local CropPop = require(game:GetService("ReplicatedStorage"):WaitForChild("CropPop"))

local Cup = CropPop.Cup

local CupBoard = {}

local function groupOf(entrant: number): number
	return (entrant - 1) // Cup.GROUP_SIZE
end

local function sortScores(scores)
	local list = {}
	for userId, cups in scores do
		table.insert(list, { userId = userId, cups = cups })
	end
	table.sort(list, function(a, b)
		if a.cups ~= b.cups then
			return a.cups > b.cups
		end
		return a.userId < b.userId
	end)
	return list
end

-- An in-memory board, for tests and Studio (one server, nothing saved).
function CupBoard.memory()
	local entrants = {}
	local groups = {}
	local function scoresOf(cupKey, group)
		local id = cupKey .. ":" .. group
		groups[id] = groups[id] or {}
		return groups[id]
	end
	return {
		join = function(cupKey: number)
			entrants[cupKey] = (entrants[cupKey] or 0) + 1
			return true, groupOf(entrants[cupKey])
		end,
		setScore = function(cupKey: number, group: number, userId: number, cups: number)
			scoresOf(cupKey, group)[userId] = cups
			return true
		end,
		top = function(cupKey: number, group: number, count: number)
			local list = sortScores(scoresOf(cupKey, group))
			local players = #list
			while #list > count do
				table.remove(list)
			end
			return true, list, players
		end,
	}
end

--[[
	A board on Roblox data stores: `counts` (a DataStore) holds each cup's
	entrant count under "c<cupKey>", and `ordered(name)` returns the
	OrderedDataStore for one group ("CropPopCup<cupKey>g<group>", keys "u<userId>").
]]
function CupBoard.dataStore(counts: any, ordered: (name: string) -> any)
	local function groupStore(cupKey: number, group: number)
		return ordered("CropPopCup" .. cupKey .. "g" .. group)
	end
	return {
		join = function(cupKey: number)
			return pcall(function()
				local n = counts:UpdateAsync("c" .. cupKey, function(old)
					return (if type(old) == "number" then old else 0) + 1
				end)
				return groupOf(n)
			end)
		end,
		setScore = function(cupKey: number, group: number, userId: number, cups: number)
			return pcall(function()
				groupStore(cupKey, group):SetAsync("u" .. userId, cups)
			end)
		end,
		top = function(cupKey: number, group: number, count: number)
			return pcall(function()
				local page = groupStore(cupKey, group):GetSortedAsync(false, Cup.GROUP_SIZE):GetCurrentPage()
				local list = {}
				for _, entry in page do
					local userId = tonumber(string.sub(entry.key, 2))
					if userId and #list < count then
						table.insert(list, { userId = userId, cups = entry.value })
					end
				end
				return list, #page
			end)
		end,
	}
end

return CupBoard

--[[
	Crop Pop level goals:

	  { kind = "Collect", tile = "Tomato", count = 15 }  -- pop N tiles of one kind
	  { kind = "Mud" }                                   -- clear every mud layer on the board
	  { kind = "HayBale" }                               -- break every hay bale on the board
	  { kind = "Frost" }                                 -- break every frost layer on the board
	  { kind = "Weeds" }                                 -- pull every weed, including ones that spread
	  { kind = "Pumpkins", count = 3 }                   -- bring N pumpkins down to the bottom row
	  { kind = "Clover" }                                -- grow clover on every cell
	  { kind = "Stones" }                                -- break every stone wall (blasts only)
	  { kind = "Fences" }                                -- break every fence (blasts only)

	Board-based targets are counted from the board unless `count` is given.
	A weed that spreads adds one to the Weeds target.
]]

local Tiles = require(script.Parent.Tiles)

local Goals = {}
Goals.__index = Goals

export type Goal = {
	kind: string,
	color: number?, -- Collect only
	target: number,
	progress: number,
}

function Goals.new(defs: { any }, board)
	local mudLayers, bales, frost, weeds, bare, stones = 0, 0, 0, 0, 0, 0
	board:eachCell(function(cell)
		if not cell.clover then
			bare += 1
		end
		mudLayers += cell.mud
		frost += cell.frost
		if cell.stone then
			stones += 1
		elseif cell.weed then
			weeds += 1
		elseif cell.bale > 0 then
			bales += 1
		end
	end)

	local list: { Goal } = {}
	for _, def in defs do
		if def.kind == "Collect" then
			table.insert(list, {
				kind = "Collect",
				color = Tiles.ByName[def.tile],
				target = def.count,
				progress = 0,
			})
		elseif def.kind == "Mud" then
			table.insert(list, { kind = "Mud", target = def.count or mudLayers, progress = 0 })
		elseif def.kind == "HayBale" then
			table.insert(list, { kind = "HayBale", target = def.count or bales, progress = 0 })
		elseif def.kind == "Frost" then
			table.insert(list, { kind = "Frost", target = def.count or frost, progress = 0 })
		elseif def.kind == "Weeds" then
			table.insert(list, { kind = "Weeds", target = def.count or weeds, progress = 0 })
		elseif def.kind == "Pumpkins" then
			table.insert(list, { kind = "Pumpkins", target = def.count, progress = 0 })
		elseif def.kind == "Stones" then
			table.insert(list, { kind = "Stones", target = def.count or stones, progress = 0 })
		elseif def.kind == "Fences" then
			table.insert(list, { kind = "Fences", target = def.count or board.fenceCount, progress = 0 })
		elseif def.kind == "Clover" then
			table.insert(list, { kind = "Clover", target = def.count or bare, progress = 0 })
		else
			error("unknown goal kind " .. tostring(def.kind))
		end
	end
	return setmetatable({ list = list }, Goals)
end

local function bump(self, kind: string, color: number?)
	for _, goal in self.list do
		if goal.kind == kind and goal.color == color and goal.progress < goal.target then
			goal.progress += 1
		end
	end
end

function Goals.onCollect(self, color: number)
	if color > 0 then
		bump(self, "Collect", color)
	end
end

function Goals.onMud(self)
	bump(self, "Mud", nil)
end

function Goals.onBale(self)
	bump(self, "HayBale", nil)
end

function Goals.onFrost(self)
	bump(self, "Frost", nil)
end

function Goals.onWeed(self)
	bump(self, "Weeds", nil)
end

function Goals.onPumpkin(self)
	bump(self, "Pumpkins", nil)
end

function Goals.onStone(self)
	bump(self, "Stones", nil)
end

function Goals.onFence(self)
	bump(self, "Fences", nil)
end

function Goals.onClover(self)
	bump(self, "Clover", nil)
end

-- A weed spread onto a new cell: one more to pull.
function Goals.onWeedGrown(self)
	for _, goal in self.list do
		if goal.kind == "Weeds" then
			goal.target += 1
		end
	end
end

function Goals.isComplete(self): boolean
	for _, goal in self.list do
		if goal.progress < goal.target then
			return false
		end
	end
	return true
end

-- True while this kind of goal still needs work (used by Bumblebee targeting).
function Goals.wants(self, kind: string, color: number?): boolean
	for _, goal in self.list do
		if goal.kind == kind and (color == nil or goal.color == color) and goal.progress < goal.target then
			return true
		end
	end
	return false
end

-- The first goal of this kind, if the level has one.
function Goals.find(self, kind: string): Goal?
	for _, goal in self.list do
		if goal.kind == kind then
			return goal
		end
	end
	return nil
end

function Goals.snapshot(self): { Goal }
	local out = table.create(#self.list)
	for i, goal in self.list do
		out[i] = table.clone(goal)
	end
	return out
end

return Goals

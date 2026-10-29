--[[
	Crop Pop level goals. Three kinds for now:

	  { kind = "Collect", tile = "Tomato", count = 15 }  -- pop N tiles of one kind
	  { kind = "Mud" }                                   -- clear every mud layer on the board
	  { kind = "HayBale" }                               -- break every hay bale on the board

	Mud and HayBale targets are counted from the board unless `count` is given.
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
	local mudLayers, bales = 0, 0
	board:eachCell(function(cell)
		mudLayers += cell.mud
		if cell.bale > 0 then
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

function Goals.snapshot(self): { Goal }
	local out = table.create(#self.list)
	for i, goal in self.list do
		out[i] = table.clone(goal)
	end
	return out
end

return Goals

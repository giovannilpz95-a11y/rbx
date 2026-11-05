--[[
	Crop Pop level goals:

	  { kind = "Collect", tile = "Tomato", count = 15 }  -- pop N tiles of one kind
	  { kind = "Mud" }                                   -- clear every mud layer on the board (and tip every mud bucket)
	  { kind = "HayBale" }                               -- break every hay bale on the board (a hay truck counts its 3)
	  { kind = "Frost" }                                 -- break every frost layer on the board
	  { kind = "Weeds" }                                 -- pull every weed, including ones that spread
	  { kind = "Pumpkins", count = 3 }                   -- bring N pumpkins down to the bottom row
	  { kind = "Clover" }                                -- grow clover on every cell (but seed sacks)
	  { kind = "Stones" }                                -- break every stone wall (blasts only)
	  { kind = "Fences" }                                -- break every fence (blasts only)
	  { kind = "Goo" }                                   -- clear every goo cell, including ones that spread (and snail trails)
	  { kind = "Statues" }                               -- dig up every buried statue (blasts only)
	  { kind = "Tarps" }                                 -- roll up every tarp cell
	  { kind = "Webs" }                                  -- clear every web (blasts only)
	  { kind = "Honey", count = 10 }                     -- collect N honey jars (each hit on a beehive sends one)
	  { kind = "Boxes" }                                 -- take every produce box off the stacks
	  { kind = "Blooms" }                                -- make every tulip bud bloom
	  { kind = "Lambs" }                                 -- walk every lost lamb home to a pen
	  { kind = "Fireflies", count = 10 }                 -- catch N fireflies (clear tiles on lit spots)
	  { kind = "Trays" }                                 -- sprout every cell of every seed tray
	  { kind = "Bins" }                                  -- burst every compost bin
	  { kind = "Floods" }                                -- pump every flooded cell dry
	  { kind = "Packets" }                               -- empty every seed packet
	  { kind = "Gophers" }                               -- catch a gopher in every burrow
	  { kind = "Letters" }                               -- collect every letter from the mailboxes
	  { kind = "Clay" }                                  -- break up all clay (a blast cracks glazed clay first)
	  { kind = "Snowballs" }                             -- clear every snowball (they burst and come back if left)
	  { kind = "Quilts" }                                -- finish every quilt (patches come from sewing tins)

	Board-based targets are counted from the board unless `count` is given.
	A weed that spreads adds one to the Weeds target. Each mud bucket counts one
	for the Mud goal, and each layer of mud it spills adds one.
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
	local clay, letters, buckets, boxes, trucks, buds, lambs = 0, 0, 0, 0, 0, 0, 0
	local trays = #board.trays
	local bins = 0
	local floods = board.floodsLeft or 0
	local packets = 0
	local burrows = #(board.burrows or {})
	local mudLayers, bales, frost, weeds, bare, stones, goo, tarps, webs = 0, 0, 0, 0, 0, 0, 0, 0, 0
	board:eachCell(function(cell)
		if cell.web then
			webs += 1
		end
		if cell.goo then
			goo += if cell.thickGoo then 2 else 1
		end
		if not cell.clover and not cell.sack then
			bare += 1 -- a seed sack's own cell needs no clover
		end
		mudLayers += cell.mud
		if cell.clay then
			clay += 1
		end
		if cell.bucket then
			buckets += 1
		end
		if cell.bud then
			buds += 1
		end
		if cell.bin then
			bins += 1
		end
		if cell.packet then
			packets += 1
		end
		if cell.lamb then
			lambs += 1
		end
		if cell.stack then
			boxes += cell.bale
		end
		if cell.truck then
			trucks += cell.bale -- each bale it carries counts once it's broken
		end
		if cell.mailbox and cell.mailbox.mail then
			letters += 1
		end
		frost += cell.frost
		if cell.tarp then
			tarps += 1 -- tarps aren't bales for the HayBale goal
		elseif cell.crate or cell.tin or cell.quilt or cell.sack or cell.mailbox or cell.scarecrow or cell.bucket or cell.stack or cell.hive or cell.truck or cell.snail or cell.bud or cell.lamb or cell.bin or cell.pump or cell.packet or cell.mower then
			-- Surprise crates, sewing tins, quilts, seed sacks, mailboxes, scarecrows and
			-- mud buckets, box stacks, beehives, hay trucks, snails, tulip buds, lambs, compost bins, pumps, seed packets and mowers aren't bales for the HayBale goal.
		elseif cell.stone then
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
			table.insert(list, { kind = "Mud", target = def.count or mudLayers + buckets, progress = 0 })
		elseif def.kind == "HayBale" then
			table.insert(list, { kind = "HayBale", target = def.count or bales + trucks, progress = 0 })
		elseif def.kind == "Frost" then
			table.insert(list, { kind = "Frost", target = def.count or frost, progress = 0 })
		elseif def.kind == "Weeds" then
			table.insert(list, { kind = "Weeds", target = def.count or weeds, progress = 0 })
		elseif def.kind == "Pumpkins" then
			table.insert(list, { kind = "Pumpkins", target = def.count, progress = 0 })
		elseif def.kind == "Stones" then
			table.insert(list, { kind = "Stones", target = def.count or stones, progress = 0 })
		elseif def.kind == "Goo" then
			table.insert(list, { kind = "Goo", target = def.count or goo, progress = 0 })
		elseif def.kind == "Webs" then
			table.insert(list, { kind = "Webs", target = def.count or webs, progress = 0 })
		elseif def.kind == "Honey" then
			table.insert(list, { kind = "Honey", target = def.count, progress = 0 })
		elseif def.kind == "Gophers" then
			table.insert(list, { kind = "Gophers", target = def.count or burrows, progress = 0 })
		elseif def.kind == "Packets" then
			table.insert(list, { kind = "Packets", target = def.count or packets, progress = 0 })
		elseif def.kind == "Floods" then
			table.insert(list, { kind = "Floods", target = def.count or floods, progress = 0 })
		elseif def.kind == "Bins" then
			table.insert(list, { kind = "Bins", target = def.count or bins, progress = 0 })
		elseif def.kind == "Trays" then
			table.insert(list, { kind = "Trays", target = def.count or trays, progress = 0 })
		elseif def.kind == "Fireflies" then
			table.insert(list, { kind = "Fireflies", target = def.count, progress = 0 })
		elseif def.kind == "Lambs" then
			table.insert(list, { kind = "Lambs", target = def.count or lambs, progress = 0 })
		elseif def.kind == "Blooms" then
			table.insert(list, { kind = "Blooms", target = def.count or buds, progress = 0 })
		elseif def.kind == "Boxes" then
			table.insert(list, { kind = "Boxes", target = def.count or boxes, progress = 0 })
		elseif def.kind == "Letters" then
			table.insert(list, { kind = "Letters", target = def.count or letters, progress = 0 })
		elseif def.kind == "Clay" then
			table.insert(list, { kind = "Clay", target = def.count or clay, progress = 0 })
		elseif def.kind == "Snowballs" then
			table.insert(list, { kind = "Snowballs", target = def.count or #board.startSnowballs, progress = 0 })
		elseif def.kind == "Quilts" then
			table.insert(list, { kind = "Quilts", target = def.count or #board.quilts, progress = 0 })
		elseif def.kind == "Tarps" then
			table.insert(list, { kind = "Tarps", target = def.count or tarps, progress = 0 })
		elseif def.kind == "Statues" then
			table.insert(list, { kind = "Statues", target = def.count or #board.statues, progress = 0 })
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

-- A mud bucket spilt a layer of mud: one more to clear.
function Goals.onMudSpilt(self)
	for _, goal in self.list do
		if goal.kind == "Mud" then
			goal.target += 1
		end
	end
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

function Goals.onGoo(self)
	bump(self, "Goo", nil)
end

-- Goo spread onto a new cell: one more to clear.
function Goals.onGooGrown(self)
	for _, goal in self.list do
		if goal.kind == "Goo" then
			goal.target += 1
		end
	end
end

function Goals.onWeb(self)
	bump(self, "Webs", nil)
end

function Goals.onHoney(self)
	bump(self, "Honey", nil)
end

function Goals.onGopher(self)
	bump(self, "Gophers", nil)
end

function Goals.onPacket(self)
	bump(self, "Packets", nil)
end

function Goals.onFlood(self)
	bump(self, "Floods", nil)
end

function Goals.onBin(self)
	bump(self, "Bins", nil)
end

function Goals.onTray(self)
	bump(self, "Trays", nil)
end

function Goals.onFirefly(self)
	bump(self, "Fireflies", nil)
end

function Goals.onLamb(self)
	bump(self, "Lambs", nil)
end

function Goals.onBloom(self)
	bump(self, "Blooms", nil)
end

function Goals.onBox(self)
	bump(self, "Boxes", nil)
end

function Goals.onLetter(self)
	bump(self, "Letters", nil)
end

function Goals.onClay(self)
	bump(self, "Clay", nil)
end

function Goals.onSnowball(self)
	bump(self, "Snowballs", nil)
end

function Goals.onQuilt(self)
	bump(self, "Quilts", nil)
end

function Goals.onTarp(self)
	bump(self, "Tarps", nil)
end

function Goals.onStatue(self)
	bump(self, "Statues", nil)
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

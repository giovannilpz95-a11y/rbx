--[[
	Crop Pop board: the grid, pieces, obstacles, gravity, refills and shuffles.

	Coordinates are (x, y) with x = 1 on the left and y = 1 at the top.
	A missing cell (`board.cells[y][x] == nil`) is a hole in the level shape.
	Pieces fall straight down through holes, stop on hay bales and weeds, and
	slide in diagonally to fill cells that nothing can reach from above.
	Frosted tiles stay put: they can't be swapped and don't fall, but they
	still match.
	Pumpkins are pieces that never match and can't be blasted: they fall and
	swap like tiles, and the engine collects them from the bottom cell of a
	column. Refills drop new ones while `pumpkinsToSpawn` is above 0.
	Clover grows on cells (under whatever is there); the engine spreads it.
	Portals link a cell to another anywhere on the board: pieces leaving the
	entrance fall into the exit instead of the cell below. An exit is fed only
	by its portal (nothing falls into it from above, and no tile spawns there),
	and the cell under an entrance gets pieces only by sliding in diagonally.
	Fences sit on the edge between two cells: nothing swaps across one, but
	matches and falling pieces pass it. Only blasts break them. Hedges are
	fences that nothing breaks (side "R" or "D" in a level's fences list).
	Hen houses ("h") are not cells either, but nothing falls past one: the
	column above stops on it, and the cell below gets a fresh tile from it
	whenever it's empty: every other one is an Egg (so eggs never stack
	into an endless match), the rest are random like the top of the board.
	Pumpkin baskets ("d") are not cells: pieces fall past them like a hole.
	Goo springs ("G") are not cells either (pieces fall past them), and
	nothing breaks them: the engine spreads goo out of them.
	The engine counts hits on them and drops pumpkins out of them.

	Everything here is deterministic: loops run in row/column order and all
	randomness comes from the Rng passed in.
]]

local Matcher = require(script.Parent.Matcher)
local EGG = require(script.Parent.Tiles).ByName.Egg -- what hen houses lay

local Board = {}
Board.__index = Board

export type Piece = {
	id: number,
	color: number, -- 1..6, 0 for a Sunflower or a pumpkin
	power: string?, -- see Tiles.Power
	pumpkin: boolean?,
	timer: number?, -- a snowball: swaps left before it bursts and frosts the tiles around it
}

export type Cell = {
	x: number,
	y: number,
	piece: Piece?,
	bale: number, -- hay bale layers left (0 = no bale); a bale cell holds no piece
	weed: boolean, -- the "bale" is a weed (always 1 layer; weeds spread)
	stone: boolean, -- the "bale" is a stone wall (only blasts break it, not matches next to it)
	tarp: any?, -- the "bale" is part of a tarp ({ cells, left }), rolled up from its right end
	crate: boolean?, -- the "bale" is a surprise crate (opens like a 1-layer bale and reveals something)
	tin: boolean?, -- the "bale" is a sewing tin (opens like a 1-layer bale and sends a patch to a quilt)
	quilt: any?, -- the "bale" is part of a quilt ({ cells, left }); nothing breaks it, patches finish it
	patched: boolean?, -- this quilt cell has its patch
	mailbox: any?, -- the "bale" is a mailbox: { mail = holds a letter?, open = opened yet? }
	scarecrow: number?, -- the "bale" is a scarecrow: charges so far (it never breaks)
	sack: boolean?, -- the "bale" is a seed sack: it never breaks, and hits sow clover near it
	bucket: boolean?, -- the "bale" is a mud bucket: one hit tips it, spilling mud around it
	hive: boolean?, -- the "bale" is a beehive: it never breaks, and each hit sends a honey jar to the goal
	stack: boolean?, -- the "bale" is a stack of produce boxes: each hit takes one, and the rest hop
	mud: number, -- mud layers under the tile (0 = none)
	clay: number?, -- clay under the tile: 2 = glazed (only a blast cracks it), 1 = cracked (any clear)
	frost: number, -- frost layers over the tile (0 = none); the tile is frozen in place
	clover: boolean, -- clover grows here (it spreads from matches and blasts that start on it)
	goo: boolean?, -- goo covers the tile here (a match or blast on it clears it; it spreads)
	thickGoo: boolean?, -- the goo is thick: the first clear leaves plain goo
	web: boolean?, -- a web over the tile: it can't move or match; only a blast clears the web
	rainbow: boolean?, -- a rainbow patch: the plain tile here changes colour after every swap
	buried: boolean?, -- part of a buried statue lies under this cell (only blasts dig it up)
	statue: any?, -- the statue this cell is (or was) part of: { cells, left }
	portalOut: Cell?, -- a portal entrance: pieces falling out of here land in this cell
	portalIn: Cell?, -- a portal exit: the entrance that feeds it
}

export type Move = { id: number, fromX: number, fromY: number, toX: number, toY: number }
export type Spawn = { piece: Piece, fromX: number, fromY: number, toX: number, toY: number }

local MAX_SHUFFLE_TRIES = 100

function Board.new(width: number, height: number)
	local self = setmetatable({
		width = width,
		height = height,
		cells = {},
		nextId = 1,
		startPumpkins = {}, -- cells that start with a pumpkin ("p" in the layout)
		startSnowballs = {}, -- cells that start with a snowball ("i" in the layout), in reading order
		pumpkinsToSpawn = 0, -- set by the engine before each refill
		-- Pumpkin baskets ("d" in the layout): { x, y, waiting } in row order;
		-- waiting = pumpkins hit loose that haven't found a cell yet.
		baskets = {},
		basketAt = {}, -- y * 100 + x -> basket
		hens = {}, -- hen houses ("h" in the layout): { x, y } in row order
		henAt = {}, -- y * 100 + x -> hen house
		springs = {}, -- goo springs ("G" in the layout): { x, y } in row order
		springAt = {}, -- y * 100 + x -> goo spring
		fences = {}, -- edge key -> { x, y, side = "r" | "d", hedge? } (the edge right of / below (x, y))
		fenceCount = 0, -- fences that can break (not hedges)
		edgeCount = 0, -- fences and hedges
		-- Buried statues ("b" in the layout; touching "b" cells make one statue):
		-- { cells = { Cell }, left = cells still buried } in reading order.
		statues = {},
		-- Tarps ("t" in the layout; touching t cells in a row make one tarp):
		-- { cells = { Cell } left to right, left = cells still covered }.
		tarps = {},
		-- Quilts ("q" in the layout; touching q cells make one quilt):
		-- { cells = { Cell } in reading order, left = patches still missing }.
		quilts = {},
	}, Board)
	for y = 1, height do
		self.cells[y] = {}
	end
	return self
end

-- Builds an empty board from level layout rows (see Levels.luau for the
-- characters) and the level's portals ({ from = { x, y }, to = { x, y } }).
local function edgeKey(x1: number, y1: number, x2: number, y2: number): number
	if x2 < x1 or y2 < y1 then
		x1, y1, x2, y2 = x2, y2, x1, y1
	end
	return (y1 * 100 + x1) * 2 + (if y2 > y1 then 1 else 0)
end

-- The fence between two neighbouring cells, if there is one.
function Board.fenceBetween(self, x1: number, y1: number, x2: number, y2: number)
	if self.edgeCount == 0 then
		return nil
	end
	return self.fences[edgeKey(x1, y1, x2, y2)]
end

-- Removes a fence; returns true if it was there. Hedges never break.
function Board.breakFence(self, fence): boolean
	if fence.hedge then
		return false
	end
	local key = edgeKey(fence.x, fence.y, fence.x + (if fence.side == "r" then 1 else 0), fence.y + (if fence.side == "d" then 1 else 0))
	if self.fences[key] then
		self.fences[key] = nil
		self.fenceCount -= 1
		self.edgeCount -= 1
		return true
	end
	return false
end

-- Fences (not hedges) on the four edges of (x, y), in a fixed order.
function Board.fencesAround(self, x: number, y: number)
	local out = {}
	if self.fenceCount == 0 then
		return out
	end
	for _, d in { { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } } do
		local fence = self.fences[edgeKey(x, y, x + d[1], y + d[2])]
		if fence and not fence.hedge then
			table.insert(out, fence)
		end
	end
	return out
end

function Board.fromLayout(layout: { string }, portals: { any }?, fences: { any }?)
	local height = #layout
	local width = #layout[1]
	local self = Board.new(width, height)
	for y, row in layout do
		for x = 1, width do
			local ch = string.sub(row, x, x)
			if ch == "h" then
				local hen = { x = x, y = y, laid = 0 }
				table.insert(self.hens, hen)
				self.henAt[y * 100 + x] = hen
			elseif ch == "G" then
				local spring = { x = x, y = y }
				table.insert(self.springs, spring)
				self.springAt[y * 100 + x] = spring
			elseif ch == "d" then
				local basket = { x = x, y = y, waiting = 0 }
				table.insert(self.baskets, basket)
				self.basketAt[y * 100 + x] = basket
			elseif ch ~= "#" then
				local cell: Cell = { x = x, y = y, piece = nil, bale = 0, weed = false, stone = false, mud = 0, frost = 0, clover = false }
				if ch == "m" then
					cell.mud = 1
				elseif ch == "M" then
					cell.mud = 2
				elseif ch == "a" then
					cell.clay = 2
				elseif ch == "A" then
					cell.clay = 1
				elseif ch == "f" then
					cell.frost = 1
				elseif ch == "F" then
					cell.frost = 2
				elseif ch == "w" then
					cell.bale = 1
					cell.weed = true
				elseif ch == "1" or ch == "2" or ch == "3" then
					cell.bale = tonumber(ch) :: number
				elseif ch == "p" then
					self.startPumpkins[cell] = true
				elseif ch == "i" then
					table.insert(self.startSnowballs, cell)
				elseif ch == "c" then
					cell.clover = true
				elseif ch == "g" then
					cell.goo = true
				elseif ch == "n" then
					cell.web = true
				elseif ch == "r" then
					cell.rainbow = true
					self.hasRainbow = true
				elseif ch == "e" then
					cell.goo = true
					cell.thickGoo = true
				elseif ch == "b" then
					cell.buried = true
				elseif ch == "t" then
					cell.bale = 1
					cell.tarp = true -- replaced by its tarp below
				elseif ch == "x" then
					cell.bale = 1
					cell.crate = true
				elseif ch == "l" or ch == "L" then
					cell.bale = 2 -- one hit opens it, the next takes it away
					cell.mailbox = { mail = ch == "l", open = false }
				elseif ch == "y" then
					cell.bale = 1
					cell.scarecrow = 0
				elseif ch == "u" then
					cell.bale = 1
					cell.bucket = true
				elseif ch == "j" then
					cell.bale = 1
					cell.hive = true
				elseif ch == "v" or ch == "V" then
					cell.bale = if ch == "v" then 3 else 2
					cell.stack = true
				elseif ch == "z" then
					cell.bale = 1
					cell.sack = true
				elseif ch == "k" then
					cell.bale = 1
					cell.tin = true
				elseif ch == "q" then
					cell.bale = 1
					cell.quilt = true -- replaced by its quilt below
				elseif ch == "s" or ch == "S" then
					cell.bale = if ch == "S" then 2 else 1
					cell.stone = true
				end
				self.cells[y][x] = cell
			end
		end
	end
	-- Touching tarp cells in a row make up one tarp.
	for y = 1, height do
		local tarp = nil
		for x = 1, width do
			local cell = self.cells[y][x]
			if cell and cell.tarp == true then
				if not tarp then
					tarp = { cells = {}, left = 0 }
					table.insert(self.tarps, tarp)
				end
				cell.tarp = tarp
				table.insert(tarp.cells, cell)
				tarp.left += 1
			else
				tarp = nil
			end
		end
	end
	-- Touching buried cells (up, down, left, right) make up one statue, and
	-- touching quilt cells one quilt.
	local function group(isPart, field, list)
		self:eachCell(function(cell)
			if isPart(cell) and cell[field] == nil then
				local whole = { cells = {}, left = 0 }
				local stack = { cell }
				cell[field] = whole
				while #stack > 0 do
					local c = table.remove(stack)
					table.insert(whole.cells, c)
					whole.left += 1
					for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local n = self:get(c.x + d[1], c.y + d[2])
						if n and isPart(n) and n[field] == nil then
							n[field] = whole
							table.insert(stack, n)
						end
					end
				end
				table.sort(whole.cells, function(a, b)
					return a.y * 100 + a.x < b.y * 100 + b.x
				end)
				table.insert(list, whole)
			end
		end)
	end
	group(function(cell)
		return cell.buried == true
	end, "statue", self.statues)
	local quiltCells = {}
	self:eachCell(function(cell)
		if cell.quilt == true then
			cell.quilt = nil
			quiltCells[cell] = true
		end
	end)
	if next(quiltCells) then
		group(function(cell)
			return quiltCells[cell] == true
		end, "quilt", self.quilts)
	end
	for _, portal in portals or {} do
		local from = self:get(portal.from[1], portal.from[2])
		local to = self:get(portal.to[1], portal.to[2])
		if from and to then
			from.portalOut = to
			to.portalIn = from
		end
	end
	for _, f in fences or {} do
		-- "R" and "D" are hedges: fences that nothing breaks.
		local x, y, side = f[1], f[2], string.lower(f[3])
		local hedge = f[3] ~= side
		local key = edgeKey(x, y, x + (if side == "r" then 1 else 0), y + (if side == "d" then 1 else 0))
		if not self.fences[key] then
			self.fences[key] = { x = x, y = y, side = side, hedge = if hedge then true else nil }
			self.edgeCount += 1
			if not hedge then
				self.fenceCount += 1
			end
		end
	end
	return self
end

-- The pumpkin basket at (x, y), if there is one.
function Board.basket(self, x: number, y: number)
	return self.basketAt[y * 100 + x]
end

function Board.get(self, x: number, y: number): Cell?
	local row = self.cells[y]
	return row and row[x]
end

function Board.newPiece(self, color: number, power: string?): Piece
	local piece = { id = self.nextId, color = color, power = power }
	self.nextId += 1
	return piece
end

function Board.newPumpkin(self): Piece
	local piece = self:newPiece(0)
	piece.pumpkin = true
	return piece
end

-- Calls fn(cell) for every cell in row-major order.
function Board.eachCell(self, fn: (Cell) -> ())
	for y = 1, self.height do
		local row = self.cells[y]
		for x = 1, self.width do
			local cell = row[x]
			if cell then
				fn(cell)
			end
		end
	end
end

-- A piece the player can swap (and that gravity and shuffles can move).
function Board.isMovable(cell: Cell?): boolean
	return cell ~= nil and cell.piece ~= nil and cell.bale == 0 and cell.frost == 0 and not cell.web
end

-- A movable plain tile: no power-up, not a pumpkin (power-ups and weeds can land on it).
function Board.isPlainTile(cell: Cell?): boolean
	return Board.isMovable(cell) and (cell :: Cell).piece.power == nil and not (cell :: Cell).piece.pumpkin
end

-- The cell pumpkins leave from: the lowest one in its column (and not a portal entrance).
function Board.isExit(self, cell: Cell): boolean
	if cell.portalOut then
		return false
	end
	for yy = cell.y + 1, self.height do
		if self.henAt[yy * 100 + cell.x] then
			return true -- a hen house below closes the column
		end
		if self.cells[yy][cell.x] then
			return false
		end
	end
	return true
end

function Board.isEmptySlot(cell: Cell?): boolean
	return cell ~= nil and cell.piece == nil and cell.bale == 0
end

-- Where a piece at (x, y) falls next: through its portal, else the next
-- existing cell below (skipping holes), unless that one is another portal's exit.
function Board.cellBelow(self, x: number, y: number): Cell?
	local here = self:get(x, y)
	if here and here.portalOut then
		return here.portalOut
	end
	for yy = y + 1, self.height do
		if self.henAt[yy * 100 + x] then
			return nil -- nothing falls past a hen house
		end
		local cell = self.cells[yy][x]
		if cell then
			if cell.portalIn and cell.portalIn ~= here then
				return nil
			end
			return cell
		end
	end
	return nil
end

-- The cell that feeds (x, y): its portal entrance, else the next existing
-- cell above, unless that one falls into a portal instead.
function Board.cellAbove(self, x: number, y: number): Cell?
	local here = self:get(x, y)
	if here and here.portalIn then
		return here.portalIn
	end
	for yy = y - 1, 1, -1 do
		if self.henAt[yy * 100 + x] then
			return nil -- fed by the hen house instead
		end
		local cell = self.cells[yy][x]
		if cell then
			if cell.portalOut and cell.portalOut ~= here then
				return nil
			end
			return cell
		end
	end
	return nil
end

-- Picks a colour for (x, y) that doesn't complete a line of 3 or a 2x2 square
-- with the cells to the left and above (used when filling a fresh board).
local function pickCalmColor(self, x: number, y: number, rng, colors: { number }): number
	local function colorAt(cx, cy)
		local cell = self:get(cx, cy)
		local piece = cell and cell.piece
		return if piece and cell.bale == 0 then piece.color else 0
	end
	local allowed = {}
	for _, c in colors do
		local makesRow = colorAt(x - 1, y) == c and colorAt(x - 2, y) == c
		local makesColumn = colorAt(x, y - 1) == c and colorAt(x, y - 2) == c
		local makesSquare = colorAt(x - 1, y) == c and colorAt(x, y - 1) == c and colorAt(x - 1, y - 1) == c
		if not (makesRow or makesColumn or makesSquare) then
			table.insert(allowed, c)
		end
	end
	if #allowed == 0 then
		return rng:pick(colors)
	end
	return rng:pick(allowed)
end

-- Fills every empty slot with no ready-made matches and at least one possible move.
function Board.fillInitial(self, rng, colors: { number })
	for _ = 1, MAX_SHUFFLE_TRIES do
		self:eachCell(function(cell)
			if self.startPumpkins[cell] then
				cell.piece = self:newPumpkin()
			elseif cell.bale == 0 then
				cell.piece = self:newPiece(pickCalmColor(self, cell.x, cell.y, rng, colors))
			end
		end)
		if #Matcher.findGroups(self, {}) == 0 and Matcher.hasPossibleMove(self) then
			return
		end
	end
	-- Extremely cramped layouts: accept whatever we have, the engine will shuffle.
end

--[[
	Drops pieces into empty slots and spawns new ones at the top of each column.
	Returns the moves of existing pieces and the new pieces, each with a start
	and end position so the view can tween them. Spawned pieces start above
	their column's top cell (negative or zero y is fine).
]]
function Board.applyGravity(self, rng, colors: { number }): ({ Move }, { Spawn })
	local tracks = {} -- piece id -> record
	local order = {} -- piece ids in first-moved order
	local spawnCounts = {} -- column -> pieces spawned so far

	local function moveTo(piece: Piece, fromCell: Cell, toCell: Cell)
		local record = tracks[piece.id]
		if not record then
			record = { id = piece.id, fromX = fromCell.x, fromY = fromCell.y }
			tracks[piece.id] = record
			table.insert(order, piece.id)
		end
		record.toX = toCell.x
		record.toY = toCell.y
		fromCell.piece = nil
		toCell.piece = piece
	end

	local function fallStraight(): boolean
		local movedAny = false
		repeat
			local moved = false
			-- From the bottom row too: a portal entrance there still has somewhere to go.
			for y = self.height, 1, -1 do
				local row = self.cells[y]
				for x = 1, self.width do
					local cell = row[x]
					if Board.isMovable(cell) then
						local below = self:cellBelow(x, y)
						if below and Board.isEmptySlot(below) then
							moveTo(cell.piece :: Piece, cell, below)
							moved = true
						end
					end
				end
			end
			movedAny = movedAny or moved
		until not moved
		return movedAny
	end

	local function spawnTops(): boolean
		local spawned = false
		for x = 1, self.width do
			local top = nil
			for y = 1, self.height do
				if self.henAt[y * 100 + x] then
					break -- a hen house feeds the cells under it
				end
				if self.cells[y][x] then
					top = self.cells[y][x]
					break
				end
			end
			if top and top.portalIn == nil and Board.isEmptySlot(top) then
				local count = (spawnCounts[x] or 0) + 1
				spawnCounts[x] = count
				local piece
				-- Each refill tile has an even chance of being a waiting pumpkin.
				if self.pumpkinsToSpawn > 0 and rng:int(1, 2) == 1 then
					self.pumpkinsToSpawn -= 1
					piece = self:newPumpkin()
				else
					piece = self:newPiece(rng:pick(colors))
				end
				top.piece = piece
				tracks[piece.id] = {
					id = piece.id,
					spawned = piece,
					fromX = x,
					fromY = top.y - count,
					toX = x,
					toY = top.y,
				}
				table.insert(order, piece.id)
				spawned = true
			end
		end
		-- Hen houses lay an Egg into the first cell below them when it's empty.
		for _, hen in self.hens do
			local target = nil
			for y = hen.y + 1, self.height do
				if self.henAt[y * 100 + hen.x] then
					break
				end
				if self.cells[y][hen.x] then
					target = self.cells[y][hen.x]
					break
				end
			end
			if target and target.portalIn == nil and Board.isEmptySlot(target) then
				local key = -(hen.y * 100 + hen.x)
				local count = (spawnCounts[key] or 0) + 1
				spawnCounts[key] = count
				local piece = self:newPiece(if hen.laid % 2 == 0 then EGG else rng:pick(colors))
				hen.laid += 1
				target.piece = piece
				tracks[piece.id] = {
					id = piece.id,
					spawned = piece,
					fromX = hen.x,
					fromY = math.max(hen.y, target.y - count),
					toX = hen.x,
					toY = target.y,
				}
				table.insert(order, piece.id)
				spawned = true
			end
		end
		return spawned
	end

	-- One diagonal slide into an empty slot that nothing above can fill.
	local function slideDiagonal(): boolean
		for y = self.height, 2, -1 do
			for x = 1, self.width do
				local cell = self.cells[y][x]
				if Board.isEmptySlot(cell) then
					for _, dx in { -1, 1 } do
						local source = self:get(x + dx, y - 1)
						if Board.isMovable(source) then
							local sourceBelow = self:cellBelow(x + dx, y - 1)
							-- Only take a piece that isn't about to fall straight itself.
							if not Board.isEmptySlot(sourceBelow) then
								moveTo((source :: Cell).piece :: Piece, source :: Cell, cell :: Cell)
								return true
							end
						end
					end
				end
			end
		end
		return false
	end

	local guard = 0
	repeat
		guard += 1
		local changed = fallStraight()
		if spawnTops() then
			changed = true
		end
		if not changed then
			changed = slideDiagonal()
		end
	until not changed or guard > 10000

	local moves: { Move } = {}
	local spawns: { Spawn } = {}
	for _, id in order do
		local record = tracks[id]
		if record.spawned then
			table.insert(spawns, {
				piece = record.spawned,
				fromX = record.fromX,
				fromY = record.fromY,
				toX = record.toX,
				toY = record.toY,
			})
		elseif record.fromX ~= record.toX or record.fromY ~= record.toY then
			table.insert(moves, {
				id = id,
				fromX = record.fromX,
				fromY = record.fromY,
				toX = record.toX,
				toY = record.toY,
			})
		end
	end
	return moves, spawns
end

--[[
	Shuffles every movable piece until the board has no ready-made matches and
	at least one possible move. Pumpkins stay where they are. Returns the new
	position of each piece.
]]
function Board.shuffle(self, rng, colors: { number }): { Move }
	local slots: { Cell } = {}
	local pieces: { Piece } = {}
	local origin = {}
	self:eachCell(function(cell)
		if Board.isMovable(cell) and not cell.piece.pumpkin then
			table.insert(slots, cell)
			table.insert(pieces, cell.piece :: Piece)
			origin[(cell.piece :: Piece).id] = cell
		end
	end)

	local function place()
		for i, cell in slots do
			cell.piece = pieces[i]
		end
	end

	local ok = false
	for _ = 1, MAX_SHUFFLE_TRIES do
		rng:shuffle(pieces)
		place()
		if #Matcher.findGroups(self, {}) == 0 and Matcher.hasPossibleMove(self) then
			ok = true
			break
		end
	end
	if not ok then
		-- Not enough variety to shuffle into a playable board: recolour plain tiles.
		for _ = 1, MAX_SHUFFLE_TRIES do
			for _, cell in slots do
				local piece = cell.piece :: Piece
				if piece.power == nil then
					piece.color = pickCalmColor(self, cell.x, cell.y, rng, colors)
				end
			end
			if #Matcher.findGroups(self, {}) == 0 and Matcher.hasPossibleMove(self) then
				break
			end
		end
	end

	local moves: { Move } = {}
	for _, cell in slots do
		local piece = cell.piece :: Piece
		local from = origin[piece.id]
		table.insert(moves, { id = piece.id, fromX = from.x, fromY = from.y, toX = cell.x, toY = cell.y })
	end
	return moves
end

-- Compact text form of the board, used to check client/server determinism.
local POWER_CODES = {
	SprayerRow = "r",
	SprayerColumn = "c",
	Bumblebee = "b",
	HayBomb = "h",
	Sunflower = "s",
}

function Board.hash(self): string
	local parts = table.create(self.height)
	for y = 1, self.height do
		local row = {}
		for x = 1, self.width do
			local cell = self.cells[y][x]
			local clover = if cell and cell.clover then "+" else "" -- not "c": that is the column sprayer
			if cell and cell.buried then
				clover ..= "^"
			end
			if cell and cell.rainbow then
				clover ..= "~"
			end
			if cell and cell.web then
				clover ..= "*"
			end
			local basket = self.basketAt[y * 100 + x]
			if self.henAt[y * 100 + x] then
				table.insert(row, "H" .. self.henAt[y * 100 + x].laid % 2)
			elseif basket then
				table.insert(row, "D" .. basket.waiting)
			elseif self.springAt[y * 100 + x] then
				table.insert(row, "G")
			elseif not cell then
				table.insert(row, "#")
			elseif cell.crate then
				table.insert(row, "X" .. clover)
			elseif cell.tin then
				table.insert(row, "K" .. clover)
			elseif cell.sack then
				table.insert(row, "Z" .. clover)
			elseif cell.scarecrow then
				table.insert(row, "Y" .. cell.scarecrow .. clover)
			elseif cell.bucket then
				table.insert(row, "U" .. clover)
			elseif cell.stack then
				table.insert(row, "V" .. cell.bale .. clover)
			elseif cell.hive then
				table.insert(row, "J" .. clover)
			elseif cell.mailbox then
				table.insert(row, "L" .. (if cell.mailbox.mail then "1" else "0") .. (if cell.mailbox.open then "o" else "") .. clover)
			elseif cell.quilt then
				table.insert(row, (if cell.patched then "Qp" else "Q") .. clover)
			elseif cell.tarp then
				table.insert(row, "T" .. clover)
			elseif cell.weed then
				table.insert(row, "W" .. clover)
			elseif cell.bale > 0 then
				table.insert(row, (if cell.stone then "R" else "B") .. cell.bale .. clover)
			else
				local piece = cell.piece
				local code = if piece and piece.pumpkin
					then "P"
					elseif piece then tostring(piece.color) .. (POWER_CODES[piece.power] or "")
					else "_"
				if piece and piece.timer then
					code ..= "i" .. piece.timer
				end
				if cell.mud > 0 then
					code ..= "m" .. cell.mud
				end
				if cell.clay then
					code ..= "a" .. cell.clay
				end
				if cell.frost > 0 then
					code ..= "f" .. cell.frost
				end
				if cell.goo then
					code ..= if cell.thickGoo then "gg" else "g"
				end
				table.insert(row, code .. clover)
			end
		end
		parts[y] = table.concat(row, ",")
	end
	if self.edgeCount > 0 then
		local keys = {}
		for key in self.fences do
			table.insert(keys, key)
		end
		table.sort(keys)
		for i, key in keys do
			if self.fences[key].hedge then
				keys[i] = key .. "h"
			end
		end
		table.insert(parts, "F" .. table.concat(keys, ","))
	end
	return table.concat(parts, "/")
end

-- Plain snapshot for the view: one entry per cell.
function Board.snapshot(self)
	local out = {}
	self:eachCell(function(cell)
		local piece = cell.piece
		table.insert(out, {
			x = cell.x,
			y = cell.y,
			bale = cell.bale,
			weed = cell.weed,
			stone = cell.stone,
			crate = cell.crate,
			tin = cell.tin,
			sack = cell.sack,
			scarecrow = cell.scarecrow,
			bucket = cell.bucket,
			stack = cell.stack,
			hive = cell.hive,
			-- What's inside shows only once it's open.
			mailbox = cell.mailbox and { open = cell.mailbox.open, mail = cell.mailbox.open and cell.mailbox.mail },
			quilt = cell.quilt ~= nil,
			patched = cell.patched,
			tarp = cell.tarp ~= nil,
			mud = cell.mud,
			clay = cell.clay,
			frost = cell.frost,
			clover = cell.clover,
			goo = cell.goo,
			thickGoo = cell.thickGoo,
			rainbow = cell.rainbow,
			web = cell.web,
			buried = cell.buried,
			piece = piece and { id = piece.id, color = piece.color, power = piece.power, pumpkin = piece.pumpkin, timer = piece.timer },
		})
	end)
	return out
end

return Board

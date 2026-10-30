--[[
	Crop Pop board: the grid, pieces, obstacles, gravity, refills and shuffles.

	Coordinates are (x, y) with x = 1 on the left and y = 1 at the top.
	A missing cell (`board.cells[y][x] == nil`) is a hole in the level shape.
	Pieces fall straight down through holes, stop on hay bales and weeds, and
	slide in diagonally to fill cells that nothing can reach from above.
	Frosted tiles stay put: they can't be swapped and don't fall, but they
	still match.

	Everything here is deterministic: loops run in row/column order and all
	randomness comes from the Rng passed in.
]]

local Matcher = require(script.Parent.Matcher)

local Board = {}
Board.__index = Board

export type Piece = {
	id: number,
	color: number, -- 1..6, 0 for a Sunflower
	power: string?, -- see Tiles.Power
}

export type Cell = {
	x: number,
	y: number,
	piece: Piece?,
	bale: number, -- hay bale layers left (0 = no bale); a bale cell holds no piece
	weed: boolean, -- the "bale" is a weed (always 1 layer; weeds spread)
	mud: number, -- mud layers under the tile (0 = none)
	frost: number, -- frost layers over the tile (0 = none); the tile is frozen in place
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
	}, Board)
	for y = 1, height do
		self.cells[y] = {}
	end
	return self
end

-- Builds an empty board from level layout rows (see Levels.luau for the characters).
function Board.fromLayout(layout: { string })
	local height = #layout
	local width = #layout[1]
	local self = Board.new(width, height)
	for y, row in layout do
		for x = 1, width do
			local ch = string.sub(row, x, x)
			if ch ~= "#" then
				local cell: Cell = { x = x, y = y, piece = nil, bale = 0, weed = false, mud = 0, frost = 0 }
				if ch == "m" then
					cell.mud = 1
				elseif ch == "M" then
					cell.mud = 2
				elseif ch == "f" then
					cell.frost = 1
				elseif ch == "F" then
					cell.frost = 2
				elseif ch == "w" then
					cell.bale = 1
					cell.weed = true
				elseif ch == "1" or ch == "2" or ch == "3" then
					cell.bale = tonumber(ch) :: number
				end
				self.cells[y][x] = cell
			end
		end
	end
	return self
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
	return cell ~= nil and cell.piece ~= nil and cell.bale == 0 and cell.frost == 0
end

function Board.isEmptySlot(cell: Cell?): boolean
	return cell ~= nil and cell.piece == nil and cell.bale == 0
end

-- Next existing cell below (x, y), skipping holes.
function Board.cellBelow(self, x: number, y: number): Cell?
	for yy = y + 1, self.height do
		local cell = self.cells[yy][x]
		if cell then
			return cell
		end
	end
	return nil
end

-- Next existing cell above (x, y), skipping holes.
function Board.cellAbove(self, x: number, y: number): Cell?
	for yy = y - 1, 1, -1 do
		local cell = self.cells[yy][x]
		if cell then
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
			if cell.bale == 0 then
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
			for y = self.height - 1, 1, -1 do
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
				if self.cells[y][x] then
					top = self.cells[y][x]
					break
				end
			end
			if top and Board.isEmptySlot(top) then
				local count = (spawnCounts[x] or 0) + 1
				spawnCounts[x] = count
				local piece = self:newPiece(rng:pick(colors))
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
	at least one possible move. Returns the new position of each piece.
]]
function Board.shuffle(self, rng, colors: { number }): { Move }
	local slots: { Cell } = {}
	local pieces: { Piece } = {}
	local origin = {}
	self:eachCell(function(cell)
		if Board.isMovable(cell) then
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
			if not cell then
				table.insert(row, "#")
			elseif cell.weed then
				table.insert(row, "W")
			elseif cell.bale > 0 then
				table.insert(row, "B" .. cell.bale)
			else
				local piece = cell.piece
				local code = if piece then tostring(piece.color) .. (POWER_CODES[piece.power] or "") else "_"
				if cell.mud > 0 then
					code ..= "m" .. cell.mud
				end
				if cell.frost > 0 then
					code ..= "f" .. cell.frost
				end
				table.insert(row, code)
			end
		end
		parts[y] = table.concat(row, ",")
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
			mud = cell.mud,
			frost = cell.frost,
			piece = piece and { id = piece.id, color = piece.color, power = piece.power },
		})
	end)
	return out
end

return Board

--[[
	Crop Pop engine: one level being played.

		local game = Engine.new(levelDef, seed)
		local ok, phases = game:trySwap(3, 4, 4, 4)

	`trySwap` applies the move and every cascade it causes, and returns the
	steps as a list of phases for the view to animate, in order:

	  { kind = "Swap", from = {x, y}, to = {x, y}, ok = boolean, combo = boolean? }
	  { kind = "Pop", removed = {{id, x, y, cause}}, created = {{piece, x, y}},
	    transformed = {{id, power}}, bales = {{x, y, hp}}, mud = {{x, y, layers}},
	    effects = {{type = "Spray" | "Bomb" | "Bee" | "Sun" | "Everything", ...}} }
	  { kind = "Drop", moves = {Board.Move}, spawns = {Board.Spawn} }
	  { kind = "Shuffle", moves = {Board.Move} }

	A winning move with moves left over also plays the bonus round: a Pop phase
	(with `bonus = { moves, coins }`) where leftover moves become Seed Sprayers.

	The same level, seed, options and swaps always give the same result, which is
	what lets the server replay a client's run (see Replay.luau).
]]

local Board = require(script.Parent.Board)
local Boosters = require(script.Parent.Boosters)
local Goals = require(script.Parent.Goals)
local Matcher = require(script.Parent.Matcher)
local Rng = require(script.Parent.Rng)
local Tiles = require(script.Parent.Tiles)

local Power = Tiles.Power

-- First-pass tuning (no Township equivalent).
local BOMB_RADIUS = 2 -- Hay Bomb clears every cell within this many steps (diamond)
local BIG_BOMB_RADIUS = 4 -- Hay Bomb + Hay Bomb
local MAX_CASCADES = 100
local BONUS_COINS_PER_MOVE = 2 -- leftover moves when a level is won

local NEIGHBORS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local Engine = {}
Engine.__index = Engine

export type Options = {
	-- Power-ups placed on random tiles at the start (pre-level boosters, Hot Streak).
	startPowerUps: { string }?,
}

function Engine.new(level, seed: number, options: Options?)
	local board = Board.fromLayout(level.layout)
	local colors = {}
	for _, name in level.colors do
		table.insert(colors, Tiles.ByName[name])
	end
	local rng = Rng.new(seed)
	board:fillInitial(rng, colors)

	local self = setmetatable({
		level = level,
		seed = seed,
		board = board,
		rng = rng,
		colors = colors,
		goals = Goals.new(level.goals, board),
		movesLeft = level.moves,
		movesMade = 0,
		status = "Playing", -- "Playing" | "Won" | "Lost"
		stats = { powerUpsMade = 0, combos = 0, cascades = 0 },
		boostersUsed = {}, -- in-level booster kind -> times used
	}, Engine)

	if options and options.startPowerUps then
		self:_placeStartPowerUps(options.startPowerUps)
	end
	return self
end

function Engine._placeStartPowerUps(self, powers: { string })
	local candidates = {}
	self.board:eachCell(function(cell)
		if Board.isMovable(cell) and cell.piece.power == nil then
			table.insert(candidates, cell)
		end
	end)
	for _, power in powers do
		if #candidates == 0 then
			break
		end
		local cell = table.remove(candidates, self.rng:int(1, #candidates))
		if power == "Sprayer" then
			power = if self.rng:int(1, 2) == 1 then Power.SprayerRow else Power.SprayerColumn
		end
		cell.piece.power = power
		if power == Power.Sunflower then
			cell.piece.color = 0
		end
	end
	if not Matcher.hasPossibleMove(self.board) then
		self.board:shuffle(self.rng, self.colors)
	end
end

-- Waves ---------------------------------------------------------------------
-- A wave is one "pop" step: matched tiles, power-ups going off, obstacles hit.

local function newWave()
	return {
		removed = {},
		created = {},
		transformed = {},
		bales = {},
		mud = {},
		effects = {},
		queue = {}, -- power-ups waiting to go off
		pendingCreates = {},
		balesTouched = {}, -- bales already hit by a neighbouring match this wave
	}
end

function Engine._removePiece(self, wave, cell, cause: string, noActivate: boolean?)
	local piece = cell.piece
	if not piece then
		return
	end
	cell.piece = nil
	table.insert(wave.removed, { id = piece.id, x = cell.x, y = cell.y, cause = cause })
	self.goals:onCollect(piece.color)
	if cell.mud > 0 then
		cell.mud -= 1
		table.insert(wave.mud, { x = cell.x, y = cell.y, layers = cell.mud })
		self.goals:onMud()
	end
	if piece.power and not noActivate then
		table.insert(wave.queue, { power = piece.power, x = cell.x, y = cell.y, color = piece.color })
	end
end

function Engine._damageBale(self, wave, cell)
	cell.bale -= 1
	table.insert(wave.bales, { x = cell.x, y = cell.y, hp = cell.bale })
	if cell.bale == 0 then
		self.goals:onBale()
	end
end

-- A power-up blast reaching (x, y).
function Engine._hit(self, wave, x: number, y: number)
	local cell = self.board:get(x, y)
	if not cell then
		return
	end
	if cell.bale > 0 then
		self:_damageBale(wave, cell)
	elseif cell.piece then
		self:_removePiece(wave, cell, "power")
	end
end

function Engine._popGroups(self, wave, groups)
	local board = self.board
	for _, group in groups do
		for _, cell in group.cells do
			self:_removePiece(wave, cell, "match")
		end
		-- Matches next to a hay bale knock off one layer (once per bale per wave).
		for _, cell in group.cells do
			for _, d in NEIGHBORS do
				local n = board:get(cell.x + d[1], cell.y + d[2])
				if n and n.bale > 0 and not wave.balesTouched[n] then
					wave.balesTouched[n] = true
					self:_damageBale(wave, n)
				end
			end
		end
		if group.power then
			table.insert(wave.pendingCreates, {
				power = group.power,
				color = if group.power == Power.Sunflower then 0 else group.color,
				cell = group.at,
			})
			self.stats.powerUpsMade += 1
		end
	end
end

function Engine._mostCommonColor(self): number?
	local counts = {}
	self.board:eachCell(function(cell)
		local piece = cell.piece
		if piece and piece.color > 0 then
			counts[piece.color] = (counts[piece.color] or 0) + 1
		end
	end)
	local best, bestCount = nil, 0
	for color = 1, Tiles.Count do
		local n = counts[color] or 0
		if n > bestCount then
			best, bestCount = color, n
		end
	end
	return best
end

-- Bumblebees go for what the level needs: hay bales, then mud, then goal tiles.
function Engine._chooseBeeTarget(self)
	local goals = self.goals
	local tiers = { {}, {}, {}, {} }
	self.board:eachCell(function(cell)
		if cell.bale > 0 then
			table.insert(if goals:wants("HayBale") then tiers[1] else tiers[4], cell)
		elseif cell.piece then
			if cell.mud > 0 and goals:wants("Mud") then
				table.insert(tiers[2], cell)
			elseif goals:wants("Collect", cell.piece.color) then
				table.insert(tiers[3], cell)
			else
				table.insert(tiers[4], cell)
			end
		end
	end)
	for _, tier in tiers do
		if #tier > 0 then
			return self.rng:pick(tier)
		end
	end
	return nil
end

function Engine._activate(self, wave, act)
	local board = self.board
	local power = act.power
	if power == Power.SprayerRow then
		table.insert(wave.effects, { type = "Spray", dir = "Row", x = act.x, y = act.y })
		for x = 1, board.width do
			self:_hit(wave, x, act.y)
		end
	elseif power == Power.SprayerColumn then
		table.insert(wave.effects, { type = "Spray", dir = "Column", x = act.x, y = act.y })
		for y = 1, board.height do
			self:_hit(wave, act.x, y)
		end
	elseif power == Power.HayBomb then
		local r = act.radius or BOMB_RADIUS
		table.insert(wave.effects, { type = "Bomb", x = act.x, y = act.y, radius = r })
		for dy = -r, r do
			for dx = -r, r do
				if math.abs(dx) + math.abs(dy) <= r then
					self:_hit(wave, act.x + dx, act.y + dy)
				end
			end
		end
	elseif power == Power.Sunflower then
		local color = act.color
		if color == nil or color == 0 then
			color = self:_mostCommonColor()
		end
		table.insert(wave.effects, { type = "Sun", x = act.x, y = act.y, color = color })
		if color then
			board:eachCell(function(cell)
				if cell.piece and cell.bale == 0 and cell.piece.color == color then
					self:_removePiece(wave, cell, "power")
				end
			end)
		end
	elseif power == "Everything" then
		table.insert(wave.effects, { type = "Everything", x = act.x, y = act.y })
		board:eachCell(function(cell)
			self:_hit(wave, cell.x, cell.y)
		end)
	elseif power == Power.Bumblebee then
		if not act.noSplash then
			for _, d in NEIGHBORS do
				self:_hit(wave, act.x + d[1], act.y + d[2])
			end
		end
		local target = self:_chooseBeeTarget()
		if target then
			table.insert(wave.effects, {
				type = "Bee",
				fromX = act.x,
				fromY = act.y,
				toX = target.x,
				toY = target.y,
				payload = act.payload,
			})
			if act.payload then
				table.insert(wave.queue, { power = act.payload, x = target.x, y = target.y })
			else
				self:_hit(wave, target.x, target.y)
			end
		end
	end
end

-- Swapping two power-ups together, or a Sunflower with anything.
function Engine._combo(self, wave, a, b)
	local pa, pb = a.piece, b.piece
	local queue = wave.queue
	local x, y = b.x, b.y

	if pa.power == Power.Sunflower and pb.power == Power.Sunflower then
		self.stats.combos += 1
		self:_removePiece(wave, a, "power", true)
		self:_removePiece(wave, b, "power", true)
		table.insert(queue, { power = "Everything", x = x, y = y })
		return
	end

	if pa.power == Power.Sunflower or pb.power == Power.Sunflower then
		local sunCell, otherCell = a, b
		if pb.power == Power.Sunflower then
			sunCell, otherCell = b, a
		end
		local other = otherCell.piece
		if other.power == nil then
			-- Sunflower + tile: clear every tile of that colour.
			self:_removePiece(wave, sunCell, "power", true)
			table.insert(queue, { power = Power.Sunflower, x = x, y = y, color = other.color })
			return
		end
		-- Sunflower + power-up: every tile of the partner's colour becomes that power-up.
		self.stats.combos += 1
		self:_removePiece(wave, sunCell, "power", true)
		table.insert(wave.effects, { type = "Sun", x = x, y = y, color = other.color })
		local targets = { otherCell }
		self.board:eachCell(function(cell)
			local piece = cell.piece
			if piece and cell.bale == 0 and piece.power == nil and piece.color == other.color then
				if Tiles.isSprayer(other.power) then
					piece.power = if self.rng:int(1, 2) == 1 then Power.SprayerRow else Power.SprayerColumn
				else
					piece.power = other.power
				end
				table.insert(wave.transformed, { id = piece.id, power = piece.power })
				table.insert(targets, cell)
			end
		end)
		for _, cell in targets do
			self:_removePiece(wave, cell, "power")
		end
		return
	end

	-- Two power-ups.
	self.stats.combos += 1
	self:_removePiece(wave, a, "power", true)
	self:_removePiece(wave, b, "power", true)
	local p, q = pa.power, pb.power
	local function has(kind)
		return p == kind or q == kind
	end
	local sprayer = if Tiles.isSprayer(p) then p elseif Tiles.isSprayer(q) then q else nil

	if Tiles.isSprayer(p) and Tiles.isSprayer(q) then
		-- Cross: its row and column.
		table.insert(queue, { power = Power.SprayerRow, x = x, y = y })
		table.insert(queue, { power = Power.SprayerColumn, x = x, y = y })
	elseif sprayer and has(Power.HayBomb) then
		-- Three rows and three columns.
		for d = -1, 1 do
			if y + d >= 1 and y + d <= self.board.height then
				table.insert(queue, { power = Power.SprayerRow, x = x, y = y + d })
			end
			if x + d >= 1 and x + d <= self.board.width then
				table.insert(queue, { power = Power.SprayerColumn, x = x + d, y = y })
			end
		end
	elseif sprayer and has(Power.Bumblebee) then
		table.insert(queue, { power = Power.Bumblebee, x = x, y = y, payload = sprayer })
	elseif p == Power.HayBomb and q == Power.HayBomb then
		table.insert(queue, { power = Power.HayBomb, x = x, y = y, radius = BIG_BOMB_RADIUS })
	elseif has(Power.HayBomb) and has(Power.Bumblebee) then
		table.insert(queue, { power = Power.Bumblebee, x = x, y = y, payload = Power.HayBomb })
	elseif p == Power.Bumblebee and q == Power.Bumblebee then
		table.insert(queue, { power = Power.Bumblebee, x = x, y = y })
		table.insert(queue, { power = Power.Bumblebee, x = x, y = y, noSplash = true })
		table.insert(queue, { power = Power.Bumblebee, x = x, y = y, noSplash = true })
	end
end

-- Runs every queued power-up, places new power-ups and records the Pop phase.
function Engine._finishWave(self, wave, phases)
	local guard = 0
	while #wave.queue > 0 and guard < 10000 do
		guard += 1
		self:_activate(wave, table.remove(wave.queue, 1))
	end
	for _, create in wave.pendingCreates do
		local cell = create.cell
		if Board.isEmptySlot(cell) then
			local piece = self.board:newPiece(create.color, create.power)
			cell.piece = piece
			table.insert(wave.created, {
				piece = { id = piece.id, color = piece.color, power = piece.power },
				x = cell.x,
				y = cell.y,
			})
		end
	end
	table.insert(phases, {
		kind = "Pop",
		removed = wave.removed,
		created = wave.created,
		transformed = wave.transformed,
		bales = wave.bales,
		mud = wave.mud,
		effects = wave.effects,
	})
end

-- Drops, refills and cascades until the board is still, then shuffles if stuck.
function Engine._settle(self, phases)
	local board = self.board
	for _ = 1, MAX_CASCADES do
		local moves, spawns = board:applyGravity(self.rng, self.colors)
		if #moves > 0 or #spawns > 0 then
			table.insert(phases, { kind = "Drop", moves = moves, spawns = spawns })
		end

		-- New power-ups from cascades appear where pieces landed, lowest first.
		local landed = {}
		for _, m in moves do
			table.insert(landed, board:get(m.toX, m.toY))
		end
		for _, s in spawns do
			table.insert(landed, board:get(s.toX, s.toY))
		end
		table.sort(landed, function(c1, c2)
			if c1.y ~= c2.y then
				return c1.y > c2.y
			end
			return c1.x < c2.x
		end)

		local groups = Matcher.findGroups(board, landed)
		if #groups == 0 then
			break
		end
		self.stats.cascades += 1
		local wave = newWave()
		self:_popGroups(wave, groups)
		self:_finishWave(wave, phases)
	end

	if not Matcher.hasPossibleMove(board) then
		table.insert(phases, { kind = "Shuffle", moves = board:shuffle(self.rng, self.colors) })
	end
end

--[[
	Winning with moves left: each leftover move turns a random tile into a
	Seed Sprayer, they all go off, and each pays a few bonus Coins.
]]
function Engine._bonusRound(self, phases)
	local leftover = self.movesLeft
	self.bonus = { moves = leftover, coins = leftover * BONUS_COINS_PER_MOVE }
	self.movesLeft = 0

	local candidates = {}
	self.board:eachCell(function(cell)
		if Board.isMovable(cell) and cell.piece.power == nil then
			table.insert(candidates, cell)
		end
	end)
	local wave = newWave()
	local chosen = {}
	for _ = 1, math.min(leftover, #candidates) do
		local cell = table.remove(candidates, self.rng:int(1, #candidates))
		cell.piece.power = if self.rng:int(1, 2) == 1 then Power.SprayerRow else Power.SprayerColumn
		table.insert(wave.transformed, { id = cell.piece.id, power = cell.piece.power })
		table.insert(chosen, cell)
	end
	for _, cell in chosen do
		self:_removePiece(wave, cell, "bonus")
	end
	self:_finishWave(wave, phases)
	phases[#phases].bonus = self.bonus
	self:_settle(phases)
end

function Engine._updateStatus(self)
	if self.goals:isComplete() then
		self.status = "Won"
	elseif self.movesLeft <= 0 then
		self.status = "Lost"
	end
end

-- Public API -----------------------------------------------------------------

function Engine.canSwap(self, x1: number, y1: number, x2: number, y2: number): boolean
	if self.status ~= "Playing" or math.abs(x1 - x2) + math.abs(y1 - y2) ~= 1 then
		return false
	end
	return Board.isMovable(self.board:get(x1, y1)) and Board.isMovable(self.board:get(x2, y2))
end

--[[
	Tries to swap (x1, y1) with its neighbour (x2, y2). Returns false (and a
	single failed Swap phase when the cells were swappable) if nothing would
	match; no move is used then.
]]
function Engine.trySwap(self, x1: number, y1: number, x2: number, y2: number): (boolean, { any })
	if not self:canSwap(x1, y1, x2, y2) then
		return false, {}
	end
	local board = self.board
	local a, b = board:get(x1, y1), board:get(x2, y2)
	local pa, pb = a.piece, b.piece
	local phases = {}
	local swapPhase = { kind = "Swap", from = { x1, y1 }, to = { x2, y2 }, ok = true }

	local isCombo = (pa.power ~= nil and pb.power ~= nil)
		or pa.power == Power.Sunflower
		or pb.power == Power.Sunflower

	if isCombo then
		swapPhase.combo = true
		table.insert(phases, swapPhase)
		local wave = newWave()
		self:_combo(wave, a, b)
		self:_useMove()
		self:_finishWave(wave, phases)
	else
		a.piece, b.piece = pb, pa
		local groups = Matcher.findGroups(board, { b, a })
		if #groups == 0 then
			a.piece, b.piece = pa, pb
			swapPhase.ok = false
			return false, { swapPhase }
		end
		table.insert(phases, swapPhase)
		self:_useMove()
		local wave = newWave()
		self:_popGroups(wave, groups)
		self:_finishWave(wave, phases)
	end

	self:_afterAction(phases)
	return true, phases
end

-- Cascades, then win/lose, then the leftover-moves bonus.
function Engine._afterAction(self, phases)
	self:_settle(phases)
	self:_updateStatus()
	if self.status == "Won" and self.movesLeft > 0 then
		self:_bonusRound(phases)
	end
end

local function inBoard(self, x: number, y: number): boolean
	return x >= 1 and y >= 1 and x <= self.board.width and y <= self.board.height
end

--[[
	Uses an in-level booster. Doesn't cost a move. Returns false (and no
	phases) if it can't be used there.
	  Trowel(x, y)                 break one tile or one hay bale layer
	  Rake(y)                      clear one row
	  GardenGloves(x1, y1, x2, y2) swap two neighbouring tiles, matching or not
	  ShakeUp()                    shuffle the board
]]
function Engine.useBooster(self, kind: string, a: number?, b: number?, c: number?, d: number?): (boolean, { any })
	local info = Boosters.Info[kind]
	if self.status ~= "Playing" or not info or info.when ~= "in" then
		return false, {}
	end
	local board = self.board
	local phases = {}

	if kind == "Trowel" then
		local cell = board:get(a :: number, b :: number)
		if not cell or (cell.piece == nil and cell.bale == 0) then
			return false, {}
		end
		local wave = newWave()
		table.insert(wave.effects, { type = "Trowel", x = cell.x, y = cell.y })
		self:_hit(wave, cell.x, cell.y)
		self:_finishWave(wave, phases)
	elseif kind == "Rake" then
		local y = a :: number
		if not inBoard(self, 1, y) then
			return false, {}
		end
		local wave = newWave()
		table.insert(wave.effects, { type = "Spray", dir = "Row", x = 1, y = y })
		for x = 1, board.width do
			self:_hit(wave, x, y)
		end
		if #wave.removed == 0 and #wave.bales == 0 then
			return false, {} -- an empty row
		end
		self:_finishWave(wave, phases)
	elseif kind == "GardenGloves" then
		local x1, y1, x2, y2 = a :: number, b :: number, c :: number, d :: number
		if not self:canSwap(x1, y1, x2, y2) then
			return false, {}
		end
		local cellA, cellB = board:get(x1, y1), board:get(x2, y2)
		cellA.piece, cellB.piece = cellB.piece, cellA.piece
		table.insert(phases, { kind = "Swap", from = { x1, y1 }, to = { x2, y2 }, ok = true })
		local groups = Matcher.findGroups(board, { cellB, cellA })
		if #groups > 0 then
			local wave = newWave()
			self:_popGroups(wave, groups)
			self:_finishWave(wave, phases)
		end
	elseif kind == "ShakeUp" then
		table.insert(phases, { kind = "Shuffle", moves = board:shuffle(self.rng, self.colors) })
	end

	self.boostersUsed[kind] = (self.boostersUsed[kind] or 0) + 1
	self:_afterAction(phases)
	return true, phases
end

--[[
	Applies one recorded action: a swap { x1, y1, x2, y2 } or a booster
	{ "Trowel", x, y }, { "Rake", y }, { "GardenGloves", x1, y1, x2, y2 }, { "ShakeUp" }.
]]
function Engine.apply(self, action: { any }): (boolean, { any })
	if type(action[1]) == "string" then
		return self:useBooster(action[1], action[2], action[3], action[4], action[5])
	end
	return self:trySwap(action[1], action[2], action[3], action[4])
end

function Engine._useMove(self)
	self.movesLeft -= 1
	self.movesMade += 1
end

-- Extra moves after running out (paid continues, P2).
function Engine.addMoves(self, count: number)
	self.movesLeft += count
	if self.status == "Lost" then
		self.status = "Playing"
	end
end

function Engine.getState(self)
	return {
		status = self.status,
		movesLeft = self.movesLeft,
		movesMade = self.movesMade,
		goals = self.goals:snapshot(),
		bonus = self.bonus and table.clone(self.bonus),
		stats = table.clone(self.stats),
	}
end

function Engine.listPossibleMoves(self): { { number } }
	return Matcher.listPossibleMoves(self.board)
end

-- Fingerprint of the whole game state, for determinism checks.
function Engine.hash(self): string
	local goalParts = {}
	for _, goal in self.goals.list do
		table.insert(goalParts, tostring(goal.progress))
	end
	return table.concat({
		self.board:hash(),
		tostring(self.movesLeft),
		table.concat(goalParts, ","),
		tostring(self.rng.state),
		self.status,
	}, "|")
end

return Engine

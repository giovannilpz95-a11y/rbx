--[[
	Crop Pop engine: one level being played.

		local game = Engine.new(levelDef, seed)
		local ok, phases = game:trySwap(3, 4, 4, 4)

	`trySwap` applies the move and every cascade it causes, and returns the
	steps as a list of phases for the view to animate, in order:

	  { kind = "Swap", from = {x, y}, to = {x, y}, ok = boolean, combo = boolean? }
	  { kind = "Pop", removed = {{id, x, y, cause}}, created = {{piece, x, y}},
	    transformed = {{id, power}}, bales = {{x, y, hp, weed?}}, mud = {{x, y, layers}},
	    frost = {{x, y, layers}}, clover = {{x, y}}, fences = {{x, y, side}}, goo = {{x, y, on}},
	    statues = {{x, y}} (cells dug up),
	    effects = {{type = "Spray" | "Bomb" | "Bee" | "Sun" | "Everything" | "Grow", ...}} }
	  { kind = "Drop", moves = {Board.Move}, spawns = {Board.Spawn} }
	  { kind = "Shuffle", moves = {Board.Move} }

	A winning move with moves left over also plays the bonus round: a Pop phase
	(with `bonus = { moves, coins }`) where leftover moves become Seed Sprayers.

	Weeds: after a swap that pulls no weed, one weed spreads onto a plain tile
	next to a weed (a Pop phase with a "Grow" effect; the tile is removed with
	cause "weed" and the cell gets a weed).

	Clover: a match with a tile on clover plants clover on every cell of the
	match, and a power-up going off on clover plants it on every cell it hits.
	Seed sacks block a cell and never break: a match next to one (once per
	sack per wave) or a blast on it sows clover on the nearest cells without
	any (up to SACK_SEEDS, nearest first; a "Sow" effect with those cells).
	The sack's own cell needs no clover.

	Pumpkins: a pumpkin that reaches the bottom cell of its column is collected
	(a Pop phase with a "Pumpkin" effect, removed with cause "pumpkin"). Refills
	drop new ones until the Pumpkins goal has enough on the way. Matches and
	blasts never break a pumpkin.

	Goo: covers a tile; a match or blast on the tile clears it. After a swap
	that clears no goo, goo spreads onto a neighbouring tile (a Pop phase with
	an "Ooze" effect, and one more for the Goo goal). If goo covers every tile
	the level is lost (`flooded`). Thick goo takes two clears (the first
	leaves plain goo), and goo spreading next to thick goo spreads thick
	(two more for the goal). Goo springs (not cells, and unbreakable)
	count as goo for spreading: goo can ooze out of one onto a tile next to it.

	Surprise crates: open like a 1-layer bale (a match next to one, or a
	blast). An opened crate leaves a random power-up in its cell (a "Crate"
	effect), or one time in four a 1-layer hay bale.

	Buried statues: only a blast (a power-up or booster) on a buried cell digs
	it up; matches don't. When the last cell of a statue is dug up, the statue
	is found (a "Statue" effect with its cells) for the Statues goal.

	Tarps: touching tarp cells in a row make one tarp, which blocks its cells
	like 1-layer bales. A match next to it rolls it up by one cell from its
	right end (once per tarp per wave), and each blast on one of its cells
	rolls up one more, for the Tarps goal.

	Rainbow patches: after every swap, the plain tile on each patch changes
	to the next of the level's colours that doesn't make a match there (a
	"Recolor" phase: { kind = "Recolor", changes = {{id, x, y, color}} }).

	Quilts and sewing tins: touching quilt cells make one quilt, which blocks
	its cells like bales that nothing breaks. A sewing tin opens like a
	1-layer bale (a match next to it, or a blast) and sends one patch to the
	unfinished quilt with the fewest patches missing (a "Patch" effect from
	the tin to the quilt cell it fills). When a quilt's last patch lands, the
	quilt lifts off and frees its cells (a "Quilt" effect with its cells), for
	the Quilts goal.

	Scarecrows: block a cell and never break. Each hit (a match next to one,
	once per wave, or a blast on it) adds a charge; the SCARECROW_CHARGES-th
	sets it off like a Sunflower on the board's most common colour, and it
	starts charging again. Pop phases list { x, y, hp = 1, scarecrow = charges }
	in bales.

	Mud buckets: block a cell like a 1-layer bale. A hit (a match next to
	one, or a blast) tips it over: it goes, and it spills one layer of mud
	onto every cell in the 3x3 around it (its own too) that has no mud, clay
	or bale (a "Spill" effect with those cells; Pop phases list them in mud).
	Each standing bucket counts one towards the Mud goal, and each spilt
	layer adds one more to clear.

	Produce boxes: a stack of 3 ("v") or 2 ("V") blocks a cell like a bale
	with that many layers. Each hit (a match next to it, or a blast) takes
	the top box for the Boxes goal (a "Box" effect); if any are left, the
	stack hops into the nearest cell the wave just emptied (within 2 steps,
	not one where a power-up is about to appear), with a "Hop" effect from
	its old cell. Pop phases list the old cell with hp 0 and the new one
	with { hp, stack = true } in bales.

	Mailboxes: block a cell like a 2-layer bale. The first hit (a match next
	to it, or a blast) opens it (a "Mailbox" effect saying whether it holds a
	letter); the next takes it away, and a letter inside counts for the
	Letters goal (a "Letter" effect).

	Clay: glazed clay under a tile only cracks under a blast (a power-up or
	booster clearing that tile); after that, any clear of the tile there (a
	match too) breaks the clay up, for the Clay goal. Cracked clay ("A") starts
	that way. The Pop phase lists changes as clay = {{x, y, layers}}.

	Snowballs: tiles that start on "i" cells carry a timer (SNOW_TIMER swaps).
	They match and fall like any tile; clearing one counts for the Snowballs
	goal. After every swap each timer ticks down (a "Tick" phase:
	{ kind = "Tick", timers = {{id, x, y, timer, burst?}} }), and a snowball
	that reaches 0 bursts: it frosts the plain unfrozen tiles around it (all 8
	neighbours; a Pop phase with a "Freeze" effect) and starts its timer again.

	Webs: a web holds its tile in place and keeps it out of matches. Only a
	blast on the cell clears the web (the tile stays), for the Webs goal.

	Fences: no swap crosses one. A blast on either cell next to a fence breaks
	it (matches don't), for the Fences goal.

	Pumpkin baskets: a match next to a basket, or a blast reaching it, shakes
	a pumpkin loose (once per basket per wave, while the goal still needs
	more). It lands in the cell below the basket at the end of the wave
	(a "Basket" effect; a plain tile there is removed with cause "basket"),
	or waits for a later wave if that cell is busy. On levels with baskets,
	refills drop no pumpkins.

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
local SCARECROW_CHARGES = 3 -- hits before a scarecrow clears the most common colour
local SNOW_TIMER = 8 -- swaps before a snowball bursts
local SACK_SEEDS = 3 -- clover cells a seed sack sows each time it's hit
local WEED_COVER_LIMIT = 3 -- weeds stop spreading once they cover 1/this of the cells

local NEIGHBORS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
-- What a surprise crate can hold.
local CRATE_POWERS = { Power.SprayerRow, Power.SprayerColumn, Power.HayBomb, Power.Bumblebee }

local Engine = {}
Engine.__index = Engine

export type Options = {
	-- Power-ups placed on random tiles at the start (pre-level boosters, Hot Streak).
	startPowerUps: { string }?,
}

function Engine.new(level, seed: number, options: Options?)
	local board = Board.fromLayout(level.layout, level.portals, level.fences)
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
		-- made: power-ups made by kind; cleared: tiles cleared by colour (for the score tracks).
		stats = { powerUpsMade = 0, combos = 0, cascades = 0, made = {}, cleared = {} },
		boostersUsed = {}, -- in-level booster kind -> times used
		continues = 0, -- paid +5-move continues taken
		weedsPulled = 0, -- during the current action (stops weeds spreading)
		gooCleared = 0, -- during the current action (stops goo spreading)
	}, Engine)

	for _, cell in board.startSnowballs do
		if cell.piece and not cell.piece.pumpkin then
			cell.piece.timer = SNOW_TIMER
		end
	end

	-- As many pumpkins on the board at once as the layout starts with (at least 1).
	local startPumpkins = 0
	for _ in board.startPumpkins do
		startPumpkins += 1
	end
	self.pumpkinsAtOnce = math.max(1, startPumpkins)

	if options and options.startPowerUps then
		self:_placePowerUps(options.startPowerUps)
	end
	return self
end

-- Turns random plain tiles into power-ups. Returns what changed (as a Pop
-- phase's `transformed`) and a Shuffle phase if the board had to be shuffled.
function Engine._placePowerUps(self, powers: { string })
	local placed = {}
	local candidates = {}
	self.board:eachCell(function(cell)
		if Board.isPlainTile(cell) then
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
		table.insert(placed, { id = cell.piece.id, power = power, x = cell.x, y = cell.y })
	end
	local shuffle = nil
	if not Matcher.hasPossibleMove(self.board) then
		shuffle = { kind = "Shuffle", moves = self.board:shuffle(self.rng, self.colors) }
	end
	return placed, shuffle
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
		clay = {},
		frost = {},
		clover = {},
		fences = {},
		goo = {},
		statues = {},
		webs = {},
		quilts = {}, -- quilt cells that got their patch: { x, y }
		effects = {},
		queue = {}, -- power-ups waiting to go off
		spread = false, -- the power-up going off started on clover
		pendingCreates = {},
		balesTouched = {}, -- bales already hit by a neighbouring match this wave
		tarpsRolled = {}, -- tarps already rolled by a neighbouring match this wave
		basketsHit = {}, -- baskets already shaken this wave
	}
end

function Engine._removePiece(self, wave, cell, cause: string, noActivate: boolean?)
	local piece = cell.piece
	if not piece or piece.pumpkin then
		return -- pumpkins only leave from the bottom of the board
	end
	if cell.frost > 0 then
		-- The tile stays; only one frost layer breaks.
		cell.frost -= 1
		table.insert(wave.frost, { x = cell.x, y = cell.y, layers = cell.frost })
		self.goals:onFrost()
		return
	end
	cell.piece = nil
	table.insert(wave.removed, { id = piece.id, x = cell.x, y = cell.y, cause = cause })
	self.goals:onCollect(piece.color)
	if piece.timer then
		self.goals:onSnowball()
	end
	if cell.goo then
		if cell.thickGoo then
			cell.thickGoo = false -- the tile goes; a thin layer of goo stays
		else
			cell.goo = false
		end
		table.insert(wave.goo, { x = cell.x, y = cell.y, on = cell.goo })
		self.goals:onGoo()
		self.gooCleared += 1
	end
	if piece.color > 0 then
		self.stats.cleared[piece.color] = (self.stats.cleared[piece.color] or 0) + 1
	end
	if cell.mud > 0 then
		cell.mud -= 1
		table.insert(wave.mud, { x = cell.x, y = cell.y, layers = cell.mud })
		self.goals:onMud()
	end
	if cell.clay == 2 then
		if cause == "power" then
			cell.clay = 1 -- the glaze cracks; the next clear here breaks it up
			table.insert(wave.clay, { x = cell.x, y = cell.y, layers = 1 })
		end
	elseif cell.clay == 1 then
		cell.clay = nil
		table.insert(wave.clay, { x = cell.x, y = cell.y, layers = 0 })
		self.goals:onClay()
	end
	if piece.power and not noActivate then
		table.insert(wave.queue, { power = piece.power, x = cell.x, y = cell.y, color = piece.color })
	end
end

-- Rolls a tarp up by one cell from its right end.
function Engine._rollTarp(self, wave, tarp)
	for i = #tarp.cells, 1, -1 do
		local cell = tarp.cells[i]
		if cell.tarp then
			cell.tarp = nil
			cell.bale = 0
			tarp.left -= 1
			table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0, tarp = true })
			table.insert(wave.effects, { type = "Roll", x = cell.x, y = cell.y })
			self.goals:onTarp()
			return
		end
	end
end

-- A seed sack sows clover on the nearest cells without it (breadth first,
-- in NEIGHBORS order, so it's the same every time).
function Engine._sow(self, wave, sack)
	local board = self.board
	local seen = { [sack] = true }
	local queue, head = { sack }, 1
	local sown = {}
	while head <= #queue and #sown < SACK_SEEDS do
		local cell = queue[head]
		head += 1
		for _, d in NEIGHBORS do
			local n = board:get(cell.x + d[1], cell.y + d[2])
			if n and not seen[n] then
				seen[n] = true
				table.insert(queue, n)
				if not n.clover and not n.sack and #sown < SACK_SEEDS then
					self:_plantClover(wave, n)
					table.insert(sown, { x = n.x, y = n.y })
				end
			end
		end
	end
	table.insert(wave.effects, { type = "Sow", fromX = sack.x, fromY = sack.y, cells = sown })
end

-- What's left of a produce box stack hops into the nearest cell the wave
-- emptied (a random one of the nearest), or stays put if there's none.
function Engine._hopStack(self, wave, from)
	local reserved = {}
	for _, create in wave.pendingCreates do
		reserved[create.cell] = true
	end
	local best, bestDist = {}, 3
	for dy = -2, 2 do
		for dx = -2, 2 do
			local cell = self.board:get(from.x + dx, from.y + dy)
			local dist = math.abs(dx) + math.abs(dy)
			if cell and dist > 0 and dist <= bestDist and Board.isEmptySlot(cell) and not reserved[cell] and not (wave.reserved and wave.reserved[cell]) then
				if dist < bestDist then
					best, bestDist = {}, dist
				end
				table.insert(best, cell)
			end
		end
	end
	if #best == 0 then
		table.insert(wave.bales, { x = from.x, y = from.y, hp = from.bale, stack = true })
		return
	end
	local to = self.rng:pick(best)
	to.bale, to.stack = from.bale, true
	from.bale, from.stack = 0, nil
	if wave.balesTouched then
		wave.balesTouched[to] = true -- the same wave's matches don't hit it again where it lands
	end
	table.insert(wave.bales, { x = from.x, y = from.y, hp = 0 })
	table.insert(wave.bales, { x = to.x, y = to.y, hp = to.bale, stack = true })
	table.insert(wave.effects, { type = "Hop", fromX = from.x, fromY = from.y, x = to.x, y = to.y, hp = to.bale })
end

-- A tipped mud bucket spills a layer of mud onto the cells around it.
function Engine._spill(self, wave, bucket)
	local spilt = {}
	for dy = -1, 1 do
		for dx = -1, 1 do
			local cell = self.board:get(bucket.x + dx, bucket.y + dy)
			if cell and cell.bale == 0 and cell.mud == 0 and not cell.clay then
				cell.mud = 1
				table.insert(wave.mud, { x = cell.x, y = cell.y, layers = 1 })
				table.insert(spilt, { x = cell.x, y = cell.y })
				self.goals:onMudSpilt()
			end
		end
	end
	table.insert(wave.effects, { type = "Spill", x = bucket.x, y = bucket.y, cells = spilt })
end

-- An opened sewing tin sends a patch to the unfinished quilt with the fewest
-- missing (the first one on a tie); the last patch finishes the quilt.
function Engine._sendPatch(self, wave, from)
	local best = nil
	for _, quilt in self.board.quilts do
		if quilt.left > 0 and (best == nil or quilt.left < best.left) then
			best = quilt
		end
	end
	if not best then
		return
	end
	for _, cell in best.cells do
		if not cell.patched then
			cell.patched = true
			best.left -= 1
			table.insert(wave.quilts, { x = cell.x, y = cell.y })
			table.insert(wave.effects, { type = "Patch", fromX = from.x, fromY = from.y, x = cell.x, y = cell.y })
			break
		end
	end
	if best.left == 0 then
		local cells = {}
		for _, cell in best.cells do
			cell.quilt = nil
			cell.patched = nil
			cell.bale = 0
			table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0, quilt = true })
			table.insert(cells, { x = cell.x, y = cell.y })
		end
		table.insert(wave.effects, { type = "Quilt", cells = cells })
		self.goals:onQuilt()
	end
end

-- byMatch: the hit is a match next to the bale (not a blast on it).
function Engine._damageBale(self, wave, cell, byMatch: boolean?)
	if cell.tarp then
		local tarp = cell.tarp
		if byMatch then
			if wave.tarpsRolled[tarp] then
				return
			end
			wave.tarpsRolled[tarp] = true
		end
		self:_rollTarp(wave, tarp)
		return
	end
	if cell.quilt then
		return -- nothing breaks a quilt; patches finish it
	end
	if cell.sack then
		self:_sow(wave, cell)
		return -- nothing breaks a seed sack
	end
	if cell.scarecrow then
		cell.scarecrow += 1
		if cell.scarecrow >= SCARECROW_CHARGES then
			cell.scarecrow = 0
			table.insert(wave.effects, { type = "Scarecrow", x = cell.x, y = cell.y })
			table.insert(wave.queue, { power = Power.Sunflower, x = cell.x, y = cell.y, color = 0 })
		end
		table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 1, scarecrow = cell.scarecrow })
		return -- nothing breaks a scarecrow
	end
	if cell.mailbox then
		local box = cell.mailbox
		cell.bale -= 1
		if not box.open then
			box.open = true
			table.insert(wave.bales, { x = cell.x, y = cell.y, hp = cell.bale, mailbox = { open = true, mail = box.mail } })
			table.insert(wave.effects, { type = "Mailbox", x = cell.x, y = cell.y, mail = box.mail })
		else
			cell.bale = 0
			cell.mailbox = nil
			table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0 })
			if box.mail then
				table.insert(wave.effects, { type = "Letter", x = cell.x, y = cell.y })
				self.goals:onLetter()
			end
		end
		return
	end
	if cell.bucket then
		cell.bale = 0
		cell.bucket = nil
		table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0, bucket = true })
		self:_spill(wave, cell)
		self.goals:onMud() -- a tipped bucket is one off the Mud goal
		return
	end
	if cell.stack then
		cell.bale -= 1
		table.insert(wave.effects, { type = "Box", x = cell.x, y = cell.y })
		self.goals:onBox()
		if cell.bale == 0 then
			cell.stack = nil
			table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0 })
		else
			self:_hopStack(wave, cell)
		end
		return
	end
	cell.bale -= 1
	if cell.tin then
		cell.tin = false
		table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0, tin = true })
		self:_sendPatch(wave, cell)
		return
	end
	if cell.crate then
		cell.crate = false
		table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0, crate = true })
		table.insert(wave.effects, { type = "Crate", x = cell.x, y = cell.y })
		if self.rng:int(1, 4) == 4 then
			cell.bale = 1
			table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 1 })
		else
			local power = CRATE_POWERS[self.rng:int(1, #CRATE_POWERS)]
			table.insert(wave.pendingCreates, {
				power = power,
				color = self.colors[self.rng:int(1, #self.colors)],
				cell = cell,
			})
		end
		return
	end
	if cell.stone then
		table.insert(wave.bales, { x = cell.x, y = cell.y, hp = cell.bale, stone = true })
		if cell.bale == 0 then
			cell.stone = false
			self.goals:onStone()
		end
		return
	end
	if cell.weed then
		cell.weed = false
		table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 0, weed = true })
		self.goals:onWeed()
		self.weedsPulled += 1
		return
	end
	table.insert(wave.bales, { x = cell.x, y = cell.y, hp = cell.bale })
	if cell.bale == 0 then
		self.goals:onBale()
	end
end

function Engine._plantClover(self, wave, cell)
	if not cell.clover and not cell.sack then
		cell.clover = true
		table.insert(wave.clover, { x = cell.x, y = cell.y })
		self.goals:onClover()
	end
end

-- Pumpkins the goal still needs beyond those on the board or waiting in baskets.
function Engine._pumpkinsOwed(self): number
	local goal = self.goals:find("Pumpkins")
	if not goal then
		return 0
	end
	local owed = goal.target - goal.progress
	self.board:eachCell(function(cell)
		if cell.piece and cell.piece.pumpkin then
			owed -= 1
		end
	end)
	for _, basket in self.board.baskets do
		owed -= basket.waiting
	end
	return owed
end

-- A match next to a basket or a blast on it: shake a pumpkin loose if one is needed.
function Engine._shakeBasket(self, wave, basket)
	if wave.basketsHit[basket] then
		return
	end
	wave.basketsHit[basket] = true
	if self:_pumpkinsOwed() > 0 then
		basket.waiting += 1
	end
end

-- The cell a basket drops into: the next board cell below it.
function Engine._basketTarget(self, basket)
	local board = self.board
	for y = basket.y + 1, board.height do
		local cell = board:get(basket.x, y)
		if cell then
			return cell
		end
	end
	return nil
end

-- Drops each basket's waiting pumpkin into the cell below, if that cell is
-- empty or holds a plain unfrozen tile.
function Engine._emptyBaskets(self, wave)
	for _, basket in self.board.baskets do
		local cell = basket.waiting > 0 and self:_basketTarget(basket)
		if cell and (Board.isEmptySlot(cell) or (Board.isPlainTile(cell) and cell.frost == 0 and not cell.web)) then
			if cell.piece then
				table.insert(wave.removed, { id = cell.piece.id, x = cell.x, y = cell.y, cause = "basket" })
				cell.piece = nil
			end
			basket.waiting -= 1
			local piece = self.board:newPumpkin()
			cell.piece = piece
			table.insert(wave.created, { piece = { id = piece.id, color = piece.color, pumpkin = true }, x = cell.x, y = cell.y })
			table.insert(wave.effects, { type = "Basket", fromX = basket.x, fromY = basket.y, toX = cell.x, toY = cell.y })
		end
	end
end

-- A blast on a buried cell digs it up; the last one finds the statue.
function Engine._digUp(self, wave, cell)
	cell.buried = false
	table.insert(wave.statues, { x = cell.x, y = cell.y })
	local statue = cell.statue
	statue.left -= 1
	if statue.left == 0 then
		local cells = {}
		for _, c in statue.cells do
			table.insert(cells, { x = c.x, y = c.y })
		end
		table.insert(wave.effects, { type = "Statue", cells = cells })
		self.goals:onStatue()
	end
end

-- A power-up blast reaching (x, y).
function Engine._hit(self, wave, x: number, y: number)
	local cell = self.board:get(x, y)
	if not cell then
		local basket = self.board:basket(x, y)
		if basket then
			self:_shakeBasket(wave, basket)
		end
		return
	end
	for _, fence in self.board:fencesAround(x, y) do
		if self.board:breakFence(fence) then
			table.insert(wave.fences, { x = fence.x, y = fence.y, side = fence.side })
			self.goals:onFence()
		end
	end
	if wave.spread then
		self:_plantClover(wave, cell)
	end
	if cell.buried then
		self:_digUp(wave, cell)
	end
	if cell.web then
		cell.web = false -- the blast clears the web; the tile stays
		table.insert(wave.webs, { x = cell.x, y = cell.y })
		self.goals:onWeb()
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
		local onClover = false
		for _, cell in group.cells do
			onClover = onClover or cell.clover
		end
		for _, cell in group.cells do
			if onClover then
				self:_plantClover(wave, cell)
			end
			self:_removePiece(wave, cell, "match")
		end
		if group.power then
			-- A hopping box stack mustn't land where this power-up appears.
			wave.reserved = wave.reserved or {}
			wave.reserved[group.at] = true
		end
		-- Matches next to a hay bale knock off one layer (once per bale per wave).
		-- Stone walls shrug them off: only blasts break stone.
		for _, cell in group.cells do
			for _, d in NEIGHBORS do
				local n = board:get(cell.x + d[1], cell.y + d[2])
				if n and n.bale > 0 and not n.stone and not n.quilt and not wave.balesTouched[n] then
					wave.balesTouched[n] = true
					self:_damageBale(wave, n, true)
				elseif not n then
					local basket = board:basket(cell.x + d[1], cell.y + d[2])
					if basket then
						self:_shakeBasket(wave, basket)
					end
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
			self.stats.made[group.power] = (self.stats.made[group.power] or 0) + 1
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

-- Bumblebees go for what the level needs: weeds and hay bales, then mud and
-- frost, then goal tiles.
function Engine._chooseBeeTarget(self)
	local goals = self.goals
	local tiers = { {}, {}, {}, {} }
	local wantsFences = self.board.fenceCount > 0 and goals:wants("Fences")
	self.board:eachCell(function(cell)
		if wantsFences and #self.board:fencesAround(cell.x, cell.y) > 0 then
			table.insert(tiers[1], cell)
		elseif cell.quilt then
			-- Bees leave quilts alone: nothing breaks them.
		elseif cell.sack then
			table.insert(if goals:wants("Clover") then tiers[1] else tiers[4], cell)
		elseif cell.bucket then
			table.insert(if goals:wants("Mud") then tiers[1] else tiers[4], cell)
		elseif cell.stack then
			table.insert(if goals:wants("Boxes") then tiers[1] else tiers[4], cell)
		elseif cell.mailbox then
			local worth = not cell.mailbox.open or cell.mailbox.mail
			table.insert(if worth and goals:wants("Letters") then tiers[1] else tiers[4], cell)
		elseif cell.bale > 0 then
			local wanted = if cell.weed
				then goals:wants("Weeds")
				elseif cell.stone then goals:wants("Stones")
				elseif cell.tarp then goals:wants("Tarps")
				elseif cell.tin then goals:wants("Quilts")
				else goals:wants("HayBale")
			table.insert(if wanted then tiers[1] else tiers[4], cell)
		elseif cell.piece and not cell.piece.pumpkin then
			if cell.piece.timer and goals:wants("Snowballs") then
				table.insert(tiers[2], cell)
			elseif cell.clay == 2 and goals:wants("Clay") then
				table.insert(tiers[2], cell) -- matches can't crack glazed clay
			elseif cell.frost > 0 and goals:wants("Frost") then
				table.insert(tiers[2], cell)
			elseif cell.mud > 0 and goals:wants("Mud") then
				table.insert(tiers[2], cell)
			elseif cell.goo and goals:wants("Goo") then
				table.insert(tiers[2], cell)
			elseif cell.buried and goals:wants("Statues") then
				table.insert(tiers[2], cell)
			elseif cell.web and goals:wants("Webs") then
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
	local origin = board:get(act.x, act.y)
	wave.spread = act.clover == true or (origin ~= nil and origin.clover)
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
					if wave.spread then
						self:_plantClover(wave, cell)
					end
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

-- Swapping two power-ups together, or a Sunflower with anything. If either
-- cell is on clover, whatever the combo sets off spreads it.
function Engine._combo(self, wave, a, b)
	local queued = #wave.queue
	local onClover = a.clover or b.clover
	self:_comboParts(wave, a, b)
	if onClover then
		for i = queued + 1, #wave.queue do
			wave.queue[i].clover = true
		end
	end
end

function Engine._comboParts(self, wave, a, b)
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
			if piece and cell.bale == 0 and cell.frost == 0 and not cell.web and piece.power == nil and piece.color == other.color then
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
	wave.spread = false
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
	if #self.board.baskets > 0 then
		self:_emptyBaskets(wave)
	end
	table.insert(phases, {
		kind = "Pop",
		removed = wave.removed,
		created = wave.created,
		transformed = wave.transformed,
		bales = wave.bales,
		mud = wave.mud,
		clay = wave.clay,
		frost = wave.frost,
		clover = wave.clover,
		fences = wave.fences,
		goo = wave.goo,
		statues = wave.statues,
		webs = wave.webs,
		quilts = wave.quilts,
		effects = wave.effects,
	})
end

-- After a swap that pulled no weed, one weed spreads onto a neighbouring plain
-- tile, until weeds cover a third of the board.
function Engine._growWeeds(self, phases)
	local board = self.board
	local candidates, seen = {}, {}
	local cells, weeds = 0, 0
	board:eachCell(function(cell)
		cells += 1
		if cell.weed then
			weeds += 1
		end
	end)
	if weeds * WEED_COVER_LIMIT >= cells then
		return
	end
	board:eachCell(function(cell)
		if cell.weed then
			for _, d in NEIGHBORS do
				local n = board:get(cell.x + d[1], cell.y + d[2])
				if n and not seen[n] and Board.isPlainTile(n) then
					seen[n] = true
					table.insert(candidates, n)
				end
			end
		end
	end)
	if #candidates == 0 then
		return
	end
	-- Row-major order keeps the pick the same on client and server.
	table.sort(candidates, function(a, b)
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.x < b.x
	end)
	local cell = candidates[self.rng:int(1, #candidates)]
	local wave = newWave()
	table.insert(wave.removed, { id = cell.piece.id, x = cell.x, y = cell.y, cause = "weed" })
	cell.piece = nil
	cell.bale = 1
	cell.weed = true
	self.goals:onWeedGrown()
	table.insert(wave.bales, { x = cell.x, y = cell.y, hp = 1, weed = true })
	table.insert(wave.effects, { type = "Grow", x = cell.x, y = cell.y })
	self:_finishWave(wave, phases)
	if not Matcher.hasPossibleMove(board) then
		table.insert(phases, { kind = "Shuffle", moves = board:shuffle(self.rng, self.colors) })
	end
end

-- After a swap that cleared no goo, goo spreads onto one neighbouring tile.
-- Covering every tile floods the board (the level is lost).
function Engine._growGoo(self, phases)
	local board = self.board
	local any = #board.springs > 0
	board:eachCell(function(cell)
		any = any or cell.goo == true
	end)
	if not any then
		return
	end
	local candidates, seen = {}, {}
	local function around(x, y)
		for _, d in NEIGHBORS do
			local n = board:get(x + d[1], y + d[2])
			if n and not seen[n] and not n.goo and n.bale == 0 and n.frost == 0 and not n.web and n.piece and not n.piece.pumpkin then
				seen[n] = true
				table.insert(candidates, n)
			end
		end
	end
	board:eachCell(function(cell)
		if cell.goo then
			around(cell.x, cell.y)
		end
	end)
	for _, spring in board.springs do
		around(spring.x, spring.y)
	end
	if #candidates == 0 then
		return
	end
	-- Row-major order keeps the pick the same on client and server.
	table.sort(candidates, function(a, b)
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.x < b.x
	end)
	local cell = candidates[self.rng:int(1, #candidates)]
	cell.goo = true
	self.goals:onGooGrown()
	-- Goo spreading next to thick goo spreads thick.
	for _, d in NEIGHBORS do
		local n = board:get(cell.x + d[1], cell.y + d[2])
		if n and n.thickGoo and not cell.thickGoo then
			cell.thickGoo = true
			self.goals:onGooGrown()
		end
	end
	local wave = newWave()
	table.insert(wave.goo, { x = cell.x, y = cell.y, on = true, thick = cell.thickGoo == true })
	table.insert(wave.effects, { type = "Ooze", x = cell.x, y = cell.y })
	self:_finishWave(wave, phases)
	local clean = false
	board:eachCell(function(c)
		clean = clean or (not c.goo and c.bale == 0)
	end)
	if not clean then
		self.flooded = true
	end
end

-- How many more pumpkins refills should drop: enough for the goal, a few at a time.
function Engine._pumpkinsWanted(self): number
	local goal = self.goals:find("Pumpkins")
	if not goal or #self.board.baskets > 0 then
		return 0 -- with baskets, pumpkins come only from them
	end
	local onBoard = 0
	self.board:eachCell(function(cell)
		if cell.piece and cell.piece.pumpkin then
			onBoard += 1
		end
	end)
	local stillNeeded = goal.target - goal.progress - onBoard
	return math.max(0, math.min(stillNeeded, self.pumpkinsAtOnce - onBoard))
end

-- Collects pumpkins sitting on the bottom cell of their column. Returns true if any.
function Engine._collectPumpkins(self, phases): boolean
	local board = self.board
	local wave = nil
	board:eachCell(function(cell)
		local piece = cell.piece
		if piece and piece.pumpkin and board:isExit(cell) then
			wave = wave or newWave()
			cell.piece = nil
			table.insert(wave.removed, { id = piece.id, x = cell.x, y = cell.y, cause = "pumpkin" })
			table.insert(wave.effects, { type = "Pumpkin", x = cell.x, y = cell.y })
			self.goals:onPumpkin()
		end
	end)
	if wave then
		self:_finishWave(wave, phases)
		return true
	end
	return false
end

-- Drops, refills and cascades until the board is still, then shuffles if stuck.
function Engine._settle(self, phases)
	local board = self.board
	for _ = 1, MAX_CASCADES do
		board.pumpkinsToSpawn = self:_pumpkinsWanted()
		local moves, spawns = board:applyGravity(self.rng, self.colors)
		board.pumpkinsToSpawn = 0
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

		local collected = self:_collectPumpkins(phases)
		local groups = Matcher.findGroups(board, landed)
		if #groups > 0 then
			self.stats.cascades += 1
			local wave = newWave()
			self:_popGroups(wave, groups)
			self:_finishWave(wave, phases)
		elseif not collected then
			break
		end
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
		if Board.isPlainTile(cell) then
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
	elseif self.flooded then
		-- Goo covers the whole board: more moves won't help.
		self.status = "Lost"
		self.stuck = true
	elseif self.movesLeft <= 0 then
		self.status = "Lost"
	elseif not Matcher.hasPossibleMove(self.board) then
		-- Even a shuffle found no swap (frost or weeds have taken too much room).
		self.status = "Lost"
		self.stuck = true
	end
end

-- Public API -----------------------------------------------------------------

function Engine.canSwap(self, x1: number, y1: number, x2: number, y2: number): boolean
	if self.status ~= "Playing" or math.abs(x1 - x2) + math.abs(y1 - y2) ~= 1 then
		return false
	end
	return Board.isMovable(self.board:get(x1, y1)) and Board.isMovable(self.board:get(x2, y2)) and not self.board:fenceBetween(x1, y1, x2, y2)
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

	self.weedsPulled = 0
	self.gooCleared = 0
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

	self:_afterAction(phases, true)
	return true, phases
end

-- Would the tile at (x, y) be part of a line of 3 or a 2x2 square?
local function matchesAt(board, x: number, y: number): boolean
	local color = Matcher.colorAt(board, x, y)
	if color <= 0 then
		return false
	end
	local function same(cx, cy)
		return Matcher.colorAt(board, cx, cy) == color
	end
	for _, d in { { 1, 0 }, { 0, 1 } } do
		local run = 1
		local k = 1
		while same(x + d[1] * k, y + d[2] * k) do
			run += 1
			k += 1
		end
		k = 1
		while same(x - d[1] * k, y - d[2] * k) do
			run += 1
			k += 1
		end
		if run >= 3 then
			return true
		end
	end
	for _, s in { { -1, -1 }, { 0, -1 }, { -1, 0 }, { 0, 0 } } do
		local sx, sy = x + s[1], y + s[2]
		if same(sx, sy) and same(sx + 1, sy) and same(sx, sy + 1) and same(sx + 1, sy + 1) then
			return true
		end
	end
	return false
end

-- Rainbow patches: each plain tile on one moves on to the next level colour
-- that doesn't make a match there (it keeps its colour if none fits).
-- Every snowball ticks down; one at 0 frosts the tiles around it and starts again.
function Engine._tickSnowballs(self, phases)
	local board = self.board
	local timers, bursting = {}, {}
	board:eachCell(function(cell)
		local piece = cell.piece
		if piece and piece.timer then
			piece.timer -= 1
			local burst = piece.timer <= 0
			if burst then
				piece.timer = SNOW_TIMER
				table.insert(bursting, cell)
			end
			table.insert(timers, { id = piece.id, x = cell.x, y = cell.y, timer = piece.timer, burst = burst or nil })
		end
	end)
	if #timers == 0 then
		return
	end
	table.insert(phases, { kind = "Tick", timers = timers })
	if #bursting == 0 then
		return
	end
	local wave = newWave()
	for _, cell in bursting do
		table.insert(wave.effects, { type = "Freeze", x = cell.x, y = cell.y })
		for dy = -1, 1 do
			for dx = -1, 1 do
				local n = board:get(cell.x + dx, cell.y + dy)
				if n and n ~= cell and n.frost == 0 and Board.isPlainTile(n) and not n.piece.timer then
					n.frost = 1
					table.insert(wave.frost, { x = n.x, y = n.y, layers = 1 })
				end
			end
		end
	end
	self:_finishWave(wave, phases)
	if not Matcher.hasPossibleMove(board) then
		table.insert(phases, { kind = "Shuffle", moves = board:shuffle(self.rng, self.colors) })
	end
end

function Engine._recolor(self, phases)
	local board = self.board
	local colors = self.colors
	local changes = {}
	board:eachCell(function(cell)
		local piece = cell.piece
		if cell.rainbow and Board.isPlainTile(cell) and piece.color > 0 then
			local start = piece.color
			local at = table.find(colors, start) or 0
			for step = 1, #colors - 1 do
				piece.color = colors[(at + step - 1) % #colors + 1]
				if not matchesAt(board, cell.x, cell.y) then
					break
				end
				piece.color = start
			end
			if piece.color ~= start then
				table.insert(changes, { id = piece.id, x = cell.x, y = cell.y, color = piece.color, timer = piece.timer })
			end
		end
	end)
	if #changes > 0 then
		table.insert(phases, { kind = "Recolor", changes = changes })
		if not Matcher.hasPossibleMove(board) then
			table.insert(phases, { kind = "Shuffle", moves = board:shuffle(self.rng, self.colors) })
		end
	end
end

-- Cascades, weeds spreading (after a swap), then win/lose, then the leftover-moves bonus.
function Engine._afterAction(self, phases, wasSwap: boolean?)
	self:_settle(phases)
	if wasSwap and self.weedsPulled == 0 and not self.goals:isComplete() then
		self:_growWeeds(phases)
	end
	if wasSwap and self.gooCleared == 0 and not self.goals:isComplete() then
		self:_growGoo(phases)
	end
	if wasSwap and self.board.hasRainbow and not self.goals:isComplete() then
		self:_recolor(phases)
	end
	if wasSwap and #self.board.startSnowballs > 0 and not self.goals:isComplete() then
		self:_tickSnowballs(phases)
	end
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
	  Trowel(x, y)                 break one tile or one hay bale layer (not a pumpkin)
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
		if not cell or cell.quilt or (cell.piece == nil and cell.bale == 0) or (cell.piece and cell.piece.pumpkin) then
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
		if #wave.removed == 0 and #wave.bales == 0 and #wave.frost == 0 and #wave.fences == 0 and #wave.statues == 0 and #wave.webs == 0 then
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
	Applies one recorded action: a swap { x1, y1, x2, y2 }, a booster
	{ "Trowel", x, y }, { "Rake", y }, { "GardenGloves", x1, y1, x2, y2 }, { "ShakeUp" },
	or a paid continue { "Continue" }.
]]
function Engine.apply(self, action: { any }): (boolean, { any })
	if action[1] == "Continue" then
		return self:continue()
	elseif action[1] == "DevOneMove" then
		-- Studio testing only (Replay drops it elsewhere): jump to the last move.
		if self.status ~= "Playing" then
			return false, {}
		end
		self.movesLeft = 1
		return true, {}
	end
	if type(action[1]) == "string" then
		return self:useBooster(action[1], action[2], action[3], action[4], action[5])
	end
	return self:trySwap(action[1], action[2], action[3], action[4])
end

function Engine._useMove(self)
	self.movesLeft -= 1
	self.movesMade += 1
end

function Engine.addMoves(self, count: number)
	self.movesLeft += count
	if self.status == "Lost" then
		self.status = "Playing"
	end
end

-- A paid continue after running out of moves: +5 moves, and from the second
-- one a power-up on the board (Boosters.Continue). Only when the level is lost.
function Engine.continue(self): (boolean, { any })
	if self.status ~= "Lost" or self.stuck then
		return false, {}
	end
	self.continues += 1
	local step = Boosters.continueStep(self.continues)
	self:addMoves(Boosters.Continue.MOVES)
	local phases = {}
	if step.power then
		local placed, shuffle = self:_placePowerUps({ step.power })
		table.insert(phases, { kind = "Pop", removed = {}, created = {}, transformed = placed, bales = {}, mud = {}, frost = {}, clover = {}, fences = {}, goo = {}, statues = {}, webs = {}, effects = {} })
		if shuffle then
			table.insert(phases, shuffle)
		end
	end
	return true, phases
end

function Engine.copyStats(stats)
	local copy = table.clone(stats)
	copy.made = table.clone(stats.made)
	copy.cleared = table.clone(stats.cleared)
	return copy
end

function Engine.getState(self)
	return {
		status = self.status,
		movesLeft = self.movesLeft,
		movesMade = self.movesMade,
		goals = self.goals:snapshot(),
		bonus = self.bonus and table.clone(self.bonus),
		stats = Engine.copyStats(self.stats),
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
		tostring(self.continues),
	}, "|")
end

return Engine

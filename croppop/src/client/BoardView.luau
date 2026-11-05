--[[
	Draws a Crop Pop board in a GUI frame and animates the engine's phases.

		local view = BoardView.new(parentFrame, function(x1, y1, x2, y2) ... end)
		view:load(game)               -- draw the starting board
		view:play(phases)             -- yields until the animations finish
		view:sync(game)               -- snap every tile to the engine's state

		view:setCellTarget(fn)        -- boosters: the next tap calls fn(x, y) instead of swapping

	Tiles are pooled Frames positioned by scale, so the board resizes with the
	screen. Input is a swipe (or tap one tile, then a neighbour) on invisible
	per-cell buttons.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent.Sfx)
local TileStyle = require(script.Parent.TileStyle)

local BoardView = {}
BoardView.__index = BoardView

local SWAP_TIME = 0.14
local POP_TIME = 0.16
local CREATE_TIME = 0.14
local FALL_TIME_PER_CELL = 0.045
local MIN_FALL_TIME = 0.1
local SHUFFLE_TIME = 0.35
local BEE_TIME = 0.32
local FX_TIME = 0.25
local SWIPE_THRESHOLD = 0.35 -- fraction of a cell
local FACE_SIZE = 0.88

local function tween(instance: Instance, time: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function layer(name: string, zIndex: number, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ZIndex = zIndex
	frame.Parent = parent
	return frame
end

function BoardView.new(parent: GuiObject, onSwap: (number, number, number, number) -> ())
	local self = setmetatable({}, BoardView)
	self.onSwap = onSwap
	self.pool = {}
	self.tiles = {} -- piece id -> tile Frame
	self.grid = {} -- [y][x] -> piece id
	self.cellGuis = {} -- [y][x] -> { cell, mud, bale, frost, frostStroke }
	self.connections = {}
	self.width, self.height = 1, 1
	self.enabled = true

	local frame = Instance.new("Frame")
	frame.Name = "Board"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Parent = parent
	self.frame = frame

	self.aspect = Instance.new("UIAspectRatioConstraint")
	self.aspect.Parent = frame

	self.cellLayer = layer("Cells", 1, frame)
	self.tileLayer = layer("Tiles", 2, frame)
	self.baleLayer = layer("Bales", 3, frame)
	self.fxLayer = layer("Effects", 4, frame)
	self.hitLayer = layer("Hit", 5, frame)

	local selection = Instance.new("Frame")
	selection.Name = "Selection"
	selection.BackgroundTransparency = 1
	selection.Visible = false
	selection.Parent = self.fxLayer
	local stroke = Instance.new("UIStroke")
	stroke.Color = TileStyle.Board.selection
	stroke.Thickness = 3
	stroke.Parent = selection
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = selection
	self.selection = selection

	-- Outline while a booster is waiting for a tap.
	local targetStroke = Instance.new("UIStroke")
	targetStroke.Name = "TargetStroke"
	targetStroke.Color = TileStyle.Board.accent
	targetStroke.Thickness = 4
	targetStroke.Enabled = false
	targetStroke.Parent = frame
	self.targetStroke = targetStroke

	self:_bindInput()
	return self
end

function BoardView._cellPosition(self, x: number, y: number): UDim2
	return UDim2.fromScale((x - 1) / self.width, (y - 1) / self.height)
end

function BoardView._cellSize(self): UDim2
	return UDim2.fromScale(1 / self.width, 1 / self.height)
end

-- Tiles ----------------------------------------------------------------------

local function makeTile(): Frame
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BackgroundTransparency = 1

	local face = Instance.new("TextLabel")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(FACE_SIZE, FACE_SIZE)
	face.TextScaled = true
	face.Font = TileStyle.Font
	face.BorderSizePixel = 0
	face.Parent = tile
	local corner = Instance.new("UICorner")
	corner.Name = "Corner"
	corner.Parent = face
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.12, 0)
	padding.PaddingRight = UDim.new(0.12, 0)
	padding.Parent = face

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.fromScale(1, 0)
	badge.Size = UDim2.fromScale(0.5, 0.5)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.TextScaled = true
	badge.Font = TileStyle.Font
	badge.TextColor3 = TileStyle.Board.text
	badge.ZIndex = 2
	badge.Parent = tile
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0.5, 0)
	badgeCorner.Parent = badge

	-- A snowball's timer: swaps left before it bursts.
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0, 1)
	timer.Position = UDim2.fromScale(0, 1)
	timer.Size = UDim2.fromScale(0.5, 0.45)
	timer.BackgroundColor3 = TileStyle.Board.frost
	timer.TextScaled = true
	timer.Font = TileStyle.Font
	timer.TextColor3 = TileStyle.Board.snowText
	timer.ZIndex = 2
	timer.Visible = false
	timer.Parent = tile
	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0.5, 0)
	timerCorner.Parent = timer

	return tile
end

local function styleTimer(tile: Frame, timer: number?)
	local label = tile:FindFirstChild("Timer") :: TextLabel?
	if label then
		label.Visible = timer ~= nil
		label.Text = if timer then TileStyle.SnowGlyph .. timer else ""
	end
end

local function styleTile(tile: Frame, piece)
	styleTimer(tile, piece.timer)
	local face = tile:FindFirstChild("Face") :: TextLabel
	local badge = tile:FindFirstChild("Badge") :: TextLabel
	local corner = face:FindFirstChild("Corner") :: UICorner
	if piece.power == "Sunflower" then
		face.BackgroundColor3 = TileStyle.Sunflower.color
		face.Text = TileStyle.Sunflower.glyph
		corner.CornerRadius = UDim.new(0.5, 0)
		badge.Visible = false
	elseif piece.pumpkin then
		face.BackgroundColor3 = TileStyle.Pumpkin.color
		face.Text = TileStyle.Pumpkin.glyph
		corner.CornerRadius = UDim.new(0.35, 0)
		badge.Visible = false
	else
		face.BackgroundColor3 = TileStyle.Colors[piece.color] or Color3.new(0.5, 0.5, 0.5)
		face.Text = TileStyle.Glyphs[piece.color] or "?"
		corner.CornerRadius = UDim.new(TileStyle.Corners[piece.color] or 0.25, 0)
		local badgeText = piece.power and TileStyle.PowerBadges[piece.power]
		badge.Visible = badgeText ~= nil
		badge.Text = badgeText or ""
	end
	face.Size = UDim2.fromScale(FACE_SIZE, FACE_SIZE)
	face.BackgroundTransparency = 0
	face.TextTransparency = 0
	face.Rotation = 0
end

function BoardView._acquire(self, piece, x: number, y: number): Frame
	local tile = table.remove(self.pool) or makeTile()
	styleTile(tile, piece)
	tile.Size = self:_cellSize()
	tile.Position = self:_cellPosition(x, y)
	tile.Visible = true
	tile.Parent = self.tileLayer
	self.tiles[piece.id] = tile
	return tile
end

function BoardView._release(self, id: number)
	local tile = self.tiles[id]
	if tile then
		self.tiles[id] = nil
		tile.Visible = false
		table.insert(self.pool, tile)
	end
end

-- Board setup ------------------------------------------------------------------

-- kind: the cell (or phase entry) saying what the "bale" is: weed, stone,
-- crate, tarp, tin, quilt (+ patched, x, y).
local function styleBale(label: TextLabel, hp: number, kind)
	local weed, stone, crate = kind.weed, kind.stone, kind.crate
	local tarp = kind.tarp ~= nil and kind.tarp ~= false
	label.Visible = hp > 0
	label.TextColor3 = if tarp then TileStyle.Board.tarpText else TileStyle.Board.baleText
	if kind.quilt then
		local patches = TileStyle.QuiltPatchColors
		label.BackgroundColor3 = if kind.patched then patches[(kind.x + kind.y * 2) % #patches + 1] else TileStyle.Board.quilt
		label.TextColor3 = TileStyle.Board.quiltText
		label.Text = if kind.patched then "" else "+" -- the stitch where a patch goes
	elseif kind.tin then
		label.BackgroundColor3 = TileStyle.Board.tin
		label.Text = TileStyle.TinGlyph
	elseif kind.sack then
		label.BackgroundColor3 = TileStyle.Board.sack
		label.Text = TileStyle.SackGlyph
	elseif kind.bucket then
		label.BackgroundColor3 = TileStyle.Board.bucket
		label.Text = TileStyle.BucketGlyph
	elseif kind.lamb then
		label.BackgroundColor3 = TileStyle.Board.lamb
		label.Text = TileStyle.GoalGlyphs.Lambs
	elseif kind.bud then
		-- Pinker as it charges; the dots are its charges so far.
		label.BackgroundColor3 = if kind.bud > 0 then TileStyle.Board.budLit else TileStyle.Board.bud
		label.Text = TileStyle.GoalGlyphs.Blooms .. string.rep("•", kind.bud)
	elseif kind.snail then
		label.BackgroundColor3 = TileStyle.Board.snail
		label.Text = TileStyle.SnailGlyph
	elseif kind.truck then
		label.BackgroundColor3 = TileStyle.Board.truck
		label.Text = TileStyle.TruckGlyph .. hp -- bales still on it
	elseif kind.hive then
		label.BackgroundColor3 = TileStyle.Board.hive
		label.Text = TileStyle.GoalGlyphs.Honey
	elseif kind.stack then
		label.BackgroundColor3 = TileStyle.Board.box
		label.Text = TileStyle.GoalGlyphs.Boxes .. hp -- boxes left on the stack
	elseif kind.scarecrow then
		label.BackgroundColor3 = TileStyle.Board.scarecrow
		label.Text = TileStyle.ScarecrowGlyph .. string.rep("•", kind.scarecrow)
	elseif kind.mailbox then
		local box = kind.mailbox
		label.BackgroundColor3 = TileStyle.Board.mailbox
		label.Text = if not box.open then TileStyle.MailGlyphs.closed elseif box.mail then TileStyle.MailGlyphs.full else TileStyle.MailGlyphs.empty
	elseif tarp then
		label.BackgroundColor3 = TileStyle.Board.tarp
		label.Text = "≋" -- canvas stripes
	elseif crate then
		label.BackgroundColor3 = TileStyle.Board.crate
		label.Text = TileStyle.CrateGlyph
	elseif weed then
		label.BackgroundColor3 = TileStyle.Board.weed
		label.Text = TileStyle.GoalGlyphs.Weeds
	elseif stone then
		label.BackgroundColor3 = TileStyle.Board.stone
		label.Text = if hp > 1 then TileStyle.GoalGlyphs.Stones .. hp else TileStyle.GoalGlyphs.Stones
	else
		label.BackgroundColor3 = TileStyle.Board.bale
		label.Text = if hp > 1 then "🌾" .. hp else "🌾"
	end
end

-- A firefly spot's marker: a warm glow and a firefly when lit, a dim dot when not.
local function styleSpot(label: TextLabel, lit: boolean)
	label.Text = if lit then TileStyle.GoalGlyphs.Fireflies else TileStyle.SpotGlyph
	label.BackgroundColor3 = if lit then TileStyle.Board.glow else TileStyle.Board.spot
	label.BackgroundTransparency = if lit then 0.1 else 0.5
	label.TextColor3 = if lit then TileStyle.Board.text else Color3.new(1, 1, 1)
end

local function styleClay(guis, layers: number?)
	guis.clay.Visible = (layers or 0) > 0
	guis.clay.BackgroundTransparency = if layers == 2 then 0.1 else 0.35
	local glaze = guis.clay:FindFirstChild("Glaze") :: UIStroke
	glaze.Enabled = layers == 2
end

local function styleFrost(guis, layers: number)
	guis.frost.Visible = layers > 0
	guis.frost.BackgroundTransparency = if layers >= 2 then 0.25 else 0.5
	guis.frostStroke.Thickness = if layers >= 2 then 4 else 2
end

function BoardView._updateCell(self, x: number, y: number, cell)
	local guis = self.cellGuis[y] and self.cellGuis[y][x]
	if not guis then
		return
	end
	guis.mud.Visible = cell.mud > 0
	guis.mud.BackgroundTransparency = if cell.mud >= 2 then 0.15 else 0.45
	styleClay(guis, cell.clay)
	guis.clover.Visible = cell.clover == true
	guis.goo.Visible = cell.goo == true
	guis.goo.BackgroundColor3 = if cell.thickGoo then TileStyle.Board.thickGoo else TileStyle.Board.goo
	guis.buried.Visible = cell.buried == true
	guis.rainbow.Visible = cell.rainbow == true
	guis.web.Visible = cell.web == true
	guis.statueMark.Visible = cell.buried == true
	styleBale(guis.bale, cell.bale, cell)
	styleFrost(guis, cell.frost or 0)
end

function BoardView.load(self, game)
	local board = game.board
	for _, child in self.cellLayer:GetChildren() do
		child:Destroy()
	end
	for _, child in self.baleLayer:GetChildren() do
		child:Destroy()
	end
	for _, child in self.hitLayer:GetChildren() do
		child:Destroy()
	end
	for id in self.tiles do
		self:_release(id)
	end
	self:clearSelection()

	self.width, self.height = board.width, board.height
	self.aspect.AspectRatio = board.width / board.height
	self.grid = {}
	self.cellGuis = {}
	self.spotGuis = {} -- y * 100 + x -> firefly spot marker
	for y = 1, board.height do
		self.grid[y] = {}
		self.cellGuis[y] = {}
	end

	board:eachCell(function(cell)
		local x, y = cell.x, cell.y
		local bg = Instance.new("Frame")
		bg.Name = "Cell"
		bg.Size = self:_cellSize()
		bg.Position = self:_cellPosition(x, y)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = if (x + y) % 2 == 0 then TileStyle.Board.cellLight else TileStyle.Board.cellDark
		bg.Parent = self.cellLayer

		local mud = Instance.new("Frame")
		mud.Name = "Mud"
		mud.AnchorPoint = Vector2.new(0.5, 0.5)
		mud.Position = UDim2.fromScale(0.5, 0.5)
		mud.Size = UDim2.fromScale(0.96, 0.96)
		mud.BorderSizePixel = 0
		mud.BackgroundColor3 = TileStyle.Board.mud
		mud.Parent = bg
		local mudCorner = Instance.new("UICorner")
		mudCorner.CornerRadius = UDim.new(0.2, 0)
		mudCorner.Parent = mud

		-- Clay under the tile: terracotta, with a shiny glaze ring while glazed.
		local clay = Instance.new("Frame")
		clay.Name = "Clay"
		clay.AnchorPoint = Vector2.new(0.5, 0.5)
		clay.Position = UDim2.fromScale(0.5, 0.5)
		clay.Size = UDim2.fromScale(0.96, 0.96)
		clay.BorderSizePixel = 0
		clay.BackgroundColor3 = TileStyle.Board.clay
		clay.Visible = false
		clay.Parent = bg
		local clayCorner = Instance.new("UICorner")
		clayCorner.CornerRadius = UDim.new(0.1, 0)
		clayCorner.Parent = clay
		local glaze = Instance.new("UIStroke")
		glaze.Name = "Glaze"
		glaze.Color = TileStyle.Board.glaze
		glaze.Thickness = 3
		glaze.Parent = clay

		-- Clover covers the cell, over any mud, with a leaf in the corner.
		local clover = Instance.new("TextLabel")
		clover.Name = "Clover"
		clover.Size = UDim2.fromScale(1, 1)
		clover.BorderSizePixel = 0
		clover.BackgroundColor3 = TileStyle.Board.clover
		clover.BackgroundTransparency = 0.25
		clover.Text = ""
		clover.Parent = bg
		local leaf = Instance.new("TextLabel")
		leaf.Name = "Leaf"
		leaf.AnchorPoint = Vector2.new(1, 1)
		leaf.Position = UDim2.fromScale(1, 1)
		leaf.Size = UDim2.fromScale(0.32, 0.32)
		leaf.BackgroundTransparency = 1
		leaf.Text = TileStyle.GoalGlyphs.Clover
		leaf.TextScaled = true
		leaf.Parent = clover

		-- Goo: a green film over the cell, under the tile, with rounded blobs.
		local goo = Instance.new("Frame")
		goo.Name = "Goo"
		goo.AnchorPoint = Vector2.new(0.5, 0.5)
		goo.Position = UDim2.fromScale(0.5, 0.5)
		goo.Size = UDim2.fromScale(1, 1)
		goo.BorderSizePixel = 0
		goo.BackgroundColor3 = TileStyle.Board.goo
		goo.BackgroundTransparency = 0.1
		goo.Parent = bg
		local gooCorner = Instance.new("UICorner")
		gooCorner.CornerRadius = UDim.new(0.35, 0)
		gooCorner.Parent = goo

		-- A rainbow patch: rainbow stripes round the tile (it changes colour every swap).
		local rainbow = Instance.new("Frame")
		rainbow.Name = "Rainbow"
		rainbow.Size = UDim2.fromScale(1, 1)
		rainbow.BorderSizePixel = 0
		rainbow.BackgroundColor3 = Color3.new(1, 1, 1)
		rainbow.BackgroundTransparency = 0.15
		rainbow.Parent = bg
		local stripes = Instance.new("UIGradient")
		stripes.Color = ColorSequence.new(TileStyle.RainbowColors[1], TileStyle.RainbowColors[#TileStyle.RainbowColors])
		stripes.Rotation = 45
		stripes.Parent = rainbow

		-- A buried statue: sandy soil over the cell, under the tile, and a
		-- small statue on the cell's corner over the tile (in the bale layer,
		-- so the tile doesn't hide it). A blast digs it up.
		local buried = Instance.new("TextLabel")
		buried.Name = "Buried"
		buried.Size = UDim2.fromScale(1, 1)
		buried.BorderSizePixel = 0
		buried.BackgroundColor3 = TileStyle.Board.buried
		buried.BackgroundTransparency = 0.2
		buried.Text = ""
		buried.Parent = bg
		local statueMark = Instance.new("TextLabel")
		statueMark.Name = "Statue"
		statueMark.AnchorPoint = Vector2.new(1, 1)
		statueMark.Position = UDim2.fromScale(x / board.width, y / board.height)
		statueMark.Size = UDim2.fromScale(0.34 / board.width, 0.34 / board.height)
		statueMark.BackgroundTransparency = 1
		statueMark.Text = TileStyle.GoalGlyphs.Statues
		statueMark.TextScaled = true
		statueMark.ZIndex = 2
		statueMark.Parent = self.baleLayer

		local bale = Instance.new("TextLabel")
		bale.Name = "Bale"
		bale.Size = self:_cellSize()
		bale.Position = self:_cellPosition(x, y)
		bale.BackgroundColor3 = TileStyle.Board.bale
		bale.TextColor3 = TileStyle.Board.baleText
		bale.TextScaled = true
		bale.Font = TileStyle.Font
		bale.BorderSizePixel = 0
		bale.Parent = self.baleLayer
		local baleCorner = Instance.new("UICorner")
		baleCorner.CornerRadius = UDim.new(0.15, 0)
		baleCorner.Parent = bale

		-- A web over the tile (in the bale layer, so it shows on top).
		local web = Instance.new("TextLabel")
		web.Name = "Web"
		web.Size = self:_cellSize()
		web.Position = self:_cellPosition(x, y)
		web.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
		web.BackgroundTransparency = 0.55
		web.TextTransparency = 0.1
		web.Text = TileStyle.GoalGlyphs.Webs
		web.TextScaled = true
		web.BorderSizePixel = 0
		web.Parent = self.baleLayer
		local webCorner = Instance.new("UICorner")
		webCorner.CornerRadius = UDim.new(0.2, 0)
		webCorner.Parent = web

		-- Frost sits over the tile, in the same layer as bales.
		local frost = Instance.new("Frame")
		frost.Name = "Frost"
		frost.Size = self:_cellSize()
		frost.Position = self:_cellPosition(x, y)
		frost.BackgroundColor3 = TileStyle.Board.frost
		frost.BorderSizePixel = 0
		frost.Parent = self.baleLayer
		local frostCorner = Instance.new("UICorner")
		frostCorner.CornerRadius = UDim.new(0.15, 0)
		frostCorner.Parent = frost
		local frostStroke = Instance.new("UIStroke")
		frostStroke.Color = Color3.fromRGB(255, 255, 255)
		frostStroke.Parent = frost

		-- Pumpkin levels: a small arrow over the bottom of each column's lowest
		-- cell, where pumpkins leave. Inside the board, so screen edges can't clip it.
		if game.goals:find("Pumpkins") and board:isExit(cell) then
			local exit = Instance.new("TextLabel")
			exit.Name = "Exit"
			exit.AnchorPoint = Vector2.new(0.5, 1)
			exit.Position = UDim2.fromScale((x - 0.5) / board.width, y / board.height)
			exit.Size = UDim2.fromScale(0.3 / board.width, 0.3 / board.height)
			exit.BackgroundTransparency = 1
			exit.Text = TileStyle.Pumpkin.exit
			exit.TextScaled = true
			exit.Parent = self.baleLayer
		end

		-- Firefly spots: a marker in the cell's top-left corner, over the tile.
		if cell.spot then
			local spot = Instance.new("TextLabel")
			spot.Name = "Spot"
			spot.AnchorPoint = Vector2.new(0, 0)
			spot.Position = UDim2.fromScale((x - 1) / board.width, (y - 1) / board.height)
			spot.Size = UDim2.fromScale(0.4 / board.width, 0.4 / board.height)
			spot.TextScaled = true
			spot.Parent = self.baleLayer
			local spotCorner = Instance.new("UICorner")
			spotCorner.CornerRadius = UDim.new(0.5, 0)
			spotCorner.Parent = spot
			styleSpot(spot, cell.lit == true)
			self.spotGuis[y * 100 + x] = spot
		end

		-- Lamb pens: a little house in the cell's corner, where lambs go home.
		if cell.pen then
			local pen = Instance.new("TextLabel")
			pen.Name = "Pen"
			pen.AnchorPoint = Vector2.new(1, 1)
			pen.Position = UDim2.fromScale(x / board.width, y / board.height)
			pen.Size = UDim2.fromScale(0.4 / board.width, 0.4 / board.height)
			pen.BackgroundColor3 = TileStyle.Board.pen
			pen.BackgroundTransparency = 0.2
			pen.Text = TileStyle.PenGlyph
			pen.TextScaled = true
			pen.Parent = self.baleLayer
			local penCorner = Instance.new("UICorner")
			penCorner.CornerRadius = UDim.new(0.3, 0)
			penCorner.Parent = pen
		end

		-- Portals: a swirl on the bottom edge of the entrance and the top edge of
		-- the exit, in the same colour for each pair.
		for _, link in { { cell.portalOut, "PortalIn", 1, y }, { cell.portalIn, "PortalOut", 0, y - 1 } } do
			if link[1] then
				local pair = self:_portalIndex(board, if link[2] == "PortalIn" then cell else link[1])
				local mark = Instance.new("TextLabel")
				mark.Name = link[2]
				mark.AnchorPoint = Vector2.new(0.5, link[3])
				mark.Position = UDim2.fromScale((x - 0.5) / board.width, link[4] / board.height)
				mark.Size = UDim2.fromScale(0.45 / board.width, 0.3 / board.height)
				mark.BackgroundColor3 = TileStyle.PortalColors[(pair - 1) % #TileStyle.PortalColors + 1]
				mark.Text = TileStyle.PortalGlyph
				mark.TextScaled = true
				mark.Parent = self.baleLayer
				local markCorner = Instance.new("UICorner")
				markCorner.CornerRadius = UDim.new(0.5, 0)
				markCorner.Parent = mark
			end
		end

		self.cellGuis[y][x] = { cell = bg, mud = mud, clay = clay, clover = clover, goo = goo, rainbow = rainbow, web = web, buried = buried, statueMark = statueMark, bale = bale, frost = frost, frostStroke = frostStroke }
		self:_updateCell(x, y, cell)
		self:_makeHitButton(x, y)

		if cell.piece then
			self:_acquire(cell.piece, x, y)
			self.grid[y][x] = cell.piece.id
		end
	end)

	-- Pumpkin baskets sit in the gaps of the board, in the bale layer.
	self.basketGuis = {}
	for _, basket in board.baskets do
		local label = Instance.new("TextLabel")
		label.Name = "Basket"
		label.Size = self:_cellSize()
		label.Position = self:_cellPosition(basket.x, basket.y)
		label.BackgroundColor3 = TileStyle.Board.basket
		label.Text = TileStyle.BasketGlyph
		label.TextScaled = true
		label.BorderSizePixel = 0
		label.Parent = self.baleLayer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = label
		self.basketGuis[basket.y * 100 + basket.x] = label
	end

	-- Hen houses, in the gaps like baskets.
	for _, hen in board.hens do
		local label = Instance.new("TextLabel")
		label.Name = "HenHouse"
		label.Size = self:_cellSize()
		label.Position = self:_cellPosition(hen.x, hen.y)
		label.BackgroundColor3 = TileStyle.Board.hen
		label.Text = TileStyle.HenGlyph
		label.TextScaled = true
		label.BorderSizePixel = 0
		label.Parent = self.baleLayer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = label
	end

	-- Goo springs, in the gaps like baskets.
	for _, spring in board.springs do
		local label = Instance.new("TextLabel")
		label.Name = "GooSpring"
		label.Size = self:_cellSize()
		label.Position = self:_cellPosition(spring.x, spring.y)
		label.BackgroundColor3 = TileStyle.Board.spring
		label.Text = TileStyle.SpringGlyph
		label.TextScaled = true
		label.BorderSizePixel = 0
		label.Parent = self.baleLayer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = label
	end

	-- Fences: a wooden bar on the edge right of or below their cell. Hedges
	-- are thicker and green.
	self.fenceGuis = {}
	for _, fence in board.fences do
		local bar = Instance.new("Frame")
		bar.Name = if fence.hedge then "Hedge" else "Fence"
		bar.BackgroundColor3 = if fence.hedge then TileStyle.Board.hedge else TileStyle.Board.fence
		local thick = if fence.hedge then 0.22 else 0.14
		bar.BorderSizePixel = 0
		local w, h = board.width, board.height
		if fence.side == "r" then
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(fence.x / w, (fence.y - 0.5) / h)
			bar.Size = UDim2.fromScale(thick / w, 0.92 / h)
		else
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale((fence.x - 0.5) / w, fence.y / h)
			bar.Size = UDim2.fromScale(0.92 / w, thick / h)
		end
		bar.Parent = self.baleLayer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = bar
		local stroke = Instance.new("UIStroke")
		stroke.Color = if fence.hedge then TileStyle.Board.hedgeEdge else Color3.fromRGB(70, 46, 22)
		stroke.Parent = bar
		self.fenceGuis[fence.x .. "," .. fence.y .. fence.side] = bar
	end
end

-- Numbers portal entrances 1, 2, ... in board order, so each pair gets its own colour.
function BoardView._portalIndex(self, board, entrance)
	if not self.portalIndex or self.portalIndexBoard ~= board then
		self.portalIndex = {}
		self.portalIndexBoard = board
		local n = 0
		board:eachCell(function(cell)
			if cell.portalOut then
				n += 1
				self.portalIndex[cell] = n
			end
		end)
	end
	return self.portalIndex[entrance] or 1
end

-- Snaps every tile, bale and mud patch to the engine's current state.
function BoardView.sync(self, game)
	local seen = {}
	self.grid = {}
	for y = 1, self.height do
		self.grid[y] = {}
	end
	game.board:eachCell(function(cell)
		self:_updateCell(cell.x, cell.y, cell)
		local piece = cell.piece
		if piece then
			seen[piece.id] = true
			local tile = self.tiles[piece.id]
			if tile then
				styleTile(tile, piece)
				tile.Position = self:_cellPosition(cell.x, cell.y)
			else
				self:_acquire(piece, cell.x, cell.y)
			end
			self.grid[cell.y][cell.x] = piece.id
		end
	end)
	for id in self.tiles do
		if not seen[id] then
			self:_release(id)
		end
	end
end

-- Animation ------------------------------------------------------------------

function BoardView._swap(self, phase)
	local x1, y1 = phase.from[1], phase.from[2]
	local x2, y2 = phase.to[1], phase.to[2]
	local a = self.tiles[self.grid[y1][x1]]
	local b = self.tiles[self.grid[y2][x2]]
	local p1, p2 = self:_cellPosition(x1, y1), self:_cellPosition(x2, y2)
	if phase.combo then
		if a then
			tween(a, SWAP_TIME, { Position = p2 })
		end
		task.wait(SWAP_TIME)
		return
	end
	if a then
		tween(a, SWAP_TIME, { Position = p2 })
	end
	if b then
		tween(b, SWAP_TIME, { Position = p1 })
	end
	task.wait(SWAP_TIME)
	if phase.ok then
		self.grid[y1][x1], self.grid[y2][x2] = self.grid[y2][x2], self.grid[y1][x1]
	else
		if a then
			tween(a, SWAP_TIME, { Position = p1 })
		end
		if b then
			tween(b, SWAP_TIME, { Position = p2 })
		end
		task.wait(SWAP_TIME)
	end
end

function BoardView._flash(self, position: UDim2, size: UDim2, color: Color3, round: boolean)
	local fx = Instance.new("Frame")
	fx.Name = "Flash"
	fx.AnchorPoint = Vector2.new(0.5, 0.5)
	fx.Position = position
	fx.Size = size
	fx.BackgroundColor3 = color
	fx.BackgroundTransparency = 0.25
	fx.BorderSizePixel = 0
	fx.Parent = self.fxLayer
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = fx
	end
	tween(fx, FX_TIME, { BackgroundTransparency = 1 })
	task.delay(FX_TIME, function()
		fx:Destroy()
	end)
end

function BoardView._centerOf(self, x: number, y: number): UDim2
	return UDim2.fromScale((x - 0.5) / self.width, (y - 0.5) / self.height)
end

function BoardView._effect(self, effect): number
	local w, h = self.width, self.height
	if effect.type == "Spray" then
		if effect.dir == "Row" then
			self:_flash(UDim2.fromScale(0.5, (effect.y - 0.5) / h), UDim2.fromScale(1, 0.6 / h), Color3.fromRGB(140, 220, 255), false)
		else
			self:_flash(UDim2.fromScale((effect.x - 0.5) / w, 0.5), UDim2.fromScale(0.6 / w, 1), Color3.fromRGB(140, 220, 255), false)
		end
		return FX_TIME
	elseif effect.type == "Bomb" then
		local r = effect.radius * 2 + 1
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(r / w, r / h), Color3.fromRGB(255, 170, 60), true)
		return FX_TIME
	elseif effect.type == "Pumpkin" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.3 / w, 1.3 / h), TileStyle.Pumpkin.color, true)
		return FX_TIME
	elseif effect.type == "Basket" then
		local label = self.basketGuis and self.basketGuis[effect.fromY * 100 + effect.fromX]
		if label then
			label.Rotation = -12
			tween(label, FX_TIME, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end
		self:_flash(self:_centerOf(effect.toX, effect.toY), UDim2.fromScale(1.1 / w, 1.1 / h), TileStyle.Pumpkin.color, true)
		return FX_TIME
	elseif effect.type == "Crate" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.4 / w, 1.4 / h), Color3.fromRGB(255, 220, 120), true)
		return FX_TIME
	elseif effect.type == "Patch" then
		-- A patch flies from the opened tin to its quilt cell.
		local patch = Instance.new("Frame")
		patch.Name = "Patch"
		patch.AnchorPoint = Vector2.new(0.5, 0.5)
		patch.Size = UDim2.fromScale(0.5 / w, 0.5 / h)
		patch.Position = self:_centerOf(effect.fromX, effect.fromY)
		patch.BackgroundColor3 = TileStyle.QuiltPatchColors[(effect.x + effect.y * 2) % #TileStyle.QuiltPatchColors + 1]
		patch.BorderSizePixel = 0
		patch.Parent = self.fxLayer
		tween(patch, BEE_TIME, { Position = self:_centerOf(effect.x, effect.y), Size = UDim2.fromScale(1 / w, 1 / h) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.delay(BEE_TIME, function()
			patch:Destroy()
		end)
		return BEE_TIME
	elseif effect.type == "Scarecrow" then
		local guis = self.cellGuis[effect.y] and self.cellGuis[effect.y][effect.x]
		if guis then
			guis.bale.Rotation = 15
			tween(guis.bale, FX_TIME, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(2 / w, 2 / h), TileStyle.Board.scarecrow, true)
		return FX_TIME
	elseif effect.type == "Lights" then
		-- The fireflies move: old spots go dark, new ones light up.
		for _, c in effect.changes do
			local spot = self.spotGuis[c.y * 100 + c.x]
			if spot then
				styleSpot(spot, c.lit)
				if c.lit then
					self:_flash(self:_centerOf(c.x, c.y), UDim2.fromScale(0.9 / w, 0.9 / h), TileStyle.Board.glow, true)
				end
			end
		end
		return FX_TIME
	elseif effect.type == "Catch" then
		-- Caught: the spot goes dark and the firefly floats off to the goal.
		local spot = self.spotGuis[effect.y * 100 + effect.x]
		if spot then
			styleSpot(spot, false)
		end
		local fly = Instance.new("TextLabel")
		fly.Name = "Firefly"
		fly.AnchorPoint = Vector2.new(0.5, 0.5)
		fly.BackgroundTransparency = 1
		fly.Size = UDim2.fromScale(0.7 / w, 0.7 / h)
		fly.Position = self:_centerOf(effect.x, effect.y)
		fly.Text = TileStyle.GoalGlyphs.Fireflies
		fly.TextScaled = true
		fly.Parent = self.fxLayer
		tween(fly, FX_TIME, { Position = self:_centerOf(effect.x, effect.y - 1.5), TextTransparency = 1 })
		task.delay(FX_TIME, function()
			fly:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Walk" then
		-- The lamb trots across into its new cell.
		local lamb = Instance.new("TextLabel")
		lamb.Name = "Walk"
		lamb.AnchorPoint = Vector2.new(0.5, 0.5)
		lamb.BackgroundTransparency = 1
		lamb.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		lamb.Position = self:_centerOf(effect.fromX, effect.fromY)
		lamb.Text = TileStyle.GoalGlyphs.Lambs
		lamb.TextScaled = true
		lamb.Parent = self.fxLayer
		tween(lamb, FX_TIME, { Position = self:_centerOf(effect.x, effect.y) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.delay(FX_TIME, function()
			lamb:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Home" then
		-- Home at last: the pen glows and the lamb skips off up the board.
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.4 / w, 1.4 / h), TileStyle.Board.pen, true)
		local lamb = Instance.new("TextLabel")
		lamb.Name = "Home"
		lamb.AnchorPoint = Vector2.new(0.5, 0.5)
		lamb.BackgroundTransparency = 1
		lamb.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		lamb.Position = self:_centerOf(effect.x, effect.y)
		lamb.Text = TileStyle.GoalGlyphs.Lambs
		lamb.TextScaled = true
		lamb.Parent = self.fxLayer
		tween(lamb, FX_TIME, { Position = self:_centerOf(effect.x, effect.y - 1.5), TextTransparency = 1 })
		task.delay(FX_TIME, function()
			lamb:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Crawl" then
		-- The snail slides across into its new cell.
		local snail = Instance.new("TextLabel")
		snail.Name = "Crawl"
		snail.AnchorPoint = Vector2.new(0.5, 0.5)
		snail.BackgroundTransparency = 1
		snail.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		snail.Position = self:_centerOf(effect.fromX, effect.fromY)
		snail.Text = TileStyle.SnailGlyph
		snail.TextScaled = true
		snail.Parent = self.fxLayer
		tween(snail, FX_TIME, { Position = self:_centerOf(effect.x, effect.y) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.delay(FX_TIME, function()
			snail:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Drop" then
		-- A bale tumbles off the truck into its new cell.
		local bale = Instance.new("TextLabel")
		bale.Name = "DroppedBale"
		bale.AnchorPoint = Vector2.new(0.5, 0.5)
		bale.BackgroundTransparency = 1
		bale.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		bale.Position = self:_centerOf(effect.fromX, effect.fromY)
		bale.Text = TileStyle.GoalGlyphs.HayBale
		bale.TextScaled = true
		bale.Parent = self.fxLayer
		tween(bale, FX_TIME, { Position = self:_centerOf(effect.x, effect.y), Rotation = 180 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(FX_TIME, function()
			bale:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Bloom" then
		-- The bud bursts open and a tulip floats up off it.
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.4 / w, 1.4 / h), TileStyle.Board.budLit, true)
		local flower = Instance.new("TextLabel")
		flower.Name = "Bloom"
		flower.AnchorPoint = Vector2.new(0.5, 0.5)
		flower.BackgroundTransparency = 1
		flower.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		flower.Position = self:_centerOf(effect.x, effect.y)
		flower.Text = TileStyle.GoalGlyphs.Blooms
		flower.TextScaled = true
		flower.Parent = self.fxLayer
		tween(flower, FX_TIME, { Position = self:_centerOf(effect.x, effect.y - 1.5), TextTransparency = 1 })
		task.delay(FX_TIME, function()
			flower:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Wilt" then
		-- The bud closes up again: it droops and loses its charge.
		local guis = self.cellGuis[effect.y] and self.cellGuis[effect.y][effect.x]
		if guis then
			guis.bale.Rotation = -15
			tween(guis.bale, FX_TIME, { Rotation = 0 }, Enum.EasingStyle.Bounce)
		end
		return FX_TIME
	elseif effect.type == "Honey" then
		-- The hive wobbles and a jar of honey floats up off it.
		local guis = self.cellGuis[effect.y] and self.cellGuis[effect.y][effect.x]
		if guis then
			guis.bale.Rotation = 10
			tween(guis.bale, FX_TIME, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end
		local jar = Instance.new("TextLabel")
		jar.Name = "HoneyJar"
		jar.AnchorPoint = Vector2.new(0.5, 0.5)
		jar.BackgroundTransparency = 1
		jar.Size = UDim2.fromScale(0.7 / w, 0.7 / h)
		jar.Position = self:_centerOf(effect.x, effect.y)
		jar.Text = TileStyle.GoalGlyphs.Honey
		jar.TextScaled = true
		jar.Parent = self.fxLayer
		tween(jar, FX_TIME, { Position = self:_centerOf(effect.x, effect.y - 1.5), TextTransparency = 1 })
		task.delay(FX_TIME, function()
			jar:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Box" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.2 / w, 1.2 / h), TileStyle.Board.box, true)
		return FX_TIME
	elseif effect.type == "Hop" then
		-- The rest of the stack jumps across to its new cell.
		local stack = Instance.new("TextLabel")
		stack.Name = "Hop"
		stack.AnchorPoint = Vector2.new(0.5, 0.5)
		stack.BackgroundTransparency = 1
		stack.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		stack.Position = self:_centerOf(effect.fromX, effect.fromY)
		stack.Text = TileStyle.GoalGlyphs.Boxes
		stack.TextScaled = true
		stack.Parent = self.fxLayer
		tween(stack, FX_TIME, { Position = self:_centerOf(effect.x, effect.y) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.delay(FX_TIME, function()
			stack:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Spill" then
		-- The bucket tips over and mud splashes onto the cells around it.
		local bucket = Instance.new("TextLabel")
		bucket.Name = "Bucket"
		bucket.AnchorPoint = Vector2.new(0.5, 0.5)
		bucket.BackgroundTransparency = 1
		bucket.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		bucket.Position = self:_centerOf(effect.x, effect.y)
		bucket.Text = TileStyle.BucketGlyph
		bucket.TextScaled = true
		bucket.Parent = self.fxLayer
		tween(bucket, FX_TIME, { Rotation = 100, TextTransparency = 1 })
		task.delay(FX_TIME, function()
			bucket:Destroy()
		end)
		for _, c in effect.cells do
			self:_flash(self:_centerOf(c.x, c.y), UDim2.fromScale(1.1 / w, 1.1 / h), TileStyle.Board.mud, true)
		end
		return FX_TIME
	elseif effect.type == "Mailbox" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.2 / w, 1.2 / h), TileStyle.Board.mailbox, true)
		return FX_TIME
	elseif effect.type == "Letter" then
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.AnchorPoint = Vector2.new(0.5, 0.5)
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		letter.Position = self:_centerOf(effect.x, effect.y)
		letter.Text = TileStyle.GoalGlyphs.Letters
		letter.TextScaled = true
		letter.Parent = self.fxLayer
		tween(letter, FX_TIME, { Position = self:_centerOf(effect.x, effect.y - 1.5), TextTransparency = 1 })
		task.delay(FX_TIME, function()
			letter:Destroy()
		end)
		return FX_TIME
	elseif effect.type == "Sow" then
		local guis = self.cellGuis[effect.fromY] and self.cellGuis[effect.fromY][effect.fromX]
		if guis then
			guis.bale.Rotation = -12
			tween(guis.bale, FX_TIME, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end
		for _, c in effect.cells do
			self:_flash(self:_centerOf(c.x, c.y), UDim2.fromScale(1.1 / w, 1.1 / h), TileStyle.Board.clover, true)
		end
		return FX_TIME
	elseif effect.type == "Quilt" then
		for _, c in effect.cells do
			self:_flash(self:_centerOf(c.x, c.y), UDim2.fromScale(1.3 / w, 1.3 / h), TileStyle.Board.quilt, true)
		end
		return FX_TIME
	elseif effect.type == "Roll" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.2 / w, 1.2 / h), TileStyle.Board.tarp, true)
		return FX_TIME
	elseif effect.type == "Statue" then
		for _, c in effect.cells do
			self:_flash(self:_centerOf(c.x, c.y), UDim2.fromScale(1.3 / w, 1.3 / h), TileStyle.Board.buried, true)
		end
		return FX_TIME
	elseif effect.type == "Ooze" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.1 / w, 1.1 / h), TileStyle.Board.goo, true)
		return FX_TIME
	elseif effect.type == "Grow" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.1 / w, 1.1 / h), TileStyle.Board.weed, true)
		return FX_TIME
	elseif effect.type == "Trowel" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(1.2 / w, 1.2 / h), Color3.fromRGB(255, 255, 255), true)
		return FX_TIME
	elseif effect.type == "Sun" or effect.type == "Everything" then
		self:_flash(self:_centerOf(effect.x, effect.y), UDim2.fromScale(3 / w, 3 / h), Color3.fromRGB(255, 230, 90), true)
		return FX_TIME
	elseif effect.type == "Bee" then
		local bee = Instance.new("TextLabel")
		bee.Name = "Bee"
		bee.AnchorPoint = Vector2.new(0.5, 0.5)
		bee.BackgroundTransparency = 1
		bee.Size = UDim2.fromScale(0.8 / w, 0.8 / h)
		bee.Position = self:_centerOf(effect.fromX, effect.fromY)
		bee.Text = TileStyle.PowerBadges.Bumblebee
		bee.TextScaled = true
		bee.Parent = self.fxLayer
		tween(bee, BEE_TIME, { Position = self:_centerOf(effect.toX, effect.toY) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.delay(BEE_TIME, function()
			bee:Destroy()
		end)
		return BEE_TIME
	end
	return 0
end

function BoardView._pop(self, phase)
	for _, t in phase.transformed do
		local tile = self.tiles[t.id]
		if tile then
			local badge = tile:FindFirstChild("Badge") :: TextLabel
			badge.Visible = true
			badge.Text = TileStyle.PowerBadges[t.power] or ""
		end
	end

	local fxTime = 0
	for _, effect in phase.effects do
		fxTime = math.max(fxTime, self:_effect(effect))
	end

	for _, r in phase.removed do
		local tile = self.tiles[r.id]
		if tile then
			local face = tile:FindFirstChild("Face") :: TextLabel
			tween(face, POP_TIME, { Size = UDim2.fromScale(0, 0), Rotation = 25 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
		if self.grid[r.y] and self.grid[r.y][r.x] == r.id then
			self.grid[r.y][r.x] = nil
		end
	end
	-- Patches first: a quilt finished this wave then lifts off with its bales.
	for _, q in phase.quilts or {} do
		local guis = self.cellGuis[q.y] and self.cellGuis[q.y][q.x]
		if guis then
			styleBale(guis.bale, 1, { quilt = true, patched = true, x = q.x, y = q.y })
		end
	end
	for _, b in phase.bales do
		local guis = self.cellGuis[b.y] and self.cellGuis[b.y][b.x]
		if guis then
			styleBale(guis.bale, b.hp, b)
		end
	end
	for _, c in phase.clay or {} do
		local guis = self.cellGuis[c.y] and self.cellGuis[c.y][c.x]
		if guis then
			styleClay(guis, c.layers)
		end
	end
	for _, m in phase.mud do
		local guis = self.cellGuis[m.y] and self.cellGuis[m.y][m.x]
		if guis then
			guis.mud.Visible = m.layers > 0
			guis.mud.BackgroundTransparency = if m.layers >= 2 then 0.15 else 0.45
		end
	end
	for _, f in phase.frost or {} do
		local guis = self.cellGuis[f.y] and self.cellGuis[f.y][f.x]
		if guis then
			styleFrost(guis, f.layers)
		end
	end
	for _, c in phase.clover or {} do
		local guis = self.cellGuis[c.y] and self.cellGuis[c.y][c.x]
		if guis then
			guis.clover.Visible = true
		end
	end
	for _, g in phase.goo or {} do
		local guis = self.cellGuis[g.y] and self.cellGuis[g.y][g.x]
		if guis then
			guis.goo.Visible = g.on
			guis.goo.BackgroundColor3 = if g.thick then TileStyle.Board.thickGoo else TileStyle.Board.goo
		end
	end
	for _, wb in phase.webs or {} do
		local guis = self.cellGuis[wb.y] and self.cellGuis[wb.y][wb.x]
		if guis then
			tween(guis.web, POP_TIME, { BackgroundTransparency = 1, TextTransparency = 1 })
			task.delay(POP_TIME, function()
				guis.web.Visible = false
				guis.web.BackgroundTransparency = 0.55
				guis.web.TextTransparency = 0.1
			end)
		end
	end
	for _, d in phase.statues or {} do
		local guis = self.cellGuis[d.y] and self.cellGuis[d.y][d.x]
		if guis then
			guis.buried.Visible = false
			guis.statueMark.Visible = false
		end
	end
	for _, f in phase.fences or {} do
		local bar = self.fenceGuis and self.fenceGuis[f.x .. "," .. f.y .. f.side]
		if bar then
			self.fenceGuis[f.x .. "," .. f.y .. f.side] = nil
			tween(bar, POP_TIME, { BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0) })
			task.delay(POP_TIME, function()
				bar:Destroy()
			end)
		end
	end

	task.wait(math.max(POP_TIME, fxTime))
	for _, r in phase.removed do
		self:_release(r.id)
	end

	if #phase.created > 0 then
		for _, c in phase.created do
			local tile = self:_acquire(c.piece, c.x, c.y)
			local face = tile:FindFirstChild("Face") :: TextLabel
			face.Size = UDim2.fromScale(0, 0)
			tween(face, CREATE_TIME, { Size = UDim2.fromScale(FACE_SIZE, FACE_SIZE) }, Enum.EasingStyle.Back)
			self.grid[c.y][c.x] = c.piece.id
		end
		task.wait(CREATE_TIME)
	end
end

local function fallTime(fromY: number, toY: number, fromX: number, toX: number): number
	local cells = math.max(math.abs(toY - fromY), math.abs(toX - fromX))
	return math.max(MIN_FALL_TIME, cells * FALL_TIME_PER_CELL)
end

function BoardView._drop(self, phase)
	local longest = 0
	for _, m in phase.moves do
		if self.grid[m.fromY] and self.grid[m.fromY][m.fromX] == m.id then
			self.grid[m.fromY][m.fromX] = nil
		end
	end
	for _, m in phase.moves do
		local tile = self.tiles[m.id]
		if tile then
			local t = fallTime(m.fromY, m.toY, m.fromX, m.toX)
			longest = math.max(longest, t)
			tween(tile, t, { Position = self:_cellPosition(m.toX, m.toY) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		self.grid[m.toY][m.toX] = m.id
	end
	for _, s in phase.spawns do
		local tile = self:_acquire(s.piece, s.fromX, s.fromY)
		local t = fallTime(s.fromY, s.toY, s.fromX, s.toX)
		longest = math.max(longest, t)
		tween(tile, t, { Position = self:_cellPosition(s.toX, s.toY) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		self.grid[s.toY][s.toX] = s.piece.id
	end
	task.wait(longest)
end

function BoardView._shuffle(self, phase)
	for y = 1, self.height do
		self.grid[y] = {}
	end
	for _, m in phase.moves do
		local tile = self.tiles[m.id]
		if tile then
			tween(tile, SHUFFLE_TIME, { Position = self:_cellPosition(m.toX, m.toY) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
		self.grid[m.toY][m.toX] = m.id
	end
	task.wait(SHUFFLE_TIME)
end

-- Rainbow patches: tiles turn to their new colour with a little spin.
function BoardView._recolor(self, phase)
	for _, c in phase.changes do
		local tile = self.tiles[c.id]
		if tile then
			styleTile(tile, { color = c.color, timer = c.timer })
			local face = tile:FindFirstChild("Face") :: TextLabel
			face.Rotation = -90
			tween(face, POP_TIME, { Rotation = 0 }, Enum.EasingStyle.Back)
		end
	end
	task.wait(POP_TIME)
end

-- Snowball timers tick down; one that bursts flashes (its frost comes in the next Pop).
function BoardView._tick(self, phase)
	for _, t in phase.timers do
		local tile = self.tiles[t.id]
		if tile then
			styleTimer(tile, t.timer)
			if t.burst then
				self:_flash(self:_centerOf(t.x, t.y), UDim2.fromScale(3 / self.width, 3 / self.height), TileStyle.Board.frost, true)
			end
		end
	end
	task.wait(POP_TIME / 2)
end

-- Plays the phases from Engine:trySwap in order. Yields.
function BoardView.play(self, phases)
	local pops = 0 -- cascades pop higher (Sfx)
	for _, phase in phases do
		if phase.kind == "Pop" then
			pops += 1
		end
		Sfx.phase(phase, pops)
		if phase.kind == "Swap" then
			self:_swap(phase)
		elseif phase.kind == "Pop" then
			self:_pop(phase)
		elseif phase.kind == "Drop" then
			self:_drop(phase)
		elseif phase.kind == "Shuffle" then
			self:_shuffle(phase)
		elseif phase.kind == "Recolor" then
			self:_recolor(phase)
		elseif phase.kind == "Tick" then
			self:_tick(phase)
		end
	end
end

-- Input ----------------------------------------------------------------------

function BoardView.clearSelection(self)
	self.selected = nil
	self.selection.Visible = false
end

function BoardView._select(self, x: number, y: number)
	self.selected = { x = x, y = y }
	self.selection.Size = self:_cellSize()
	self.selection.Position = self:_cellPosition(x, y)
	self.selection.Visible = true
end

function BoardView._request(self, x1: number, y1: number, x2: number, y2: number)
	self:clearSelection()
	if x2 < 1 or y2 < 1 or x2 > self.width or y2 > self.height then
		return
	end
	self.onSwap(x1, y1, x2, y2)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function BoardView._makeHitButton(self, x: number, y: number)
	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.Text = ""
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Size = self:_cellSize()
	button.Position = self:_cellPosition(x, y)
	button.Parent = self.hitLayer
	button.InputBegan:Connect(function(input)
		if self.enabled and isPress(input) and self.cellTarget then
			self.cellTarget(x, y)
			return
		end
		if self.enabled and isPress(input) then
			self.drag = { x = x, y = y, start = input.Position, input = input }
		end
	end)
end

function BoardView._bindInput(self)
	table.insert(
		self.connections,
		UserInputService.InputChanged:Connect(function(input)
			local drag = self.drag
			if not drag then
				return
			end
			local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
			if not (isMouse or input == drag.input) then
				return
			end
			local delta = input.Position - drag.start
			local cellPixels = self.frame.AbsoluteSize.X / self.width
			local threshold = math.max(4, cellPixels * SWIPE_THRESHOLD)
			if math.max(math.abs(delta.X), math.abs(delta.Y)) < threshold then
				return
			end
			self.drag = nil
			local dx, dy = 0, 0
			if math.abs(delta.X) > math.abs(delta.Y) then
				dx = if delta.X > 0 then 1 else -1
			else
				dy = if delta.Y > 0 then 1 else -1
			end
			self:_request(drag.x, drag.y, drag.x + dx, drag.y + dy)
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input)
			local drag = self.drag
			if not drag or not (input.UserInputType == Enum.UserInputType.MouseButton1 or input == drag.input) then
				return
			end
			self.drag = nil
			-- A tap: select, or swap with the selected neighbour.
			local selected = self.selected
			if selected and math.abs(selected.x - drag.x) + math.abs(selected.y - drag.y) == 1 then
				self:_request(selected.x, selected.y, drag.x, drag.y)
			elseif selected and selected.x == drag.x and selected.y == drag.y then
				self:clearSelection()
			else
				self:_select(drag.x, drag.y)
			end
		end)
	)
end

-- Boosters that pick a cell (Trowel, Rake): taps go to fn(x, y) until cleared with nil.
function BoardView.setCellTarget(self, fn: ((number, number) -> ())?)
	self.cellTarget = fn
	self.drag = nil
	self:clearSelection()
	self.targetStroke.Enabled = fn ~= nil
end

function BoardView.setEnabled(self, enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self.drag = nil
		self:clearSelection()
	end
end

function BoardView.destroy(self)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.connections = {}
	self.frame:Destroy()
end

return BoardView

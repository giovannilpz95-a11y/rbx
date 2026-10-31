--[[
	Crop Pop match finding.

	A match is a line of 3+ same-colour tiles, or a 2x2 square. Lines and squares
	that share tiles join into one group, and each group can make one power-up:

	  5+ in a line          -> Sunflower
	  T or L shape          -> Hay Bomb
	  4 in a line           -> Seed Sprayer (a row of 4 makes a row sprayer, a column of 4 a column sprayer)
	  2x2 square            -> Bumblebee

	Holes, hay bales, weeds, pumpkins and Sunflowers never match. Frosted tiles match
	(that's how the frost breaks) but can't be swapped.
]]

local Tiles = require(script.Parent.Tiles)

local Power = Tiles.Power

local Matcher = {}

export type Group = {
	color: number,
	cells: { any }, -- Board cells, row-major order
	power: string?,
	at: any?, -- the cell the power-up appears on
}

local function colorAt(board, x: number, y: number): number
	local cell = board:get(x, y)
	if cell == nil or cell.bale > 0 then
		return 0
	end
	local piece = cell.piece
	return if piece then piece.color else 0
end
Matcher.colorAt = colorAt

local function isMovable(cell): boolean
	return cell ~= nil and cell.piece ~= nil and cell.bale == 0 and cell.frost == 0
end

local function scanRuns(board, runs, dir: string)
	local outer = if dir == "H" then board.height else board.width
	local inner = if dir == "H" then board.width else board.height
	local function at(o, i)
		if dir == "H" then
			return i, o
		end
		return o, i
	end
	for o = 1, outer do
		local i = 1
		while i <= inner do
			local x, y = at(o, i)
			local color = colorAt(board, x, y)
			local len = 1
			if color > 0 then
				while i + len <= inner do
					local nx, ny = at(o, i + len)
					if colorAt(board, nx, ny) ~= color then
						break
					end
					len += 1
				end
				if len >= 3 then
					local cells = table.create(len)
					for k = 0, len - 1 do
						local cx, cy = at(o, i + k)
						table.insert(cells, board:get(cx, cy))
					end
					table.insert(runs, { dir = dir, color = color, cells = cells })
				end
			end
			i += len
		end
	end
end

--[[
	Finds every match on the board. `preferred` lists cells (in priority order)
	where a power-up should appear if a group covers them, such as the two
	swapped cells or the cells where pieces just landed.
]]
function Matcher.findGroups(board, preferred: { any }): { Group }
	local width = board.width
	local function key(cell)
		return (cell.y - 1) * width + cell.x
	end

	local runs = {}
	scanRuns(board, runs, "H")
	scanRuns(board, runs, "V")

	local squares = {}
	for y = 1, board.height - 1 do
		for x = 1, width - 1 do
			local color = colorAt(board, x, y)
			if
				color > 0
				and colorAt(board, x + 1, y) == color
				and colorAt(board, x, y + 1) == color
				and colorAt(board, x + 1, y + 1) == color
			then
				table.insert(squares, {
					color = color,
					cells = { board:get(x, y), board:get(x + 1, y), board:get(x, y + 1), board:get(x + 1, y + 1) },
				})
			end
		end
	end

	if #runs == 0 and #squares == 0 then
		return {}
	end

	-- Union-find over cell keys; the root of a set is always its smallest key.
	local parent = {}
	local function find(k)
		while parent[k] ~= k do
			parent[k] = parent[parent[k]]
			k = parent[k]
		end
		return k
	end
	local function join(shape)
		local first = key(shape.cells[1])
		if parent[first] == nil then
			parent[first] = first
		end
		for _, cell in shape.cells do
			local k = key(cell)
			if parent[k] == nil then
				parent[k] = k
			end
			local a, b = find(first), find(k)
			if a ~= b then
				if a < b then
					parent[b] = a
				else
					parent[a] = b
				end
			end
		end
	end
	for _, run in runs do
		join(run)
	end
	for _, square in squares do
		join(square)
	end

	-- Build groups in row-major order of their first cell.
	local groups: { Group } = {}
	local infos = {}
	local byRoot = {}
	for k = 1, width * board.height do
		if parent[k] ~= nil then
			local root = find(k)
			local info = byRoot[root]
			if not info then
				info = { group = { color = 0, cells = {} }, members = {}, runs = {}, squares = {} }
				byRoot[root] = info
				table.insert(infos, info)
				table.insert(groups, info.group)
			end
			local x = (k - 1) % width + 1
			local y = (k - x) // width + 1
			local cell = board:get(x, y)
			table.insert(info.group.cells, cell)
			info.members[k] = true
			info.group.color = cell.piece.color
		end
	end
	for _, run in runs do
		table.insert(byRoot[find(key(run.cells[1]))].runs, run)
	end
	for _, square in squares do
		table.insert(byRoot[find(key(square.cells[1]))].squares, square)
	end

	for _, info in infos do
		local group = info.group
		local longest, maxLen = nil, 0
		for _, run in info.runs do
			if #run.cells > maxLen then
				longest, maxLen = run, #run.cells
			end
		end

		local cross = nil
		for _, a in info.runs do
			if a.dir == "H" and not cross then
				local inA = {}
				for _, cell in a.cells do
					inA[key(cell)] = true
				end
				for _, b in info.runs do
					if b.dir == "V" then
						for _, cell in b.cells do
							if inA[key(cell)] then
								cross = cell
								break
							end
						end
					end
					if cross then
						break
					end
				end
			end
		end

		if maxLen >= 5 then
			group.power = Power.Sunflower
		elseif cross then
			group.power = Power.HayBomb
		elseif maxLen == 4 then
			group.power = if longest.dir == "H" then Power.SprayerRow else Power.SprayerColumn
		elseif #info.squares > 0 then
			group.power = Power.Bumblebee
		end

		if group.power then
			for _, cell in preferred do
				if info.members[key(cell)] then
					group.at = cell
					break
				end
			end
			if not group.at then
				if group.power == Power.HayBomb then
					group.at = cross
				elseif longest and group.power ~= Power.Bumblebee then
					group.at = longest.cells[math.ceil(#longest.cells / 2)]
				else
					-- Lowest row, then leftmost.
					local best = group.cells[1]
					for _, cell in group.cells do
						if cell.y > best.y or (cell.y == best.y and cell.x < best.x) then
							best = cell
						end
					end
					group.at = best
				end
			end
			-- A frosted tile keeps its piece, so the power-up goes on a free one.
			if group.at.frost > 0 then
				for _, cell in group.cells do
					if cell.frost == 0 then
						group.at = cell
						break
					end
				end
			end
		end
	end

	return groups
end

-- True if the tile at (x, y) is part of a line of 3 or a 2x2 square.
function Matcher.hasMatchAt(board, x: number, y: number): boolean
	local color = colorAt(board, x, y)
	if color == 0 then
		return false
	end
	local function count(dx, dy)
		local n = 0
		local cx, cy = x + dx, y + dy
		while colorAt(board, cx, cy) == color do
			n += 1
			cx += dx
			cy += dy
		end
		return n
	end
	if count(-1, 0) + count(1, 0) >= 2 or count(0, -1) + count(0, 1) >= 2 then
		return true
	end
	for _, offset in { { 0, 0 }, { -1, 0 }, { 0, -1 }, { -1, -1 } } do
		local ox, oy = x + offset[1], y + offset[2]
		if
			colorAt(board, ox, oy) == color
			and colorAt(board, ox + 1, oy) == color
			and colorAt(board, ox, oy + 1) == color
			and colorAt(board, ox + 1, oy + 1) == color
		then
			return true
		end
	end
	return false
end

-- True if swapping these two cells would do something (match, combo or Sunflower).
function Matcher.isUsefulSwap(board, a, b): boolean
	local p, q = a.piece, b.piece
	if p.power and q.power then
		return true
	end
	if p.power == Power.Sunflower or q.power == Power.Sunflower then
		return true
	end
	a.piece, b.piece = q, p
	local hit = Matcher.hasMatchAt(board, a.x, a.y) or Matcher.hasMatchAt(board, b.x, b.y)
	a.piece, b.piece = p, q
	return hit
end

-- Every useful swap as { x1, y1, x2, y2 }, in row-major order.
function Matcher.listPossibleMoves(board, limit: number?): { { number } }
	local moves = {}
	for y = 1, board.height do
		for x = 1, board.width do
			local cell = board:get(x, y)
			if isMovable(cell) then
				for _, d in { { 1, 0 }, { 0, 1 } } do
					local other = board:get(x + d[1], y + d[2])
					if isMovable(other) and not board:fenceBetween(x, y, x + d[1], y + d[2]) and Matcher.isUsefulSwap(board, cell, other) then
						table.insert(moves, { x, y, x + d[1], y + d[2] })
						if limit and #moves >= limit then
							return moves
						end
					end
				end
			end
		end
	end
	return moves
end

function Matcher.hasPossibleMove(board): boolean
	return #Matcher.listPossibleMoves(board, 1) > 0
end

return Matcher

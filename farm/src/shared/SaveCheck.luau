--!strict
-- Can this profile be written to a DataStore as is? (Design/09 Roblox Architecture §12,
-- data safety.) DataStores keep JSON, so a value that JSON can't hold either fails the
-- save or comes back changed on the next load. Checked: tables are either arrays
-- (keys 1..n, no holes) or dictionaries with string keys, never both; numbers are finite;
-- only strings, numbers, booleans and tables; no cycles; size under the 4 MB limit.
-- Pure, so Lune tests run it on played-farm fixtures.

local SaveCheck = {}

SaveCheck.maxBytes = 4_000_000
SaveCheck.maxDepth = 32

local function describe(path: { string }): string
	return if #path == 0 then "(root)" else table.concat(path, ".")
end

local function isArray(t: { [any]: any }): (boolean, boolean)
	-- returns (looksLikeArray, isMixedOrHoley)
	local count, numeric, maxIndex = 0, 0, 0
	for key in t do
		count += 1
		if type(key) == "number" then
			numeric += 1
			if key % 1 == 0 and key > maxIndex then
				maxIndex = key
			end
		end
	end
	if numeric == 0 then
		return false, false
	end
	return true, numeric ~= count or maxIndex ~= count
end

-- Returns true, or false with the first bad path and why
function SaveCheck.check(value: any): (boolean, string?)
	local onPath: { [any]: boolean } = {} -- tables being walked: seeing one again is a cycle
	local path: { string } = {}
	local problem: string? = nil

	local function walk(v: any, depth: number): boolean
		local kind = type(v)
		if kind == "number" then
			if v ~= v or v == math.huge or v == -math.huge then
				problem = describe(path) .. ": number is NaN or infinite"
				return false
			end
			return true
		elseif kind == "string" or kind == "boolean" then
			return true
		elseif kind ~= "table" then
			problem = describe(path) .. ": can't store a " .. typeof(v)
			return false
		end
		if onPath[v] then
			problem = describe(path) .. ": the table contains itself"
			return false
		end
		if depth > SaveCheck.maxDepth then
			problem = describe(path) .. ": nested too deep"
			return false
		end
		onPath[v] = true
		local array, bad = isArray(v)
		if bad then
			problem = describe(path) .. ": array with holes or mixed with string keys"
			return false
		end
		for key, child in v do
			if not array and type(key) ~= "string" then
				problem = describe(path) .. ": key " .. tostring(key) .. " is not a string"
				return false
			end
			table.insert(path, tostring(key))
			local ok = walk(child, depth + 1)
			table.remove(path)
			if not ok then
				return false
			end
		end
		onPath[v] = nil
		return true
	end

	if not walk(value, 1) then
		return false, problem
	end
	local bytes = SaveCheck.size(value)
	if bytes > SaveCheck.maxBytes then
		return false, string.format("(root): about %d bytes, over the %d limit", bytes, SaveCheck.maxBytes)
	end
	return true, nil
end

-- Rough JSON size in bytes, for the 4 MB limit (strings counted with their quotes)
function SaveCheck.size(value: any): number
	local kind = type(value)
	if kind == "string" then
		return #value + 2
	elseif kind == "number" then
		return #tostring(value)
	elseif kind == "boolean" then
		return if value then 4 else 5
	elseif kind == "table" then
		local total = 2
		for key, child in value do
			total += SaveCheck.size(child) + 1
			if type(key) == "string" then
				total += #key + 3
			end
		end
		return total
	end
	return 4
end

return SaveCheck

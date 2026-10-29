--[[
	Loads src/shared outside Roblox for tool scripts, by giving each module a
	`script` whose Parent finds its siblings (so require(script.Parent.X) and
	require(script.Child) both work). Run tools from the croppop/ folder with
	the luaurun host.
]]

local cache = {}

local function exists(path)
	return (pcall(readfile, path))
end

local function folderOf(dir)
	return setmetatable({}, {
		__index = function(_, name)
			return function()
				local key = dir .. name
				local found = cache[key]
				if found ~= nil then
					return found
				end
				local path = dir .. name .. ".luau"
				local childDir = dir .. name .. "/"
				if not exists(path) then
					path = childDir .. "init.luau"
				end
				local script = setmetatable({ Name = name, Parent = folderOf(dir) }, { __index = folderOf(childDir) })
				local env = setmetatable({
					script = script,
					require = function(m)
						return m()
					end,
				}, { __index = _G })
				local result = loadmodule(readfile(path), path, env)()
				cache[key] = result
				return result
			end
		end,
	})
end

local shared = folderOf("src/shared/")

return function(name)
	return shared[name]()
end

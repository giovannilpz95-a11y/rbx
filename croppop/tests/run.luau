--[[
	Crop Pop test runner. Run from the croppop/ folder:

		cargo run --release --manifest-path tools/luaurun/Cargo.toml -- tests/run.luau

	Builds a fake Roblox instance tree from src/ the way Rojo would (folders,
	init.luau, .server.luau / .client.luau), so modules can keep using
	`require(script.Parent.X)`. Then compiles every source file and runs
	every tests/*.spec.luau file.
]]

local ROOT = ARGS[1] or "."

-- Fake instances -------------------------------------------------------------

local Methods = {}
local InstanceMeta = {}

InstanceMeta.__index = function(self, key)
	local method = Methods[key]
	if method then
		return method
	end
	local child = rawget(self, "_children")[key]
	if child then
		return child
	end
	error(tostring(key) .. " is not a valid member of " .. rawget(self, "Name"), 2)
end
InstanceMeta.__tostring = function(self)
	return rawget(self, "Name")
end

function Methods.FindFirstChild(self, name)
	return rawget(self, "_children")[name]
end
Methods.WaitForChild = Methods.FindFirstChild
function Methods.GetService(self, name)
	return rawget(self, "_children")[name] or error("no service " .. name)
end
function Methods.GetChildren(self)
	local out = {}
	for _, child in rawget(self, "_order") do
		table.insert(out, child)
	end
	return out
end
function Methods.GetFullName(self)
	local parent = rawget(self, "Parent")
	if parent then
		return parent:GetFullName() .. "." .. rawget(self, "Name")
	end
	return rawget(self, "Name")
end

local function makeInstance(name, className, path, parent)
	local inst = setmetatable({
		Name = name,
		ClassName = className,
		Parent = parent,
		_path = path,
		_children = {},
		_order = {},
	}, InstanceMeta)
	if parent then
		rawget(parent, "_children")[name] = inst
		table.insert(rawget(parent, "_order"), inst)
	end
	return inst
end

local SCRIPT_SUFFIXES = {
	{ ".server.luau", "Script" },
	{ ".client.luau", "LocalScript" },
	{ ".luau", "ModuleScript" },
}

local function classify(fileName)
	for _, entry in SCRIPT_SUFFIXES do
		local suffix = entry[1]
		if string.sub(fileName, -#suffix) == suffix then
			return string.sub(fileName, 1, -#suffix - 1), entry[2]
		end
	end
	return nil
end

local function buildDir(path, name, parent)
	local entries = listdir(path)
	local initPath, initClass = nil, "Folder"
	for _, e in entries do
		if not e.dir then
			local base, class = classify(e.name)
			if base == "init" then
				initPath, initClass = path .. "/" .. e.name, class
			end
		end
	end
	local inst = makeInstance(name, initClass, initPath, parent)
	for _, e in entries do
		local childPath = path .. "/" .. e.name
		if e.dir then
			buildDir(childPath, e.name, inst)
		else
			local base, class = classify(e.name)
			if base and base ~= "init" then
				makeInstance(base, class, childPath, inst)
			end
		end
	end
	return inst
end

-- require() for fake instances ------------------------------------------------

local cache = {}
local loading = {}
local game -- set below

local function requireModule(target)
	if type(target) ~= "table" or getmetatable(target) ~= InstanceMeta then
		error("require expects a ModuleScript, got " .. tostring(target), 2)
	end
	local found = cache[target]
	if found ~= nil then
		return found
	end
	if loading[target] then
		error("circular require of " .. target:GetFullName(), 2)
	end
	local path = rawget(target, "_path")
	assert(path and rawget(target, "ClassName") == "ModuleScript", target:GetFullName() .. " is not a ModuleScript")
	loading[target] = true
	local env = setmetatable({ script = target, require = requireModule, game = game }, { __index = _G })
	local result = loadmodule(readfile(path), path, env)()
	loading[target] = nil
	if result == nil then
		error(target:GetFullName() .. " did not return a value")
	end
	cache[target] = result
	return result
end

-- The Rojo tree ---------------------------------------------------------------

game = makeInstance("game", "DataModel", nil, nil)
local ReplicatedStorage = makeInstance("ReplicatedStorage", "ReplicatedStorage", nil, game)
local ServerScriptService = makeInstance("ServerScriptService", "ServerScriptService", nil, game)
local StarterPlayerScripts = makeInstance("StarterPlayerScripts", "StarterPlayerScripts", nil, game)
buildDir(ROOT .. "/src/shared", "CropPop", ReplicatedStorage)
buildDir(ROOT .. "/src/server", "CropPopServer", ServerScriptService)
buildDir(ROOT .. "/src/client", "CropPopClient", StarterPlayerScripts)

-- Syntax check every file, including client code that can't run here.
local compileErrors = 0
local function compileTree(path)
	for _, e in listdir(path) do
		local childPath = path .. "/" .. e.name
		if e.dir then
			compileTree(childPath)
		elseif string.sub(e.name, -5) == ".luau" then
			local ok, err = compile(readfile(childPath), childPath)
			if not ok then
				compileErrors += 1
				print("COMPILE ERROR " .. tostring(err))
			end
		end
	end
end
compileTree(ROOT .. "/src")
compileTree(ROOT .. "/tests")

-- Tiny test framework ---------------------------------------------------------

local passed, failed = 0, 0
local currentFile = ""

local function test(name, fn)
	local started = clock()
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	local ms = math.floor((clock() - started) * 1000)
	if ok then
		passed += 1
		print(string.format("  ok   %s (%dms)", name, ms))
	else
		failed += 1
		print(string.format("  FAIL %s\n%s", name, err))
	end
end

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local expect = {}
function expect.eq(actual, expected, message)
	if actual ~= expected then
		error(string.format("%sexpected %s, got %s", if message then message .. ": " else "", fmt(expected), fmt(actual)), 2)
	end
end
function expect.truthy(value, message)
	if not value then
		error((message or "expected a truthy value") .. ", got " .. fmt(value), 2)
	end
end
function expect.falsy(value, message)
	if value then
		error((message or "expected a falsy value") .. ", got " .. fmt(value), 2)
	end
end

local CropPop = requireModule(ReplicatedStorage.CropPop)
local Helpers = loadmodule(readfile(ROOT .. "/tests/helpers.luau"), "tests/helpers.luau", setmetatable({
	CropPop = CropPop,
	expect = expect,
}, { __index = _G }))()

for _, e in listdir(ROOT .. "/tests") do
	if string.sub(e.name, -10) == ".spec.luau" then
		currentFile = e.name
		print(currentFile)
		local env = setmetatable({
			test = test,
			expect = expect,
			CropPop = CropPop,
			Helpers = Helpers,
			game = game,
			require = requireModule,
		}, { __index = _G })
		loadmodule(readfile(ROOT .. "/tests/" .. e.name), "tests/" .. e.name, env)()
	end
end

print(string.format("\n%d passed, %d failed, %d compile errors", passed, failed, compileErrors))
if failed > 0 or compileErrors > 0 then
	exit(1)
end

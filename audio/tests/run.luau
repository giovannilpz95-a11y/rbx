--[[
	Audio test runner. Run from the audio/ folder with Crop Pop's Luau host:

		cargo build --release --manifest-path ../croppop/tools/luaurun/Cargo.toml
		../croppop/tools/luaurun/target/release/luaurun tests/run.luau

	Compiles every .luau file, then runs tests/*.spec.luau. Specs get `load(name)`, which
	loads a src/shared module with a fake `script` (so `require(script.X)` works) and an
	optional table of extra globals (a fake `game` for the runtime module).
]]

local ROOT = ARGS[1] or "."
local SHARED = ROOT .. "/src/shared"

-- Syntax check everything, including the client scripts that only run in Roblox.
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
compileTree(ROOT .. "/../croppop/src/client") -- Sfx.luau and its call sites

-- Module loading: `script` is a fake ModuleScript whose children are the sibling files.
local function makeLoader(extraEnv)
	local cache = {}
	local loadModule
	local function scriptFor(name)
		return setmetatable({ Name = name }, {
			__index = function(_, child)
				return { _module = child }
			end,
		})
	end
	loadModule = function(name)
		if cache[name] ~= nil then
			return cache[name]
		end
		local path = if name == "init" then SHARED .. "/init.luau" else SHARED .. "/" .. name .. ".luau"
		local env = setmetatable({
			script = scriptFor(name),
			require = function(target)
				return loadModule(target._module)
			end,
		}, {
			__index = function(_, key)
				local v = extraEnv and extraEnv[key]
				if v ~= nil then
					return v
				end
				return _G[key]
			end,
		})
		local result = loadmodule(readfile(path), path, env)()
		cache[name] = result
		return result
	end
	return loadModule
end

-- Tiny test framework -------------------------------------------------------------

local passed, failed = 0, 0

local function test(name, fn)
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n" .. err)
	end
end

local function fmt(v)
	return if type(v) == "string" then string.format("%q", v) else tostring(v)
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

for _, e in listdir(ROOT .. "/tests") do
	if string.sub(e.name, -10) == ".spec.luau" then
		print(e.name)
		local env = setmetatable({
			test = test,
			expect = expect,
			load = makeLoader(nil),
			makeLoader = makeLoader,
			ROOT = ROOT,
		}, { __index = _G })
		loadmodule(readfile(ROOT .. "/tests/" .. e.name), "tests/" .. e.name, env)()
	end
end

print(string.format("\n%d passed, %d failed, %d compile errors", passed, failed, compileErrors))
if failed > 0 or compileErrors > 0 then
	exit(1)
end

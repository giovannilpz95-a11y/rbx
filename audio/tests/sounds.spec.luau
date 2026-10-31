local Sounds = load("Sounds")

local GROUPS = { Music = true, Ambience = true, Effects = true, Ui = true }
local SOURCES = { Original = true, APM = true, PSE = true }

local function isAssetId(v)
	return type(v) == "string" and string.match(v, "^rbxassetid://%d+$") ~= nil
end

local sfxFiles = {}
for _, e in listdir(ROOT .. "/sfx") do
	sfxFiles["sfx/" .. e.name] = true
end

test("every sound has a group, a volume and a source", function()
	for name, s in Sounds.list do
		expect.truthy(GROUPS[s.group], name .. " group")
		expect.truthy(type(s.volume) == "number" and s.volume > 0 and s.volume <= 1, name .. " volume")
		expect.truthy(SOURCES[s.source], name .. " source")
		if s.id ~= nil then
			expect.truthy(isAssetId(s.id), name .. " id")
		end
		if s.fallback ~= nil then
			expect.truthy(isAssetId(s.fallback), name .. " fallback")
		end
		expect.truthy(s.file ~= nil or s.id ~= nil or s.fallback ~= nil, name .. " has nothing to play")
	end
end)

test("every original points at a file in sfx/, and every file is used", function()
	local used = {}
	for name, s in Sounds.list do
		if s.source == "Original" then
			expect.truthy(s.file, name .. " is an original without a file")
			expect.truthy(sfxFiles[s.file], name .. ": missing " .. tostring(s.file))
			used[s.file] = true
		end
	end
	for file in sfxFiles do
		if string.sub(file, -4) == ".ogg" then
			expect.truthy(used[file], file .. " is not in Sounds.luau")
		end
	end
end)

test("library-only sounds have a licensed asset", function()
	for name, s in Sounds.list do
		if s.source ~= "Original" then
			expect.truthy(isAssetId(s.id or s.fallback), name)
		end
	end
end)

test("short sounds stay under 2 seconds (Art & Audio Direction mix rule)", function()
	for name, s in Sounds.list do
		if not s.looped then
			expect.truthy(s.length and s.length <= 2, name .. " length")
		end
	end
end)

test("music contexts have tracks with ids and volumes", function()
	for _, context in { "Farm", "Puzzle", "Visit" } do
		local list = Sounds.music[context]
		expect.truthy(list and #list > 0, context)
		for _, track in list do
			expect.truthy(isAssetId(track.id), context .. " " .. tostring(track.name))
			expect.truthy(track.volume > 0 and track.volume <= 1, context .. " volume")
		end
	end
	for context, name in Sounds.contextAmbience do
		expect.truthy(Sounds.music[context], context .. " has music")
		expect.truthy(Sounds.list[name] and Sounds.list[name].looped, context .. " ambience " .. name)
	end
	for group, v in Sounds.groups do
		expect.truthy(GROUPS[group] and v >= 0 and v <= 1, group)
	end
end)

test("every sound name the code asks for exists", function()
	local files = {
		ROOT .. "/src/shared/FarmCues.luau",
		ROOT .. "/src/shared/CropPopCues.luau",
		ROOT .. "/src/client/UiTaps.luau",
		ROOT .. "/src/client/FarmHooks.luau",
		ROOT .. "/src/client/Main.client.luau",
		ROOT .. "/src/client/FactoryHum.luau",
		ROOT .. "/src/client/WorldMusic.luau",
	}
	local count = 0
	for _, path in files do
		local source = readfile(path)
		for name in string.gmatch(source, 'sound = "(%w+)"') do
			expect.truthy(Sounds.list[name], path .. " asks for " .. name)
			count += 1
		end
		for name in string.gmatch(source, '= "(Pop%w+)"') do
			expect.truthy(Sounds.list[name], path .. " asks for " .. name)
			count += 1
		end
		for name in string.gmatch(source, 'play%("(%w+)"') do
			expect.truthy(Sounds.list[name], path .. " plays " .. name)
			count += 1
		end
		for name in string.gmatch(source, 'attachLoop%("(%w+)"') do
			expect.truthy(Sounds.list[name] and Sounds.list[name].looped, path .. " loops " .. name)
			count += 1
		end
		for name in string.gmatch(source, 'setAmbience%("(%w+)"') do
			expect.truthy(Sounds.list[name], path .. " ambience " .. name)
			count += 1
		end
	end
	expect.truthy(count > 20, "found the names")
end)

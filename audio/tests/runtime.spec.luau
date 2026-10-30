-- GameAudio itself, against a small fake of the Roblox API.

local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

local function fakeRoblox()
	local created = {}
	local delayed = {}
	local function newInstance(className)
		local inst = { ClassName = className, Name = className, Volume = 1, PlaybackSpeed = 1, IsPlaying = false, Ended = signal(), children = {} }
		function inst:Play()
			self.IsPlaying = true
			self.played = (self.played or 0) + 1
		end
		function inst:Stop()
			self.IsPlaying = false
		end
		function inst:Destroy()
			self.destroyed = true
		end
		table.insert(created, inst)
		return inst
	end
	local services = {
		ContentProvider = { PreloadAsync = function() end },
		RunService = { IsStudio = function() return false end },
		SoundService = newInstance("SoundService"),
		TweenService = {
			Create = function(_, target, _, props)
				return {
					Completed = signal(),
					Play = function()
						for k, v in props do
							target[k] = v -- jump straight to the end
						end
					end,
				}
			end,
		},
	}
	local env = {
		game = { GetService = function(_, name) return services[name] or error("no service " .. name) end },
		Instance = { new = newInstance },
		TweenInfo = { new = function() return {} end },
		task = {
			spawn = function(fn, ...) fn(...) end,
			delay = function(t, fn, ...) table.insert(delayed, { t = t, fn = fn, args = { ... } }) end,
		},
		warn = function() end,
	}
	local function find(pred)
		local out = {}
		for _, inst in created do
			if pred(inst) then
				table.insert(out, inst)
			end
		end
		return out
	end
	local function runDelayed()
		local list = table.clone(delayed)
		table.clear(delayed)
		for _, d in list do
			d.fn(table.unpack(d.args))
		end
	end
	return env, find, runDelayed
end

local function fresh()
	local env, find, runDelayed = fakeRoblox()
	local GameAudio = makeLoader(env)("init")
	return GameAudio, find, runDelayed
end

test("volume groups are nested SoundGroups with the default levels", function()
	local GameAudio, find = fresh()
	GameAudio.setVolume("Ui", 0.6)
	local groups = find(function(i) return i.ClassName == "SoundGroup" end)
	expect.eq(#groups, 5, "master + 4 groups")
	expect.eq(GameAudio.getVolume("Music"), 0.35)
	GameAudio.setVolume("Music", 2)
	expect.eq(GameAudio.getVolume("Music"), 1, "clamped")
end)

test("an uploaded sound plays from a pool, pitched by semitones", function()
	local GameAudio, find = fresh()
	expect.truthy(GameAudio.play("PopMatch", { pitch = 12 }))
	local voices = find(function(i) return i.ClassName == "Sound" and i.SoundId == "rbxassetid://78976345803082" end)
	expect.eq(#voices, 3, "a pool of 3 voices")
	local playing = 0
	for _, v in voices do
		if v.IsPlaying then
			playing += 1
			expect.eq(v.PlaybackSpeed, 2, "an octave up")
		end
	end
	expect.eq(playing, 1)
end)

test("plays are counted, and an unknown name is quiet", function()
	local GameAudio = fresh()
	expect.truthy(GameAudio.play("Coin"))
	expect.eq(GameAudio.stats.Coin, 1)
	expect.falsy(GameAudio.play("NoSuchSound"))
end)

test("a muted group stays quiet", function()
	local GameAudio = fresh()
	GameAudio.setMuted("Effects", true)
	expect.falsy(GameAudio.play("PopMatch"))
	GameAudio.setMuted("Effects", false)
	expect.truthy(GameAudio.play("PopMatch"))
end)

test("music: a playlist context, then a single looping track with a crossfade", function()
	local GameAudio, find = fresh()
	GameAudio.setMusic("Farm")
	local farm = find(function(i) return i.Name == "Music_Farm" end)
	expect.eq(#farm, 1)
	expect.eq(farm[1].SoundId, "rbxassetid://1839578771")
	expect.falsy(farm[1].Looped, "two tracks take turns")
	GameAudio.setMusic("Puzzle")
	local puzzle = find(function(i) return i.Name == "Music_Puzzle" end)
	expect.truthy(puzzle[1].Looped, "one track loops")
	expect.eq(farm[1].Volume, 0, "faded out")
	GameAudio.setMusic("Puzzle")
	expect.eq(#find(function(i) return i.Name == "Music_Puzzle" end), 1, "same context does nothing")
	expect.eq(GameAudio.getMusic(), "Puzzle")
end)

test("the farm ambience fades out under Crop Pop and comes back after", function()
	local GameAudio, find = fresh()
	GameAudio.setMusic("Farm")
	local beds = find(function(i) return i.Name == "Ambience_AmbienceFarm" end)
	expect.eq(#beds, 1)
	expect.eq(beds[1].Volume, 0.5)
	GameAudio.setMusic("Puzzle")
	expect.eq(beds[1].Volume, 0, "faded out")
	GameAudio.setMusic("Farm")
	beds = find(function(i) return i.Name == "Ambience_AmbienceFarm" end)
	expect.eq(#beds, 2, "a fresh bed")
	expect.eq(beds[2].Volume, 0.5)
end)

test("coming back to the farm picks the music up where it left off", function()
	local GameAudio, find = fresh()
	GameAudio.setMusic("Farm")
	local first = find(function(i) return i.Name == "Music_Farm" end)[1]
	first.TimePosition = 42
	GameAudio.setMusic("Puzzle")
	GameAudio.setMusic("Farm")
	local tracks = find(function(i) return i.Name == "Music_Farm" end)
	expect.eq(#tracks, 2)
	expect.eq(tracks[2].SoundId, first.SoundId, "same track")
	expect.eq(tracks[2].TimePosition, 42, "same spot")
end)

test("the playlist moves on after a track ends", function()
	local GameAudio, find, runDelayed = fresh()
	GameAudio.setMusic("Farm")
	find(function(i) return i.Name == "Music_Farm" end)[1].Ended:Fire()
	runDelayed()
	local tracks = find(function(i) return i.Name == "Music_Farm" end)
	expect.eq(#tracks, 2)
	expect.eq(tracks[2].SoundId, "rbxassetid://1839993539")
end)

test("fanfares duck the music, then it comes back", function()
	local GameAudio, find, runDelayed = fresh()
	GameAudio.getVolume("Music") -- sets up the groups
	local music = find(function(i) return i.ClassName == "SoundGroup" and i.Name == "Music" end)[1]
	expect.eq(music.Volume, 0.35)
	expect.truthy(GameAudio.play("LevelUp"))
	expect.truthy(math.abs(music.Volume - 0.35 * 0.35) < 1e-6, "ducked")
	runDelayed()
	expect.eq(music.Volume, 0.35)
end)

test("Crop Pop moments switch the music and play their cues", function()
	local GameAudio = fresh()
	GameAudio.cropPopEvent("Open")
	expect.eq(GameAudio.getMusic(), "Puzzle")
	GameAudio.cropPopEvent("Win")
	expect.eq(GameAudio.stats.PopWin, 1)
	GameAudio.cropPopEvent("Close")
	expect.eq(GameAudio.getMusic(), "Farm")
	GameAudio.cropPopPhase({ kind = "Swap", ok = false }, 0)
	expect.eq(GameAudio.stats.PopBad, 1)
end)

test("delayed cues wait their turn", function()
	local GameAudio, _, runDelayed = fresh()
	GameAudio.playCues({ { sound = "Harvest" }, { sound = "Harvest", delay = 0.06, pitch = 2 } })
	expect.eq(GameAudio.stats.Harvest, 1)
	runDelayed()
	expect.eq(GameAudio.stats.Harvest, 2)
end)

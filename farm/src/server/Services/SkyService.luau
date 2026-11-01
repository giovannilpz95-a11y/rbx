--!strict
-- Sky events (Design/14 Multiplayer Features H1, Config/Sky, shared/Sky): a Rain Shower or a
-- Starfall that everyone on the server sees at the same instant, on a fixed UTC schedule.
--
--   Rain Shower  every growing field of the players here grows 15% faster while it lasts, and
--                each rolls once for Dewkissed (a Prize Crop trait)
--   Starfall     stars land around each player, their own (nobody can take anyone else's):
--                walking up to one catches it for Coins and XP, with a Lucky Star now and then
--                (an Heirloom Seed) and a bonus for catching them all. Growing fields roll
--                once for Starlit.
--
-- Players who join during an event get it from then on. Clients read the event from the
-- workspace's "SkyEvent" attribute (JSON { kind, startsAt, endsAt }, "" when the sky is
-- clear) and the next one from "SkyNext"; stars reach their owner as "Star" pop-ups.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Sky)
local Net = require(Shared.Net)
local Prize = require(Shared.Config.Prize)
local Sky = require(Shared.Sky)
local Train = require(Shared.Train)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local NoticeService = require(script.Parent.NoticeService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local TrainService = require(script.Parent.TrainService)
local Clock = require(script.Parent.Parent.Util.Clock)

local SkyService = {}

type Star = { pos: Vector3, landAt: number, lucky: boolean }
type Visit = {
	startsAt: number, -- the event this record is for
	endsAt: number,
	stars: { [number]: Star },
	nextStar: number,
	dropped: number,
	caught: number,
	luckyAt: number, -- which star (by count) is the Lucky Star; 0 for none
	traits: number, -- fields that turned the event's trait
	bonus: boolean,
}

local rng = Random.new()
local override: Sky.Event? = nil -- a Studio Dev event, ahead of the schedule
local current: Sky.Event? = nil
local published = ""
local publishedNext = ""
local forecastFor = -1 -- the event the Notice Board has forecast
local visits: { [Player]: Visit } = {}
local nextStarId = 0

local function activeEvent(now: number): Sky.Event?
	if override then
		if now < override.endsAt then
			return override
		end
		override = nil
	end
	return Sky.current(now)
end

function SkyService.current(): Sky.Event?
	return current
end

local function publish(now: number)
	local text = if current
		then HttpService:JSONEncode({ kind = current.kind, startsAt = current.startsAt, endsAt = current.endsAt })
		else ""
	if text ~= published then
		published = text
		Workspace:SetAttribute("SkyEvent", text)
	end
	local nextEvent = Sky.nextEvent(now)
	local nextText = if nextEvent
		then HttpService:JSONEncode({ kind = nextEvent.kind, startsAt = nextEvent.startsAt })
		else ""
	if nextText ~= publishedNext then
		publishedNext = nextText
		Workspace:SetAttribute("SkyNext", nextText)
	end
end

local function eligible(data: { [string]: any }?): boolean
	return data ~= nil and data.tutorial.step == 0
end

-- The event reaches one growing field: a faster timer in the rain, and the trait roll
local function touchField(
	player: Player,
	data: { [string]: any },
	field: { [string]: any },
	event: Sky.Event,
	now: number
)
	if not Sky.isGrowing(field, now) or field.sky == event.startsAt then
		return false
	end
	local cut = Sky.growCut(event, field.readyAt, now)
	if cut > 0 then
		field.readyAt = math.max(now, field.readyAt - cut)
	end
	if Sky.weatherRoll(data, field, event, rng:NextNumber()) then
		local visit = visits[player]
		if visit and visit.startsAt == event.startsAt then
			visit.traits += 1
		end
	end
	return true
end

-- The event reaches a player (at its start, or when they join or finish the guide during it)
local function reach(player: Player, event: Sky.Event, now: number)
	local data = DataService.get(player)
	if not eligible(data) then
		return
	end
	local d = data :: { [string]: any }
	local kind = Config.kinds[event.kind]
	local total = Sky.starsPerShower(event.kind)
	visits[player] = {
		startsAt = event.startsAt,
		endsAt = event.endsAt,
		stars = {},
		nextStar = now + 2,
		dropped = 0,
		caught = 0,
		luckyAt = if kind.stars and rng:NextNumber() < Config.luckyChance then rng:NextInteger(1, total) else 0,
		traits = 0,
		bonus = false,
	}
	local touched = false
	for _, field in d.fields do
		if touchField(player, d, field, event, now) then
			touched = true
		end
	end
	if touched then
		DataService.markDirty(player)
		PlotService.refresh(player)
		NetService.pushState(player)
	end
end

-- A crop planted during an event is growing during it too (FarmService.plant calls this)
function SkyService.onPlant(player: Player, field: { [string]: any })
	local event = current
	local data = DataService.get(player)
	if event == nil or not eligible(data) then
		return
	end
	if visits[player] == nil or visits[player].startsAt ~= event.startsAt then
		reach(player, event, Clock.now())
		return
	end
	touchField(player, data :: { [string]: any }, field, event, Clock.now())
end

-- Where a star lands near the avatar: on whatever ground is there, about level with them
local function starSpot(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	local feet = root.Position.Y - 3
	for _ = 1, 8 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = rng:NextNumber(Config.starRadius[1], Config.starRadius[2])
		local x, z = root.Position.X + math.cos(angle) * radius, root.Position.Z + math.sin(angle) * radius
		local hit = Workspace:Raycast(Vector3.new(x, feet + 40, z), Vector3.new(0, -80, 0), params)
		if hit and hit.Instance.CanCollide and math.abs(hit.Position.Y - feet) <= 4 and hit.Normal.Y > 0.7 then
			return hit.Position + Vector3.new(0, 1.2, 0)
		end
	end
	return nil
end

local function dropStar(player: Player, visit: Visit, event: Sky.Event, now: number)
	local pos = starSpot(player)
	visit.nextStar = now + Config.starEvery
	if pos == nil then
		return -- standing somewhere stars can't land (a roof, the water): try at the next one
	end
	visit.dropped += 1
	nextStarId += 1
	local lucky = visit.dropped == visit.luckyAt
	visit.stars[nextStarId] = { pos = pos, landAt = now + Config.starFall, lucky = lucky }
	NetService.popup(player, {
		kind = "Star",
		id = nextStarId,
		x = pos.X,
		y = pos.Y,
		z = pos.Z,
		lucky = lucky,
		goneAt = event.endsAt + Config.starLinger,
	})
end

-- Catch one of your stars (the client sends it when the avatar walks up to it)
function SkyService.collect(player: Player, id: any): (boolean, string?)
	if type(id) ~= "number" or id % 1 ~= 0 then
		return false
	end
	local visit = visits[player]
	local star = visit and visit.stars[id]
	local data = DataService.get(player)
	if visit == nil or star == nil or data == nil then
		return false
	end
	local now = Clock.now()
	if now < star.landAt - 1 or now > visit.endsAt + Config.starLinger + 2 then
		return false
	end
	if not NetService.isNear(player, star.pos, Config.starReach) then
		return false
	end
	visit.stars[id] = nil
	visit.caught += 1
	local coins = Sky.starCoins(data.level)
	EconomyService.add(player, "Coins", coins, "sky_star")
	EconomyService.add(player, "XP", Config.starXp, "sky_star")
	local extras = {}
	if star.lucky then
		data.heirloomSeeds = (data.heirloomSeeds or 0) + 1
		table.insert(extras, "an Heirloom Seed (your next field planted)")
	end
	-- Every star of a whole Starfall: a building material or tool from the train's table
	if not visit.bonus and visit.caught >= Sky.starsPerShower("Starfall") then
		visit.bonus = true
		local reward
		reward, data.trains.seed = Train.drawReward(data.trains.seed, data.level)
		TrainService.give(data, { [reward.item] = reward.qty })
		table.insert(extras, TrainService.rewardName(reward.item, reward.qty) .. " for catching them all")
	end
	DataService.markDirty(player, #extras > 0)
	NetService.pushState(player)
	NetService.popup(player, { kind = "StarCaught", id = id, coins = coins, extra = table.concat(extras, " and ") })
	TelemetryService.custom(player, "sky_star", 1, if star.lucky then "lucky" else nil, true)
	return true
end

-- The end of an event: tell each player what it left them
local function finish(event: Sky.Event)
	local kind = Config.kinds[event.kind]
	local trait = Prize.tiers[kind.trait].displayName
	for player, visit in visits do
		if visit.startsAt ~= event.startsAt or player.Parent == nil then
			continue
		end
		local parts = {}
		if kind.stars and visit.dropped > 0 then
			table.insert(parts, string.format("you caught %d of %d stars", visit.caught, visit.dropped))
		end
		if visit.traits > 0 then
			table.insert(
				parts,
				string.format("%d growing crop%s turned %s", visit.traits, if visit.traits == 1 then "" else "s", trait)
			)
		end
		if #parts > 0 then
			NetService.toast(player, string.format("The %s is over: %s.", kind.displayName, table.concat(parts, ", ")))
		end
	end
end

local function tick()
	local now = Clock.now()
	local event = activeEvent(now)
	local was = current
	local same = event == was
		or (event ~= nil and was ~= nil and event.startsAt == was.startsAt and event.kind == was.kind)
	if not same then
		current = event
		if was then
			finish(was)
		end
		if event then
			for _, player in Players:GetPlayers() do
				reach(player, event, now)
			end
		end
	end
	publish(now)
	-- Late arrivals (joined, or finished the guide) and stars falling
	if current then
		local ev = current :: Sky.Event
		for _, player in Players:GetPlayers() do
			local visit = visits[player]
			if visit == nil or visit.startsAt ~= ev.startsAt then
				reach(player, ev, now)
				visit = visits[player]
			end
			if visit and Config.kinds[ev.kind].stars and now >= visit.nextStar and now < ev.endsAt then
				dropStar(player, visit, ev, now)
			end
		end
	end
	-- A finished event's record (and its stars) goes once the stars' linger is over
	for player, visit in visits do
		local live = current ~= nil and current.startsAt == visit.startsAt
		if player.Parent == nil or (not live and now > visit.endsAt + Config.starLinger + 2) then
			visits[player] = nil
		end
	end
	-- The Notice Board forecasts the next event
	local upcoming = Sky.nextEvent(now)
	if upcoming and upcoming.startsAt ~= forecastFor and upcoming.startsAt - now <= Config.forecastSeconds then
		forecastFor = upcoming.startsAt
		NoticeService.post(Sky.forecastText(upcoming))
	end
end

-- Studio: a Rain Shower or Starfall starts now (`kind`), for its full length
function SkyService.debugStart(player: Player, kind: any): (boolean, string?)
	if not RunService:IsStudio() or type(kind) ~= "string" or Config.kinds[kind] == nil then
		return false
	end
	local now = Clock.now()
	override = { kind = kind, startsAt = now, endsAt = now + Config.kinds[kind].seconds }
	tick()
	NetService.toast(player, "Dev: a " .. Config.kinds[kind].displayName .. " starts now")
	return true
end

function SkyService.init()
	NetService.on(Net.Sky_Collect, 4, 8, SkyService.collect)
	NetService.on(Net.Debug_Sky, 1, 2, SkyService.debugStart)
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[Sky] " .. tostring(err))
			end
			task.wait(1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)
end

return SkyService

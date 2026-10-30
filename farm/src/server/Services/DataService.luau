--!strict
-- Player profiles: load with a session lock, autosave, release on leave, save all on shutdown.
-- Design/09 Roblox Architecture §4–5. A thin in-house lock over UpdateAsync; swapping in
-- ProfileStore later only changes this file.
--
-- Stored record: { data = <profile>, lock = { jobId, placeId, lockedAt }? }

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Profile = require(Shared.Profile)
local Tutorial = require(Shared.Tutorial)

local Clock = require(script.Parent.Parent.Util.Clock)

local DataService = {}

local ENV = if RunService:IsStudio() then "DEV" else "LIVE"
local STORE_NAME = "Farm_Profiles_" .. ENV
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local LOCK_STALE_SECONDS = 10 * 60 -- a lock older than this is from a dead server
local LOAD_ATTEMPTS = 5
local LOAD_RETRY_SECONDS = 4

type Session = {
	data: { [string]: any },
	dirty: boolean,
	important: boolean,
	lastSaveAt: number,
	memoryOnly: boolean, -- Studio without API access: nothing is written
	released: boolean,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function studioFallback(reason: string): boolean
	if RunService:IsStudio() then
		warn(
			"[DataService] Using an unsaved in-memory farm in Studio ("
				.. reason
				.. "). Turn on 'Enable Studio Access to API Services' to test saving."
		)
		return true
	end
	return false
end

-- Returns true when the player has a usable profile. Never plays on a blank profile in live.
function DataService.load(player: Player): boolean
	local raw: { [string]: any }? = nil
	local loaded = false
	local memoryOnly = false

	if store == nil then
		if not studioFallback("no DataStore") then
			player:Kick("Couldn't load your farm. Please rejoin.")
			return false
		end
		memoryOnly = true
		loaded = true
	else
		local activeStore = store :: DataStore
		for attempt = 1, LOAD_ATTEMPTS do
			local blocked = false
			local ok, err = pcall(function()
				activeStore:UpdateAsync(keyFor(player), function(old)
					local record = old or {}
					local lock = record.lock
					local now = os.time()
					if lock and lock.jobId ~= JOB_ID and now - (lock.lockedAt or 0) < LOCK_STALE_SECONDS then
						blocked = true
						return nil -- another live server owns this farm; don't write
					end
					blocked = false
					raw = record.data
					record.lock = { jobId = JOB_ID, placeId = game.PlaceId, lockedAt = now }
					return record
				end)
			end)
			if ok and not blocked then
				loaded = true
				break
			end
			if not ok then
				warn("[DataService] Load attempt", attempt, "failed:", err)
				if attempt == 1 and studioFallback(tostring(err)) then
					memoryOnly = true
					loaded = true
					break
				end
			end
			if player.Parent == nil then
				return false
			end
			task.wait(LOAD_RETRY_SECONDS)
		end
	end

	if not loaded then
		player:Kick("Your farm is still open on another server. Please rejoin in a minute.")
		return false
	end
	if player.Parent == nil then
		-- Left while loading: give the lock back.
		if not memoryOnly then
			sessions[player] = {
				data = raw or Profile.template(),
				dirty = false,
				important = false,
				lastSaveAt = 0,
				memoryOnly = false,
				released = false,
			}
			DataService.release(player)
		end
		return false
	end

	local data, reason = Profile.migrate(raw)
	if data == nil then
		player:Kick(
			if reason == "newer"
				then "The game was just updated. Please rejoin."
				else "Couldn't load your farm. Please rejoin."
		)
		return false
	end

	local now = Clock.now()
	if Profile.welcome(data, now) then
		Tutorial.start(data, now)
	end
	data.meta.sessionCount += 1

	sessions[player] = {
		data = data,
		dirty = true,
		important = false,
		lastSaveAt = os.clock(),
		memoryOnly = memoryOnly,
		released = false,
	}
	return true
end

-- Studio only: farms with no real player behind them, never saved (SocialService's test
-- neighbor for single-player checks of visiting and Helping Hands).
local dummies: { [any]: { [string]: any } } = {}

function DataService.addDummy(owner: any, data: { [string]: any })
	assert(RunService:IsStudio(), "Dummy farms are Studio-only")
	dummies[owner] = data
end

function DataService.get(player: Player): { [string]: any }?
	local session = sessions[player]
	if session == nil then
		return dummies[player]
	end
	return if not session.released then session.data else nil
end

function DataService.markDirty(player: Player, important: boolean?)
	local session = sessions[player]
	if session then
		session.dirty = true
		if important then
			session.important = true
		end
	end
end

-- Other systems that keep their own live state (Crop Pop) copy it into the profile here.
local beforeSaveHooks: { (player: Player, data: { [string]: any }) -> () } = {}

function DataService.onBeforeSave(hook: (player: Player, data: { [string]: any }) -> ())
	table.insert(beforeSaveHooks, hook)
end

local function write(player: Player, session: Session, release: boolean): boolean
	for _, hook in beforeSaveHooks do
		local ok, err = pcall(hook, player, session.data)
		if not ok then
			warn("[DataService] Before-save hook failed:", err)
		end
	end
	if session.memoryOnly or store == nil then
		return true
	end
	local activeStore = store :: DataStore
	session.data.meta.lastSeenAt = Clock.now()
	local snapshot = Profile.deepCopy(session.data)
	local lostLock = false
	local ok, err = pcall(function()
		activeStore:UpdateAsync(keyFor(player), function(old)
			local record = old or {}
			if record.lock and record.lock.jobId ~= JOB_ID then
				lostLock = true
				return nil
			end
			record.data = snapshot
			record.lock = if release then nil else { jobId = JOB_ID, placeId = game.PlaceId, lockedAt = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.UserId, err)
		return false
	end
	if lostLock then
		warn("[DataService] Lost the session lock for", player.UserId)
		session.released = true
		if player.Parent then
			player:Kick("Your farm was opened on another server.")
		end
		return false
	end
	session.dirty = false
	session.important = false
	session.lastSaveAt = os.clock()
	return true
end

function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if session == nil or session.released then
		return false
	end
	return write(player, session, false)
end

local releasing = 0

-- Final save that also gives the lock back. Safe to call twice.
function DataService.release(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session == nil or session.released then
		return
	end
	session.released = true
	releasing += 1
	write(player, session, true)
	releasing -= 1
end

function DataService.init()
	-- Autosave: dirty profiles every 90 s, "important" ones (level up, etc.) within 10 s.
	-- With before-save hooks every profile counts as dirty, since the hooked state changes
	-- without telling us.
	task.spawn(function()
		while true do
			task.wait(1)
			local clock = os.clock()
			for player, session in sessions do
				if session.released or (not session.dirty and #beforeSaveHooks == 0) then
					continue
				end
				local age = clock - session.lastSaveAt
				if age >= Balance.autosaveSeconds or (session.important and age >= Balance.importantSaveSeconds) then
					task.spawn(write, player, session, false)
					session.lastSaveAt = clock -- avoid re-queueing while the write is in flight
				end
			end
		end
	end)

	game:BindToClose(function()
		for player in sessions do
			task.spawn(DataService.release, player)
		end
		task.wait() -- let every release start its write
		local deadline = os.clock() + 25
		while releasing > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)
end

return DataService

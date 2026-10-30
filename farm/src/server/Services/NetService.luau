--!strict
-- Creates the remotes, runs every client intent through rate limit -> type check -> handler,
-- and sends the owner a fresh state snapshot after anything changes.
-- Design/09 Roblox Architecture §8. Snapshots are whole-state for the greybox; small
-- path deltas can replace them once the state grows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)
local Shop = require(Shared.Shop)
local Timer = require(Shared.Timer)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Clock = require(script.Parent.Parent.Util.Clock)

local NetService = {}

local folder = Instance.new("Folder")
folder.Name = "FarmRemotes"
folder.Parent = ReplicatedStorage

local remotes: { [string]: RemoteEvent } = {}
for name in Net do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	remotes[name] = remote
end

local limiters: { [Player]: { [string]: RateLimiter.RateLimiter } } = {}
local pushQueued: { [Player]: boolean } = {}
local readyPlayers: { [Player]: boolean } = {}
local onReady: { [Player]: { () -> () } } = {}
local lastActive: { [Player]: number } = {} -- os.clock() of the player's last handled intent

-- Argument checks used by handlers
NetService.check = {}

function NetService.check.id(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 64
end

function NetService.check.int(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

function NetService.check.number(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Build what the owner's UI needs. Never includes anything another player owns.
local function snapshot(data: { [string]: any })
	local itemsTotal = 0
	for _, qty in data.inventory.items do
		itemsTotal += qty
	end
	local info = Progression.info(data.currencies.XP)
	local factories = {}
	for id, factory in data.factories do
		factories[id] = {
			built = factory.built,
			constructionReadyAt = factory.constructionReadyAt,
			slots = factory.slots,
			queue = factory.queue,
			output = factory.output,
			outputCount = Timer.countOutput(factory.output),
		}
	end
	return {
		currencies = data.currencies,
		level = data.level,
		xpIntoLevel = info.xpIntoLevel,
		xpToNext = info.xpToNext,
		atCap = info.atCap,
		inventory = data.inventory.items,
		barnUsed = itemsTotal,
		barnCapacity = Shop.barnCapacity(data), -- with the Big Barn pass
		purchases = { bought = data.purchases.bought, passes = data.purchases.passes },
		barnUpgrades = data.inventory.upgrades,
		fields = data.fields,
		factories = factories,
		pens = data.pens,
		town = data.town,
		land = data.land,
		decor = data.decor,
		tools = data.toolShed.items,
		prizes = data.prizes,
		prizeShelf = data.prizeShelf,
		social = data.social,
		board = data.orders.board,
		settings = data.settings,
		tutorial = data.tutorial,
		serverNow = Clock.now(),
		timeScale = Clock.getTimeScale(),
	}
end

function NetService.pushState(player: Player)
	if pushQueued[player] or not readyPlayers[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		local data = DataService.get(player)
		if data and player.Parent then
			remotes[Net.State_Snapshot]:FireClient(player, snapshot(data))
		end
	end)
end

-- Messages to a Studio test neighbor (not a real Player) go nowhere.
local function isPlayer(player: any): boolean
	return typeof(player) == "Instance"
end

function NetService.toast(player: Player, message: string)
	if not isPlayer(player) then
		return
	end
	remotes[Net.Toast]:FireClient(player, message)
end

function NetService.popup(player: Player, payload: { [string]: any })
	if not isPlayer(player) then
		return
	end
	remotes[Net.Reward_Popup]:FireClient(player, payload)
end

-- Handlers return (ok, errorMessage?). A successful handler marks the profile dirty and
-- queues a state push; a failed one shows its message as a toast.
export type Handler = (player: Player, ...any) -> (boolean, string?)

function NetService.on(name: string, rate: number, burst: number, handler: Handler)
	local remote = remotes[name]
	assert(remote, "Unknown remote " .. name)
	remote.OnServerEvent:Connect(function(player, ...)
		local perPlayer = limiters[player]
		if perPlayer == nil then
			perPlayer = {}
			limiters[player] = perPlayer
		end
		local limiter = perPlayer[name]
		if limiter == nil then
			limiter = RateLimiter.new(rate, burst)
			perPlayer[name] = limiter
		end
		if not limiter:take() then
			return -- dropped silently
		end
		if DataService.get(player) == nil then
			return
		end
		lastActive[player] = os.clock()
		local ok, result, message = pcall(handler, player, ...)
		if not ok then
			warn("[NetService]", name, "errored:", result)
			return
		end
		if result then
			DataService.markDirty(player)
			NetService.pushState(player)
		elseif message then
			NetService.toast(player, message)
		end
	end)
end

-- Server-side reach check: the avatar must be near a hands-on target.
function NetService.isNear(player: Player, position: Vector3, studs: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return false
	end
	local offset = root.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= studs
end

-- Seconds since the player last did anything (any intent the server handled).
function NetService.idleSeconds(player: Player): number
	local at = lastActive[player]
	return if at then os.clock() - at else math.huge
end

-- Run fn once the player's UI is listening (now, if it already is).
function NetService.whenReady(player: Player, fn: () -> ())
	if readyPlayers[player] then
		fn()
	else
		onReady[player] = onReady[player] or {}
		table.insert(onReady[player], fn)
	end
end

function NetService.init()
	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
		pushQueued[player] = nil
		readyPlayers[player] = nil
		onReady[player] = nil
		lastActive[player] = nil
	end)
	-- The client asks for its first snapshot once its UI is listening. If the farm is still
	-- loading, the push after the load delivers it instead.
	remotes[Net.Client_Ready].OnServerEvent:Connect(function(player)
		if not readyPlayers[player] then
			readyPlayers[player] = true
			NetService.pushState(player)
			local waiting = onReady[player]
			onReady[player] = nil
			for _, fn in waiting or {} do
				task.spawn(fn)
			end
		end
	end)
end

return NetService

--!strict
-- Local mirror of the owner's state (sent whole by the server after every change) plus
-- per-player client settings that the debug panel can tune.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Factories = require(Shared.Config.Factories)
local Profile = require(Shared.Profile)
local Timer = require(Shared.Timer)

local ClientStore = {}

ClientStore.state = nil :: { [string]: any }?
ClientStore.changed = Instance.new("BindableEvent")

-- Tunable in the debug panel for the greybox playtest
ClientStore.settings = {
	reach = Balance.reachStuds,
	walkSpeed = Balance.walkSpeed,
	sprinting = false,
}
ClientStore.settingsChanged = Instance.new("BindableEvent")

function ClientStore.set(state: { [string]: any })
	ClientStore.state = state
	ClientStore.changed:Fire(state)
end

function ClientStore.setSetting(key: string, value: any)
	(ClientStore.settings :: any)[key] = value
	ClientStore.settingsChanged:Fire(key, value)
end

-- Server clock in seconds; matches the os.time() stamps in the state.
function ClientStore.now(): number
	return Workspace:GetServerTimeNow()
end

-- Where a factory's queue stands right now, without waiting for the server.
function ClientStore.factoryPreview(factoryId: string)
	local state = ClientStore.state
	local factory = state and state.factories[factoryId]
	if factory == nil then
		return nil
	end
	local queue = Profile.deepCopy(factory.queue)
	local output = Profile.deepCopy(factory.output)
	Timer.advanceQueue(queue, output, ClientStore.now(), Factories[factoryId].trayCapacity)
	local now = ClientStore.now()
	return {
		built = factory.built,
		underConstruction = factory.built and factory.constructionReadyAt ~= nil and now < factory.constructionReadyAt,
		constructionReadyAt = factory.constructionReadyAt,
		slots = factory.slots,
		queue = queue,
		output = output,
		outputCount = Timer.countOutput(output),
	}
end

function ClientStore.itemCount(item: string): number
	local state = ClientStore.state
	return if state then state.inventory[item] or 0 else 0
end

return ClientStore

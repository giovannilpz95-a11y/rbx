--!strict
-- The save document: default template, ordered migrations and reconcile (pure, so Lune
-- tests can cover it). Layout follows Design/09 Roblox Architecture §4, trimmed to what the
-- greybox uses; the other systems add their blocks with a migration when they arrive.

local Balance = require("./Config/Balance")
local Factories = require("./Config/Factories")
local Levels = require("./Config/Levels")

local Profile = {}

Profile.VERSION = 1

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end
Profile.deepCopy = deepCopy

function Profile.fieldIds(): { string }
	local ids = {}
	for i = 1, Balance.startingFields do
		table.insert(ids, "F" .. i)
	end
	return ids
end

function Profile.template(): { [string]: any }
	local startCoins = Levels.list[1].rewardCoins
	local startGems = Levels.list[1].rewardGems

	local fields = {}
	for _, id in Profile.fieldIds() do
		fields[id] = {} -- { crop: string?, plantedAt: number?, readyAt: number? }
	end

	local factories = {}
	for _, id in Balance.enabledFactories do
		factories[id] = {
			built = false,
			constructionReadyAt = nil,
			slots = Factories[id].queueSlots,
			queue = {}, -- { Timer.Job }
			output = {}, -- item -> qty waiting on the output tray
		}
	end

	return {
		version = Profile.VERSION,
		meta = {
			createdAt = 0,
			lastSeenAt = 0,
			sessionCount = 0,
		},
		currencies = {
			Coins = startCoins,
			Gems = startGems,
			XP = 0, -- total XP earned; the level is derived from it
		},
		level = 1,
		inventory = {
			items = {},
			barnCapacity = Balance.barnStartCapacity,
		},
		fields = fields,
		factories = factories,
		orders = {
			board = {}, -- array of slots: an order, or { refreshAt = n } while empty
			seed = 0,
			delivered = 0,
		},
		settings = {
			lastSeed = "Wheat",
		},
	}
end

-- Migrations[n] turns a version-n profile into version n+1. None yet.
local Migrations: { [number]: (profile: { [string]: any }) -> () } = {}

-- Fill keys missing from `target` with template defaults. Extra keys are kept.
local function reconcile(target: { [string]: any }, template: { [string]: any })
	for key, default in template do
		if target[key] == nil then
			target[key] = deepCopy(default)
		elseif type(default) == "table" and type(target[key]) == "table" then
			reconcile(target[key], default)
		end
	end
end
Profile.reconcile = reconcile

-- Returns the upgraded profile, or nil and a reason when this build can't load it.
function Profile.migrate(data: { [string]: any }?): ({ [string]: any }?, string?)
	if data == nil then
		return Profile.template(), nil
	end
	local version = data.version or 1
	if version > Profile.VERSION then
		return nil, "newer"
	end
	while version < Profile.VERSION do
		local step = Migrations[version]
		if step then
			step(data)
		end
		version += 1
		data.version = version
	end
	reconcile(data, Profile.template())
	return data, nil
end

return Profile

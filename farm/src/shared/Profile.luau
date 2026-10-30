--!strict
-- The save document: default template, ordered migrations and reconcile (pure, so Lune
-- tests can cover it). Layout follows Design/09 Roblox Architecture §4, trimmed to what the
-- greybox uses; the other systems add their blocks with a migration when they arrive.

local Animals = require("./Config/Animals")
local Balance = require("./Config/Balance")
local Factories = require("./Config/Factories")
local Levels = require("./Config/Levels")
local Social = require("./Config/Social")
local Town = require("./Config/Town")

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

	local pens = {}
	for _, id in Balance.enabledPens do
		local def = Animals.pens[id]
		local animals = {}
		if def.given then
			for _ = 1, def.startAnimals do
				table.insert(animals, {}) -- hungry
			end
		end
		pens[id] = {
			built = def.given,
			constructionReadyAt = nil,
			animals = animals, -- { readyAt: number? } each (shared/Pen)
			feedLeft = 0,
		}
	end

	local houses = {}
	for lot, houseId in Town.starterHouses do
		table.insert(houses, { type = houseId, lot = lot }) -- built: no readyAt
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
			items = {}, -- never put starting items here: reconcile would refill them on every load
			barnCapacity = Balance.barnStartCapacity,
			upgrades = 0, -- Barn upgrades done (shared/BarnRules)
		},
		fields = fields,
		factories = factories,
		pens = pens,
		decor = {}, -- placed decorations: { id, x, z, r } (shared/DecorRules)
		prizes = {}, -- the Prize Basket: { crop, tier } (shared/Prize)
		prizeShelf = {}, -- Prize Crops on show on the plot, same shape
		purchases = {
			receipts = {}, -- PurchaseId -> time granted, newest 200 (shared/Shop)
			bought = {}, -- one-time products bought (StarterPack)
			passes = {}, -- game passes owned, refreshed from Roblox on join
		},
		toolShed = {
			items = {}, -- Shovel / Axe / Saw -> qty; no Barn space (shared/Drops)
			dry = 0, -- harvests in a row without a tool, for the pity drop
		},
		land = {}, -- land expansions started, in order: { readyAt? } (shared/TownRules)
		town = {
			houses = houses, -- { type, lot, readyAt? } (shared/TownRules)
			community = {}, -- id -> { readyAt? }
		},
		orders = {
			board = {}, -- array of slots: an order, or { refreshAt = n } while empty
			seed = 0,
			delivered = 0,
		},
		settings = {
			lastSeed = "Wheat",
		},
		daily = {
			day = 0, -- days claimed in this round of the login calendar (shared/Daily)
			lastDay = -1, -- UTC day number of the last claim
		},
		tutorial = {
			step = 0, -- the first-session guide (shared/Tutorial); 0 = off
		},
		social = { -- visiting, Helping Hands and boosts (shared/Social)
			privacy = Social.defaultPrivacy, -- who may visit: Open / Friends / Closed
			helpers = Social.defaultHelpers, -- who may help: Nobody / Friends / Anyone
			help = { day = -1, used = 0, owners = {} }, -- today's helping, owners by user id string
			boostUntil = 0, -- Welcome Boost end time
			boostDay = -1,
			boostPairs = {}, -- friends (user id strings) who already gave today's boost
		},
		-- puzzle = Crop Pop's own save block (Hearts, boosters, progress), absent until it
		-- first saves; the farm stores it without reading it (server/Services/CropPopBridge).
	}
end

-- One-time gifts for a brand-new farm (meta.createdAt still 0). Returns true if applied.
function Profile.welcome(data: { [string]: any }, now: number): boolean
	if data.meta.createdAt ~= 0 then
		return false
	end
	data.meta.createdAt = now
	data.inventory.items.CowFeed = (data.inventory.items.CowFeed or 0) + Balance.starterCowFeed
	return true
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

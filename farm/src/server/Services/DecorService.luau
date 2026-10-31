--!strict
-- Decorations (Design/07 Town Building): buy one from the Town panel and place it in front
-- of you, turn it, or sell it back for 50%. Placing is instant and gives a little XP once.
-- Gold Town Record trophies place the same way from storage (data.trophies), for free, and
-- "selling" one puts it back in storage.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Decor = require(Shared.Config.Decor)
local DecorRules = require(Shared.DecorRules)
local Net = require(Shared.Net)
local SeedCartRules = require(Shared.SeedCart)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Clock = require(script.Parent.Parent.Util.Clock)

local DecorService = {}

local LIMIT = 200 -- plot-local studs; any real spot is well inside this

local function fits(player: Player, data: { [string]: any }, p: DecorRules.Placed, skip: number?): (boolean, string?)
	local ok, reason = DecorRules.canPlace(data, p, Clock.now(), skip)
	if not ok then
		return false, reason
	end
	local w, d = DecorRules.footprint(p.id, p.r)
	if PlotService.blocked(player, p.x, p.z, w * Decor.tile, d * Decor.tile) then
		return false, "Something is already there"
	end
	return true, nil
end

function DecorService.place(player: Player, id: any, x: any, z: any, r: any): (boolean, string?)
	if not NetService.check.id(id) or DecorRules.def(id) == nil then
		return false
	end
	if typeof(x) ~= "number" or typeof(z) ~= "number" or x ~= x or z ~= z then
		return false -- not numbers, or NaN
	end
	if math.abs(x) > LIMIT or math.abs(z) > LIMIT then
		return false
	end
	if not NetService.check.int(r, 0, 3) then
		return false
	end
	local def = DecorRules.def(id)
	local data = DataService.get(player) :: { [string]: any }
	local trophy = def.trophy == true
	if trophy and (data.trophies[id] or 0) < 1 then
		return false, "Win this record's Gold medal to get its trophy"
	end
	if data.level < def.unlockLevel then
		return false, string.format("The %s unlocks at level %d", def.displayName, def.unlockLevel)
	end
	local room, why = DecorRules.hasRoom(data, id)
	if not room then
		return false, why
	end
	local cx, cz = DecorRules.snap(id, r, x, z)
	local p = { id = id, x = cx, z = cz, r = r }
	local ok, reason = fits(player, data, p)
	if not ok then
		return false, reason
	end
	if trophy then
		data.trophies[id] -= 1
	-- One prepaid at the Seed Cart is placed for free
	elseif
		not SeedCartRules.useCoupon(data, id)
		and not EconomyService.spend(player, "Coins", def.coinCost, "decor_" .. id)
	then
		return false, string.format("The %s costs %d Coins", def.displayName, def.coinCost)
	end
	table.insert(data.decor, p)
	if def.xp > 0 then
		EconomyService.add(player, "XP", def.xp, "decor_" .. id)
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function DecorService.rotate(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not NetService.check.int(index, 1, Decor.maxPlaced) or data.decor[index] == nil then
		return false
	end
	local old = data.decor[index]
	local r = (old.r + 1) % 4
	local cx, cz = DecorRules.snap(old.id, r, old.x, old.z)
	local p = { id = old.id, x = cx, z = cz, r = r }
	local ok, reason = fits(player, data, p, index)
	if not ok then
		return false, reason
	end
	data.decor[index] = p
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function DecorService.sell(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not NetService.check.int(index, 1, Decor.maxPlaced) or data.decor[index] == nil then
		return false
	end
	local p = table.remove(data.decor, index)
	if DecorRules.isTrophy(p.id) then
		data.trophies[p.id] = (data.trophies[p.id] or 0) + 1 -- back to storage, never sold
	else
		EconomyService.add(player, "Coins", DecorRules.refund(p.id), "decor_sell")
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function DecorService.init()
	NetService.on(Net.Decor_Place, 2, 4, DecorService.place)
	NetService.on(Net.Decor_Rotate, 3, 5, DecorService.rotate)
	NetService.on(Net.Decor_Sell, 2, 3, DecorService.sell)
end

return DecorService

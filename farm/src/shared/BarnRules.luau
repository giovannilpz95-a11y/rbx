--!strict
-- Barn upgrade rules (Design/02 Farming), pure so the server, the client and the Lune tests
-- share them. Saved as data.inventory.upgrades (count done) next to barnCapacity.

local Balance = require("./Config/Balance")
local Barn = require("./Config/Barn")

local BarnRules = {}

-- Barn capacity after this many upgrades.
function BarnRules.capacity(upgrades: number): number
	local total = Balance.barnStartCapacity
	local done = 0
	for _, step in Barn.steps do
		local count = math.min(upgrades, step.upTo) - done
		if count <= 0 then
			break
		end
		total += count * step.add
		done += count
	end
	return total
end

-- Materials upgrade n needs: n of each Barn material.
function BarnRules.upgradeCost(n: number): { [string]: number }
	local cost = {}
	for id in Barn.materials do
		cost[id] = n
	end
	return cost
end

return BarnRules

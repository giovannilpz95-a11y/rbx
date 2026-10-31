--!strict
-- Roblox badges for Town Record medals (Config/Records). Each record has a slot per tier
-- (Bronze, Silver, Gold); 0 means no badge made for it yet. The badges themselves are made on
-- the Roblox Creator Dashboard (Giovanni's list: project files launch/roblox-badges.md); paste
-- each badge's id here and players get it when they claim that medal, or on their next join
-- if they claimed it earlier.

return table.freeze({
	records = table.freeze({
		Orders = { 0, 0, 0 },
		Harvest = { 0, 0, 0 },
		Goods = { 0, 0, 0 },
		Animals = { 0, 0, 0 },
		Coins = { 0, 0, 0 },
		Population = { 0, 0, 0 },
		Houses = { 0, 0, 0 },
		Factories = { 0, 0, 0 },
		Decor = { 0, 0, 0 },
		Helping = { 0, 0, 0 },
	}) :: { [string]: { number } },
})

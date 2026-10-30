--!strict
-- The L4 social slice (Design/14 Multiplayer Features: A1, A2, B1, G1, G3; Design/08 Social &
-- Events). Township has no live co-op, so every number here is first-pass from note 14.

return table.freeze({
	-- Who may walk onto your plot, and who may help on it (08 Safety Rules, 14 B1)
	privacyOptions = table.freeze({ "Open", "Friends", "Closed" }),
	defaultPrivacy = "Open",
	helperOptions = table.freeze({ "Nobody", "Friends", "Anyone" }),
	defaultHelpers = "Friends",
	sendHomeCooldown = 10 * 60, -- a visitor sent home can't come back for this long

	-- Helping Hands (14 B1): water and harvest on someone else's plot
	helpUnlockLevel = 3,
	helpPerDay = 40, -- actions per helper per UTC day, across all plots
	helpPerOwnerPerDay = 15, -- actions per helper on one owner's plot per day
	waterCut = 0.10, -- watering takes this share off a field's remaining time, once per crop
	helperCoinShare = 0.10, -- helper Coins per harvest: this share of the field's sell value
	helperToolChance = 0.02, -- per helping action, the helper's scarcest tool
	helperMinAccountDays = 3, -- helper rewards only from Roblox accounts this old (alts)
	teamworkSeconds = 30, -- owner and helper both working the plot within this window...
	teamworkXP = 5, -- ...each get this much extra XP per helping action

	-- Good Neighbors (14 G1): more Coins from Order Board deliveries with friends around
	neighborBonusPerFriend = 0.05,
	neighborBonusMax = 0.10,
	neighborMinLevel = 5, -- the friend must be this level...
	neighborActiveSeconds = 5 * 60, -- ...and have done something this recently

	-- Friend-join Welcome Boost (14 G3)
	welcomeSeconds = 15 * 60,
	welcomeGrowCut = 0.10, -- crops planted during the boost grow this much faster
	welcomeMinLevel = 5, -- the joiner's level for the friend they joined to get the boost too
})

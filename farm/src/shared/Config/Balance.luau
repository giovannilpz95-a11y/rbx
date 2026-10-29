--!strict
-- Global tuning. Barn size is Township baseline; walk-first numbers are first-pass from
-- Design/15 3D World & Avatar Play and are meant to be tuned in the greybox playtest.

return table.freeze({
	-- Crops playable in the greybox (the full table lives in Crops)
	enabledCrops = table.freeze({ "Wheat", "Corn" }),
	-- Factories placed on the greybox plot
	enabledFactories = table.freeze({ "Bakery" }),

	startingFields = 6, -- Township baseline
	barnStartCapacity = 50, -- Township baseline

	-- Walk-first "Reach + Errands" (first-pass)
	reachStuds = 32, -- tap anything this close; farther taps auto-walk first
	reachOptions = table.freeze({ 0, 16, 32, 48 }), -- debug slider values
	serverReachStuds = 56, -- server check: largest debug reach + slack for latency
	walkSpeed = 20,
	walkSpeedOptions = table.freeze({ 16, 20, 24 }),
	sprintSpeed = 28,
	sweepInterval = 0.35, -- seconds between swings while the action button is held
	harvestArcStuds = 6, -- a swing hits ready beds this close to the point in front of you
	plantRadiusStuds = 4, -- holding the action button sows empty beds this close
	magnetStuds = 10, -- walk-by collect radius for factory output

	-- Saving (first-pass, 09 Roblox Architecture §5)
	autosaveSeconds = 90,
	importantSaveSeconds = 10,

	-- DEV-only timer scale (Studio): 0.25 makes Wheat take 30 s as in the prototype checklist
	timeScaleOptions = table.freeze({ 1, 0.25, 0.05 }),
})

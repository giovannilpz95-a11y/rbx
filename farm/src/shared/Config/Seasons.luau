--!strict
-- Seasonal looks (Design/08 Social & Events "Seasonal Content"; Launch/20 §2: a season's skin
-- switches on the first Friday of its window, UTC). Visual only: drifting petals, leaves or
-- snow around the camera and a light colour grade. Seasonal recipes and decorations come with
-- the events that use them.
--
-- Decided default (tell Giovanni): the looks follow the calendar from now on (it's the Harvest
-- Moon in November), and Reduce motion thins the particles.

export type Season = {
	id: string,
	displayName: string,
	firstMonth: number, -- the window starts on this month's first Friday
	-- Particles drifting down around the camera (nil: none)
	particles: {
		colors: { Color3 },
		size: number,
		rate: number,
		reducedRate: number,
		speed: number, -- studs a second downward
		sway: number, -- sideways drift
	}?,
	-- A light grade over the scene (ColorCorrection TintColor, Saturation)
	tint: Color3,
	saturation: number,
}

local seasons: { [string]: Season } = {
	SpringBloom = {
		id = "SpringBloom",
		displayName = "Spring Bloom",
		firstMonth = 3,
		particles = {
			colors = { Color3.fromRGB(255, 196, 214), Color3.fromRGB(255, 230, 240) },
			size = 0.35,
			rate = 7,
			reducedRate = 2,
			speed = 3,
			sway = 3,
		},
		tint = Color3.fromRGB(255, 250, 252),
		saturation = 0.04,
	},
	SummerSun = {
		id = "SummerSun",
		displayName = "Summer Sun",
		firstMonth = 6,
		particles = nil, -- bright skies: just a warmer, richer grade
		tint = Color3.fromRGB(255, 251, 240),
		saturation = 0.08,
	},
	HarvestMoon = {
		id = "HarvestMoon",
		displayName = "Harvest Moon",
		firstMonth = 9,
		particles = {
			colors = { Color3.fromRGB(230, 120, 40), Color3.fromRGB(200, 70, 40), Color3.fromRGB(235, 175, 60) },
			size = 0.5,
			rate = 6,
			reducedRate = 2,
			speed = 4,
			sway = 4,
		},
		tint = Color3.fromRGB(255, 244, 228),
		saturation = 0.03,
	},
	FrostyFields = {
		id = "FrostyFields",
		displayName = "Frosty Fields",
		firstMonth = 12,
		particles = {
			colors = { Color3.fromRGB(245, 248, 252), Color3.fromRGB(225, 236, 250) },
			size = 0.25,
			rate = 14,
			reducedRate = 4,
			speed = 5,
			sway = 2,
		},
		tint = Color3.fromRGB(244, 248, 255),
		saturation = -0.04,
	},
}

for _, season in seasons do
	if season.particles then
		table.freeze(season.particles.colors)
		table.freeze(season.particles)
	end
	table.freeze(season)
end

return table.freeze({
	seasons = table.freeze(seasons),
	order = table.freeze({ "SpringBloom", "SummerSun", "HarvestMoon", "FrostyFields" }), -- by firstMonth
})

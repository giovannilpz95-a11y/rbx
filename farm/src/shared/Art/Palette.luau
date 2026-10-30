--!strict
-- World palette for the 3D models. Design/12 Art & Audio Direction (palette) and
-- Design/16 Model Catalog §1.4, pushed a little brighter for the sunny, saturated look the
-- game is going for. Shared tokens (cream, cocoa, coins, gems, xp, grass, wood) use the same
-- hex values as the UI palette in uitheme/src/Palette.luau; change both together.
--
-- Rules (16 §1.4): no pure black or white (darkest is cocoa, lightest is cream), one roof
-- accent per building, crops and goods are the most saturated colors on screen, and the
-- currency colors are never used as large building colors.

local function hex(value: string): Color3
	local r, g, b = value:match("^#(%x%x)(%x%x)(%x%x)$")
	assert(r and g and b, "bad hex color " .. value)
	return Color3.fromRGB(tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number)
end

local Palette = {
	-- Shared with the UI palette
	cream = hex("#FFF6E5"),
	cocoa = hex("#4A3426"),
	coins = hex("#FFC93C"),
	gems = hex("#29C7AC"),
	xp = hex("#8BD346"),
	grass = hex("#7BC96F"),
	wood = hex("#C98A4B"),

	-- Ground
	grassLight = hex("#93D77A"),
	grassDark = hex("#5FAE57"),
	grassWild = hex("#6DBB63"),
	soil = hex("#8B5E3C"),
	soilDark = hex("#6B4429"),
	soilLight = hex("#A87448"),
	path = hex("#E8D3A6"),
	pathEdge = hex("#D2B98A"),
	road = hex("#B9AFA0"),
	hub = hex("#E3D5B8"),
	water = hex("#4FC3D9"),
	straw = hex("#E9C46A"),

	-- Buildings
	oat = hex("#F8ECD2"), -- default walls
	woodDark = hex("#9A6534"),
	woodLight = hex("#DDA868"),
	stone = hex("#A8A3B8"),
	stoneDark = hex("#8A8599"),
	stoneLight = hex("#C9C5D6"),
	glass = hex("#8FD0EE"), -- window panes (sky blue)
	glassDeep = hex("#5FB3DE"),
	lantern = hex("#FFD98A"),
	roofRed = hex("#D9534F"),
	roofTeal = hex("#3AA6A0"),
	roofMustard = hex("#F2B33D"),
	roofPlum = hex("#8E5A8C"),
	barnRed = hex("#C8463F"),
	sky = hex("#8FD0EE"),
	plum = hex("#8E5A8C"),
	brick = hex("#C9694F"),
	cork = hex("#D9A066"),
	metal = hex("#9FA8B3"),
	tire = hex("#5A4636"), -- tyres and dark details stay warm, not black

	-- Plants
	leaf = hex("#5E9E32"),
	leafLight = hex("#7FC241"),
	lime = hex("#8BD346"),
	treeTop = hex("#6CC24A"),
	treeTopDark = hex("#52A63C"),
	trunk = hex("#8C5A33"),
	flowerPink = hex("#F48FB1"),
	flowerYellow = hex("#FFE066"),
	flowerWhite = hex("#FFF6E5"),

	-- Crops (most saturated things on screen)
	wheat = hex("#EDB93C"),
	wheatHead = hex("#FFD966"),
	wheatGreen = hex("#9BCF4E"),
	corn = hex("#FFD83B"),
	cornLeaf = hex("#5FB63E"),
	cornTassel = hex("#E9C46A"),
	carrot = hex("#FF8A2B"),
	carrotTop = hex("#4FAE3B"),
	cane = hex("#A6D45A"),
	caneDark = hex("#7A9E3A"),
	canePlum = hex("#9C5C8E"),
	cotton = hex("#FFF6E5"),
	cottonShrub = hex("#6E8F3A"),
	cottonHusk = hex("#9A6534"),
	seed = hex("#E8D3A6"),
	sprout = hex("#8BD346"),

	-- Animals
	cowCoat = hex("#FFF6E5"),
	cowPatch = hex("#D08A4E"),
	cowMuzzle = hex("#F4A6A0"),
	horn = hex("#F4E6C8"),
	hen = hex("#FFF6E5"),
	henWing = hex("#E0B07A"),
	comb = hex("#F2655A"),
	beak = hex("#F7A23B"),
	wool = hex("#FFF6E5"),
	sheepFace = hex("#5B6478"),
	eye = hex("#4A3426"),

	-- Goods and props
	milk = hex("#FFF6E5"),
	egg = hex("#F7E7CE"),
	bread = hex("#D98E3D"),
	crate = hex("#D9A066"),
	sack = hex("#D8BE8C"),

	-- Townsfolk (Art/Folk): a range of skin tones, and hair
	skinLight = hex("#F6D2B0"),
	skinTan = hex("#D9A57B"),
	skinDeep = hex("#A86F4C"),
	skinUmber = hex("#7A4E35"),
	hairDark = hex("#5A3B2A"),
	hairGinger = hex("#C8693A"),
	hairGrey = hex("#C9C5D6"),
}

return table.freeze(Palette)

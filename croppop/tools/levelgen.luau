--[[
	Crop Pop level generator. Builds levels 6..325 from original shape and
	obstacle patterns, then tunes each level's moves with the test bot until
	its win rate is near the target for its place in the game.

	Run from the croppop/ folder (prints Luau text for each level):

		luaurun tools/levelgen.luau 6 325 > /tmp/levels.txt

	The output is pasted into src/shared/Levels/SetNN.luau. Levels are fixed
	once they ship, so this tool is for making new ones and retuning drafts;
	hand edits in the level editor win over regenerating.

	Same id, same level: every choice comes from an Rng seeded by the id.
]]

local load = loadmodule(readfile("tools/loadshared.luau"), "tools/loadshared.luau", setmetatable({}, { __index = _G }))()
local Bot = load("Bot")
local Engine = load("Engine")
local Matcher = load("Matcher")
local LevelText = load("LevelText")
local Levels = load("Levels")
local Rng = load("Rng")
local Tiles = load("Tiles")

local FIRST = tonumber(ARGS[1]) or 6
local LAST = tonumber(ARGS[2]) or 1150
local GAMES = tonumber(ARGS[3]) or 48

-- Names for levels 6 onwards, in order.
local NAMES = {
	"Clover Patch", "Barn Dance", "Dewy Morning", "Fence Post", "Puddle Jump",
	"Haystack Hill", "Sprout Lane", "Muddy Boots", "Golden Rows", "Rooster Call",
	"Picnic Field", "Windmill Way", "Carrot Top", "Butter Churn", "Bramble Path",
	"Sheep Shearing", "Orchard Gate", "Rainy Day", "Tractor Tracks", "Honey Hollow",
	"Sunflower Bend", "Woolly Hills", "Corncrib Corner", "Egg Hunt", "Market Morning",
	"Mill Pond", "Scarecrow Watch", "Hay Loft", "Berry Bramble", "Cattle Crossing",
	"Frosty Furrows", "Harvest Moon", "Duck Pond", "Weathervane", "Goat Gully",
	"Tomato Terrace", "Milk Run", "Seed Bag", "Garden Gate", "Plough Line",
	"Cobble Yard", "Stable Row", "Lantern Lane", "Thistle Down", "Brook Bridge",
	"Meadow Maze", "Sugar Beet", "Old Oak", "Chicken Coop", "Root Cellar",
	"Willow Bank", "Hilltop Farm", "Dusty Road", "Cider Press", "Turnip Turn",
	"Bluebell Glade", "Pasture Loop", "Wheelbarrow", "Silo Shadow", "Henhouse Hustle",
	"Wild Oats", "Rolling Bales", "Cornflower Field", "Barnyard Bustle", "Cowbell Valley",
	"Sowing Season", "Clay Pots", "Sunset Shed", "Rusty Gate", "Fieldstone Wall",
	"Haywagon Ride", "Bumble Meadow", "Morning Milking", "Muddy Ditch", "Woolpack Lane",
	"Spud Rows", "Lavender Ridge", "Pea Pod", "Grain Store", "Foggy Fields",
	"Rain Barrel", "Tilled Earth", "Picket Fence", "Goose Green", "Saddle Hill",
	"Acorn Grove", "Market Stall", "Cabbage Corner", "Shearing Shed", "Harvest Feast",
	"Starry Paddock", "Lucky Horseshoe", "Fresh Furrows", "Apple Cart", "Golden Harvest",
	"Pumpkin Patch", "Hayride Hollow", "Gourd Garden", "Cranberry Bog", "Maple Lane",
	"Squash Rows", "Barley Maze", "Apple Bobbing", "Barn Owl", "Harvest Fair",
	"Leaf Pile", "Cider Mill", "Pumpkin Pie", "Bonfire Night", "Walnut Grove",
	"Haystack Maze", "Autumn Mist", "Turnip Lanterns", "Root Market", "Giant Gourd Show",
	"Hazel Hedge", "First Frost", "Harvest Supper", "Quilting Bee", "Moonlit Pumpkins",
	"Lucky Clover", "Green Pasture", "Mossy Stones", "Shamrock Hill", "Grand Harvest Ball",
	"Hedgerow", "Barn Swallow", "Fern Hollow", "Sheepfold", "Meadowsweet",
	"Gooseberry Lane", "Paddock Gate", "Summer Breeze", "Clover Honey", "Village Fete",
	"Nettle Bank", "Plum Orchard", "Dandelion Clock", "Rye Field", "Kitchen Garden",
	"Mill Wheel", "Lamb Meadow", "Buttercup Lane", "Cloverleaf Crossing", "Golden Meadows",
	"Old Stone Wall", "Frozen Pond", "Woodpile", "Snowy Barn", "Quarry Road",
	"Hot Cocoa", "Sleigh Path", "Winter Wheat", "Holly Bush", "Midwinter Market",
	"Pine Cone Lane", "Icicle Eaves", "Mitten Hill", "Rock Garden", "Hearth Bread",
	"Snowdrop Field", "Chimney Smoke", "Wool Socks", "Lantern Walk", "Winter Feast",
	"Cobblestone Bridge", "Robin's Perch", "Frosted Turnips", "Firelight Barn", "New Year Fields",
	"Rabbit Warren", "Mole Hills", "Hidden Burrow", "Well Bucket", "Tunnel Lane",
	"Fox Den", "Badger Sett", "Secret Garden", "Rain Chute", "Grain Chute",
	"Twisting Furrows", "Hollow Log", "Mill Race", "Cellar Steps", "Topsy Turvy Barn",
	"Spring Thaw", "Lambing Season", "Seedling Trays", "April Showers", "Daffodil Dell",
	"Nesting Box", "Blossom Orchard", "Spring Fair", "Hop Garden", "Maypole Meadow",
	"Pumpkin Basket", "Wicker Lane", "Harvest Hamper", "Strawberry Rows", "Bean Poles",
	"Sheaf Corner", "Midsummer Hay", "Basket Weaver", "Beehive Hill", "Market Baskets",
	"Pea Shoots", "Cherry Ladder", "Lazy River", "Haymakers", "Sunny Hamper",
	"Picking Season", "Watering Can", "Gooseberry Fool", "Cart Track", "Long Meadow",
	"Garden Party", "Cucumber Frame", "Lark Rise", "Hamper Hill", "Summer Show",
	"Split Rail", "Paddock Fence", "Gate Latch", "Stile Steps", "Hurdle Run",
	"Pony Ring", "Fence Mending", "Hedge Gap", "Sheep Pen", "Rail Yard Farm",
	"Post and Rail", "Calf Pen", "Wattle Hurdles", "Cattle Grid", "Kissing Gate",
	"Goat Pen", "Corral Corner", "Field Boundary", "Picket Path", "County Show",
	"Fence Painting", "Pig Sty", "Fold Yard", "Boundary Walk", "Grand Gate",
	"Sticky Situation", "Bog Lane", "Marsh Meadow", "Slimy Ditch", "Frog Pond",
	"Swamp Hollow", "Reed Bed", "Squelchy Path", "Duckweed Dip", "Goo Lagoon",
	"Wetland Walk", "Peat Moss", "Slime Pond", "Mire Farm", "Newt Corner",
	"Soggy Bottom", "Cattail Creek", "Bullfrog Bend", "Muck Spreader", "Ooze Ridge",
	"Willow Marsh", "Dragonfly Dell", "Heron Wade", "Sludge Pump", "Great Bog Fair",
	"Hen House", "Speckled Hen", "Nest Egg", "Coop Corner", "Clucking Lane",
	"Roost Row", "Egg Basket Hill", "Bantam Yard", "Morning Lay", "Henhouse Hollow",
	"Brown Eggs", "Feather Field", "Chick Run", "Perch Point", "Egg Market",
	"Rooster Ridge", "Hatching Day", "Scratch Yard", "Free Range", "Golden Egg",
	"Dovecote", "Poultry Show", "Corn Feed", "Broody Hen", "Grand Coop Fair",
	"Surprise Crate", "Mystery Barn", "Lucky Dip", "Parcel Post", "Gift Wagon",
	"Harvest Hamper Hunt", "Hidden Treasure", "Crate Stack", "Peddler's Cart", "Treasure Trove",
	"Bran Tub", "Wrapped Bales", "Prize Pumpkin", "Raffle Day", "Secret Seeds",
	"Market Crates", "Packing Shed", "Delivery Day", "Lucky Crate", "Jumble Sale",
	"Toy Box Barn", "Crate Maze", "Box Social", "Surprise Party", "Grand Prize Fair",
	"Buried Statue", "Old Relic", "Dig Site", "Sundial Square", "Garden Bust",
	"Village Green Monument", "Sandy Dig", "Stone Lion", "Founders' Plinth", "Fossil Field",
	"Moss Statue", "Bell Tower Dig", "Relic Row", "Market Cross", "Weathered Bust",
	"Statue Garden", "Lost Monument", "Old Well", "Treasure Dig", "Hidden Relic",
	"Spade Day", "Ancient Arch", "Statue Walk", "Digger's Delight", "Grand Unveiling",
	"Goo Spring", "Bubbling Well", "Slime Fountain", "Green Geyser", "Seep Hollow",
	"Mossy Spout", "Fen Spring", "Gurgle Gully", "Murky Fountain", "Spring Clean",
	"Frogspawn Pool", "Bubble Bog", "Lily Fountain", "Spout Lane", "Burbling Brook",
	"Sticky Spring", "Swamp Geyser", "Toad Hall Well", "Pond Dipping", "Bog Spring",
	"Wellspring Farm", "Drizzle Dell", "Fountain Square", "Gushing Gulch", "Grand Spring Gala",
	"Tarp Rolling", "Canvas Cover", "Market Awning", "Striped Tent", "Rainy Day Tarp",
	"Hay Wagon Cover", "Marquee Meadow", "Shade Sail", "Roll-Up Barn", "Fair Tent",
	"Canvas Corner", "Picnic Awning", "Tarpaulin Lane", "Circus Field", "Rain Cover",
	"Pavilion Green", "Wagon Tilt", "Big Top Farm", "Awning Alley", "Show Tent",
	"Bunting Row", "Stall Covers", "Tent Pegs", "Rolling Shade", "Grand Marquee Fair",
	"Thick Goo", "Gloopy Gully", "Treacle Tarn", "Syrup Swamp", "Mudlark Marsh",
	"Gumbo Bog", "Porridge Pond", "Custard Creek", "Molasses Mill", "Glue Pot Lane",
	"Toffee Fen", "Jelly Mire", "Stodgy Ditch", "Sticky Wicket", "Gooseberry Gloop",
	"Bubble and Squeak", "Thicket Bog", "Goo Goliath", "Slurry Puddle", "Swamp King",
	"Clotted Creek", "Gumdrop Glade", "Mire Maze", "Deep Bog Day", "Grand Goo Gala",
	"Rainbow Patch", "Painted Pots", "Dye Works", "Colour Wheel", "Prism Meadow",
	"Paint Pot Lane", "Shifting Sands", "Kaleidoscope Farm", "Rainbow Row", "Flower Show Dye",
	"Hue Hollow", "Bright Barn", "Spectrum Field", "Tie-Dye Day", "Chameleon Corner",
	"Painted Ponies", "Colour Swap Shop", "Stained Glass Mill", "Sunset Shades", "Rainbow Ridge",
	"Paintbox Pasture", "Crayon Croft", "Easel Lane", "Prism Pond", "Grand Rainbow Fair",
	"Spider Webs", "Cobweb Corner", "Dewy Webs", "Attic Barn", "Tangled Hedge",
	"Old Shed", "Lacy Lane", "Silk Meadow", "Webbed Window", "Spinner's Loft",
	"Morning Dew", "Dusty Rafters", "Gossamer Glen", "Hayloft Webs", "Knotty Pine",
	"Tangle Wood", "Cobweb Cottage", "Misty Gate", "Woodshed Webs", "Spider Hollow",
	"Lantern Barn", "Netting Nook", "Thread Mill", "Web of Hedges", "Grand Lantern Ball",
	"Patchwork Quilt", "Sewing Bee", "Granny's Quilt", "Thimble Lane", "Rag Rug Row",
	"Calico Corner", "Button Barn", "Mending Day", "Gingham Picnic", "Quilting Fair",
	"Needle Point", "Cotton Field", "Bobbin Mill", "Stitch in Time", "Hearth Rug",
	"Darning Nook", "Woolly Fold", "Pincushion Hill", "Flannel Farm", "Lavender Sachet",
	"Feather Quilt", "Spinning Wheel", "Tea Cosy Cottage", "Seamstress Row", "Grand Quilt Show",
	"Seed Sacks", "Sowing Day", "Meadow Mix", "Seed Drill", "Wildflower Bank",
	"Lawn Party", "Sack Race", "Turf Trouble", "Bird Seed Lane", "Planting Time",
	"Seedling Row", "Grassy Knoll", "Meadow Sweep", "Sower's Path", "Lucky Sack",
	"Feed Store", "Nursery Beds", "Oat Furrows", "Sprout Hill", "Seed Swap",
	"Fresh Turf", "Allotment Day", "Barley Rows", "Topsoil Top-Up", "Grand Sowing Fair",
	"Snowball Fight", "First Snow", "Winter Lane", "Sledge Hill", "Icicle Barn",
	"Snowdrift Farm", "Mitten Market", "Cold Snap", "Skating Pond", "Snowman Meadow",
	"Hot Cocoa Hut", "Winter Turnips", "Sleigh Bells", "Chilly Orchard", "Yule Log Lodge",
	"Snowflake Lane", "Woolly Hats", "Ice Rink", "Blizzard Barn", "Snowy Owl Wood",
	"Fireside Farm", "Winter Market", "Snowcap Peak", "Frosty Lanterns", "Grand Winter Ball",
	"Clay Pit", "Potter's Wheel", "Kiln Corner", "Terracotta Terrace", "Flower Pots",
	"Brickyard Lane", "Glazed Jugs", "Pottery Fair", "Cider Crocks", "Red Earth Ridge",
	"Clay Oven Bakery", "Honey Jars", "Mosaic Puddle", "Tile Works", "Kiln Fire Night",
	"Garden Urns", "Clay Court", "Teapot Cottage", "Earthenware Row", "Pitcher Plant Pond",
	"Butter Churn Barn", "Chimney Pots", "Dovecote Yard", "Clay Pigeon Field", "Grand Pottery Show",
	"Mail Day", "Postman's Round", "Letterbox Lane", "Love Letters", "Postcard Hill",
	"Stamp Collector", "Mail Coach Road", "Sorting Office", "Envelope Lane", "Courier Cross",
	"Thank-You Notes", "Post Horn Hollow", "Farmhouse Post", "Signal Hill", "Pigeon Post",
	"Morning Mail", "Wax Seal Way", "Riverside Post", "Inkwell Cottage", "First Class Farm",
	"Birthday Cards", "Letter Rack Lodge", "Pillar Post Row", "Airmail Puddle", "Grand Post Day",
	"Scarecrow Field", "Crow's Nest", "Straw Hat Hill", "Rookery Wood", "Harvest Moonrise",
	"Magpie Lane", "Corn Dolly Fair", "Straw Man Meadow", "Raven Ridge", "Hat Trick Farm",
	"Stubble Ditch", "Old Scarecrow Inn", "Blackbird Barn", "Ragged Coat Croft", "Crowfoot Pond",
	"Barley Twist", "Turnip Head Hill", "Rook's Rest", "Strawstack Lane", "Jackdaw Corner",
	"Ember Glow Night", "Starling Sky", "Cornfield Ditch", "Owl Barn Loft", "Grand Harvest Supper",
	"Bucket Brigade", "Milk Pail Morning", "Wash Day", "Spilt Milk", "Slop Trough",
	"Splash Lane", "Drizzle Corner", "Mop and Pail", "Water Pump Yard", "Bucket Bath Night",
	"Pail Fair", "Duck Pond Dash", "Spillway Mill", "Water Carrier", "Bucket List",
	"Soapsuds Yard", "Pig Wallow", "Trough Hollow", "Dairy Churns", "Rainy Lane",
	"Splashdown", "Tipping Point", "Rubber Boots", "Bucket Head Hill", "Grand Splash Gala",
	"First Market Morning", "Produce Run", "Village Grocer", "Stacked High", "Farm Shop Friday",
	"Pallet Yard", "Doorstep Delivery", "Orchard Haul", "Saturday Market", "Wholesale Barn",
	"Fruit Stall Row", "Loading Bay", "Grocer's Lane", "Packing House Hill", "Market Town Fair",
	"Carrot Stall", "Harvest Haul", "Stacking Season", "Corner Shop", "Grand Market Day",
	"Cider Stall Yard", "Barrow Boy Lane", "Produce Show", "Night Market", "Market Square Gala",
	"Hedgerow Lane", "Privet Path", "Hawthorn Hollow", "Garden Maze", "Topiary Court",
	"Quickset Walk", "Laurel Row", "Hedge Fund Farm", "Yew Tree Walk", "Maze Runner Meadow",
	"Holly Bush Hill", "Beech Hedge Bend", "Shrubbery Square", "Hornbeam Lane", "Hedge Row Manor",
	"Thicket Way", "Wild Man Maze", "Hedgehog Hollow", "Sweetbriar Lane", "Field Hedge Way",
	"Hedge Laying Day", "Juniper Walk", "Windbreak Row", "Labyrinth Gardens", "Grand Garden Maze",
	"Honey Hive", "Beekeeper's Cottage", "Nectar Lane", "Wildflower Apiary", "Mead Hall",
	"Pollen Path", "Lavender Hives", "Honeycomb Hill", "Swarm Season", "Buzzing Orchard",
	"Sunflower Rise", "Golden Comb Farm", "Royal Jelly Lane", "Heather Moor", "Hive Mind Meadow",
	"Drone Day", "Busy Bee Lane", "Nectar Night", "Queen Bee Court", "Grand Honey Show",
	"Smoker's Shed", "Wax Candle Row", "Linden Blossom", "Honey Fair", "Golden Hive Gala",
	"Hay Truck Day", "Wagon Wheel Way", "Flatbed Farm", "Convoy Crossing", "Haulage Yard",
	"Pickup Lane", "Lorry Park", "Truck Stop Diner", "Wagon Trail", "Barn Delivery Run",
	"Country Road", "Tow Rope Hill", "Dusty Wheels", "Haystack Run", "Grand Wagon Race",
	"Harvest Convoy", "Long Road Home", "Old Truck Barn", "Gravel Track", "Wagon Fair",
	"Fuel Stop", "Rolling Wagons", "Dairy Run", "Flatbed Festival", "Grand Truck Parade",
	"Snail Trail Lane", "Garden Shell Path", "Slow Lane Orchard", "Slug Hollow", "Spiral Shell Dell",
	"Morning Dew Walk", "Snail Race Day", "Lettuce Leaf Row", "Shell Shock Field", "Grand Snail Derby",
	"Rainy Day Rambles", "Escargot Corner", "Silver Trail Way", "Damp Fern Glen", "Snail's Pace Show",
	"Cabbage Row Crawl", "Whorl Shell Hill", "Dewdrop Garden", "Slugabed Lane", "Snail Shell Fair",
	"Mossy Bank", "Shellback Row", "Leafy Lane End", "Slow Coach Lane", "Grand Shell Parade",
	"Tulip Time", "Bulb Field", "Petal Path", "First Bloom", "Windmill Tulips",
	"Blossom Way", "Morning Bloom", "Flower Show Lane", "Rosebud Row", "Grand Tulip Gala",
	"Posy Corner", "Daisy Chain Dell", "Bluebell Wood", "Florist's Yard", "Petal Parade",
	"Tulip Fields", "Bouquet Lane", "Buttercup Bank", "Bulb Barn", "Golden Bloom Fair",
	"Lilac Lane", "Peony Path", "Crocus Corner", "Bud Break Hill", "Grand Flower Festival",
	"Lost Lamb Lane", "Shepherd's Walk", "Flock Hill", "Woolly Rise", "Ewe Turn",
	"Little Lambs", "Sheepfold Yard", "Sheepdog Trials", "Bleating Brook", "Grand Sheep Show",
	"Crook and Bell", "Lambing Time", "Woolpack Road", "Shearing Day", "Ram's Horn Hill",
	"Counting Sheep", "Fleece Fair", "Black Sheep Row", "Shepherd's Rest", "Grand Flock Parade",
	"Lamb's Tail Lane", "Drover's Road", "Highland Flock", "Homeward Lambs", "Golden Fleece Gala",
	"Firefly Field", "Glow Worm Lane", "Twilight Pasture", "Dusk Till Dawn", "Paper Lantern Walk",
	"Moonlit Orchard", "Evening Glow", "Night Owl Barn", "Starry Hollow", "Glimmer Glen",
	"Firefly Dance", "Lantern Row", "Moonbeam Rise", "Night Sky Farm", "Grand Lantern Night",
	"Glow Brook", "Twilight Rows", "Midsummer Eve", "Dusky Dell", "Lantern Fair",
	"Firefly Hollow", "Moonrise Ridge", "Starlight Yard", "Night Harvest", "Grand Firefly Festival",
	"Tray Day", "Windowsill Farm", "Glasshouse Lane", "First Shoots", "Little Cloches",
	"Propagator Path", "Punnet Place", "Shoot Up Hill", "Dibber Dell", "Grand Tray Parade",
	"Germination Way", "Cutting Corner", "Plug Plant Plot", "Hothouse Hill", "Tray Table Fair",
	"Cloche Corner", "Tender Shoots", "Root Run", "Leafing Out", "Grand Hothouse Show",
	"Tiny Leaves Lane", "Two Leaf Rise", "Pricking Out", "Hardening Off", "Grand Glasshouse Gala",
	"Compost Corner", "Mulch Mile", "Wormery Way", "Leaf Mould Lane", "Peelings Path",
	"Scrap Heap Hill", "Humus Hollow", "Rich Loam Rise", "Compost Cart", "Grand Compost Fair",
	"Turning the Heap", "Garden Scraps", "Wormcast Walk", "Kitchen Peelings", "Mulch Mound",
	"Black Gold Bank", "Humus Heights", "Loam Lea", "Heap Hollow", "Grand Mulch Show",
	"Leaf Litter Lane", "Peat Free Plot", "Worm Farm Way", "Rotted Leaf Rise", "Grand Compost Gala",
	"Flood Plain", "Pump House", "Water Lane", "Soggy Boots", "Drain Dale",
	"Sluice Way", "Marsh Lane", "Splash Down", "Hand Pump Hill", "Grand Flood Fair",
	"Downpour Drive", "Deluge Dell", "Overflow Yard", "Wetland Trail", "Brimming Banks",
	"Pump Handle Row", "Water Wheel", "Flood Barrier", "Soggy Socks", "Grand Pump Show",
	"Marshland Mile", "Splashy Lane", "Drainpipe Dash", "Water Works", "Grand Deluge Gala",
	"Packet Path", "Sachet Square", "Pouch Pond", "Catalogue Corner", "Heirloom Hill",
	"Variety Lane", "Packet Parade", "Mixed Rows", "Garden Centre Way", "Grand Packet Fair",
	"Heirloom Orchard", "Sachet Sunday", "Pouch Pocket", "Packet Lane", "Variety Show",
	"Mixed Bag Mile", "Heirloom Hollow", "Catalogue Club", "Sachet Street", "Grand Variety Gala",
	"Packet Picnic", "Pouch Point", "Heirloom Harvest", "Garden Centre Sale", "Grand Heirloom Show",
	"Mower Lane", "Grass Verge", "Striped Rows", "Croquet Court", "Cricket Pitch",
	"Mowing Day", "Clippings Corner", "Trim Path", "Sunday Mowing", "Grand Mower Fair",
	"Verge View", "Grass Track", "Stripe Street", "Croquet Club", "Tall Grass Rise",
	"Ride-On Ridge", "Mower Shed Lane", "Trimmed Edge", "Cricket Field", "Grand Grass Show",
	"Clippings Cart", "Verge Walk", "Mowing Match", "Stripe Lane", "Grand Croquet Gala",
	"Gopher Gully", "Burrow Bank", "Molehill Mound", "Warren Walk", "Tunnel Turn",
	"Gopher Hop", "Burrow Row", "Peekaboo Plot", "Hidey Hole Hill", "Grand Gopher Fair",
	"Molehill Rise", "Warren Way", "Tunnel Vision", "Gopher Grove", "Bolt Hole Bend",
	"Burrow Brook", "Pop Up Path", "Warren End", "Hidey Hole Lane", "Grand Burrow Show",
	"Tunnel Twist", "Gopher Gardens", "Molehill Meander", "Burrow Bend", "Grand Thousand Gala",
	"Jam Jar Lane", "Pickle Path", "Preserve Place", "Larder Lookout", "Grand Jam Fair",
	"Chutney Corner", "Marmalade Mile", "Pantry Shelf", "Jelly Jump", "Grand Preserve Show",
	"Jar Lid Lane", "Pickling Day", "Larder Loft", "Chutney Chase", "Grand Pickle Gala",
	"Jam Tart Terrace", "Pantry Parade", "Marmalade Morning", "Jelly Junction", "Grand Larder Fair",
	"Jam Kitchen", "Pickle Pantry", "Chutney Cottage", "Marmalade Moor", "Grand Jam Jamboree",
	"Tool Chest Trail", "Spanner Street", "Hammer Hill", "Workbench Way", "Grand Toolbox Fair",
	"Wrench Walk", "Chest Corner", "Spanner Square", "Hammer Hollow", "Grand Tool Show",
	"Toolbox Terrace", "Workbench Bend", "Wrench Row", "Chest Lane", "Grand Workbench Gala",
	"Hammer Heights", "Spanner Spinney", "Toolbox Track", "Wrench Wood", "Grand Hammer Fair",
	"Chest Common", "Toolkit Lane", "Spanner Ridge", "Workbench Walk", "Grand Tool Chest Gala",
	"Weathervane Way", "Cockerel Crest", "Windy Corner", "Compass Court", "Grand Vane Fair",
	"Breezy Bank", "Cockerel Close", "Gusty Lane", "North Wind Knoll", "Grand Cockerel Show",
	"Vane Hill", "Spinning Spire", "Windy Walk", "Compass Crossing", "Grand Breeze Gala",
	"Vane Rise", "Gusty Gap", "Breezy Brow", "Cockerel Corner", "Grand Weathervane Fair",
	"Windy Wold", "Spire Top", "Compass Point", "Weathercock Wood", "Grand Whirlwind Gala",
	"Vine Valley", "Ivy Lane", "Creeper Corner", "Trellis Track", "Grand Vine Fair",
	"Clematis Bank", "Tendril Trail", "Wisteria Walk", "Arbour Avenue", "Grand Ivy Show",
	"Vineyard View", "Ivy Cottage", "Creeper Crescent", "Trellis Terrace", "Grand Clematis Gala",
	"Tendril Turn", "Wisteria Way", "Arbour Close", "Vine Arch", "Grand Trellis Fair",
	"Ivy Hollow", "Creeper Copse", "Clematis Brook", "Tendril Tops", "Grand Eleven Hundred Gala",
	"Misty Morning", "Fog Bank", "Haze Hill", "Murky Mere", "Grand Mist Fair",
	"Steamy Lane", "Dewy Dell", "Cloudy Corner", "Fog Bottom Ford", "Grand Fog Show",
	"Hazy Hollow", "Misty Moor", "Vapour Vale", "Murky Mile", "Grand Haze Gala",
	"Dew Drop Drive", "Cloud Bank", "Steamy Gully", "Fog Hollow", "Grand Misty Fair",
	"Hazy Heath", "Vapour Trail", "Dewy Downs", "Murky Lane", "Grand Cloudburst Gala",
	"Washing Day", "Scrubbing Lane", "Rinse Row", "Soapy Hill", "Grand Wash Fair",
	"Suds Corner", "Sponge Street", "Lather Lane", "Washtub Walk", "Grand Scrub Show",
	"Rinsing Ridge", "Soap Suds Square", "Scrub Brush Bend", "Washline Way", "Grand Rinse Gala",
	"Sudsy Steps", "Sponge Dale", "Scrubland Row", "Lather Loft", "Grand Washday Gala",
	"Rinse Cycle Close", "Soapy Dell", "Washboard Way", "Scrub Yard", "Grand Lather Fair",
}

-- Township-like move counts: long enough to plan, short enough to stay tense.
local MIN_MOVES, MAX_MOVES = 15, 35
local MAX_COLLECT = 45
local FROST_INTRO = 21 -- first level with frost
local WEEDS_INTRO = 41 -- first level with weeds
local PUMPKIN_INTRO = 101 -- first level with pumpkins
local CLOVER_INTRO = 126 -- first level with clover
local STONE_INTRO = 151 -- first level with stone walls
local PORTAL_INTRO = 176 -- first level with portals
local BASKET_INTRO = 201 -- first level with pumpkin baskets
local FENCE_INTRO = 226 -- first level with fences
local GOO_INTRO = 251 -- first level with goo
local HEN_INTRO = 276 -- first level with hen houses
local CRATE_INTRO = 301 -- first level with surprise crates
local STATUE_INTRO = 326 -- first level with buried statues
local SPRING_INTRO = 351 -- first level with goo springs
local TARP_INTRO = 376 -- first level with tarps
local THICK_GOO_INTRO = 401 -- first level with thick goo
local RAINBOW_INTRO = 426 -- first level with rainbow patches
local WEB_INTRO = 451 -- first level with webs
local QUILT_INTRO = 476 -- first level with quilts and sewing tins
local SACK_INTRO = 501 -- first level with seed sacks
local SNOW_INTRO = 526 -- first level with snowballs
local CLAY_INTRO = 551 -- first level with clay
local MAIL_INTRO = 576 -- first level with mailboxes
local SCARECROW_INTRO = 601 -- first level with scarecrows
local BUCKET_INTRO = 626 -- first level with mud buckets
local BOX_INTRO = 651 -- first level with produce box stacks
local HEDGE_INTRO = 676 -- first level with hedges
local HIVE_INTRO = 701 -- first level with beehives
local TRUCK_INTRO = 726 -- first level with hay trucks
local SNAIL_INTRO = 751 -- first level with garden snails
local BUD_INTRO = 776 -- first level with tulip buds
local LAMB_INTRO = 801 -- first level with lost lambs
local FIREFLY_INTRO = 826 -- first level with firefly spots
local TRAY_INTRO = 851 -- first level with seed trays
local BIN_INTRO = 876 -- first level with compost bins
local PUMP_INTRO = 901 -- first level with flood water and hand pumps
local PACKET_INTRO = 926 -- first level with seed packets
local MOWER_INTRO = 951 -- first level with lawn mowers
local GOPHER_INTRO = 976 -- first level with gopher burrows
local JAR_INTRO = 1001 -- first level with jam jars
local CHEST_INTRO = 1026 -- first level with tool chests
local VANE_INTRO = 1051 -- first level with weathervanes
local VINE_INTRO = 1076 -- first level with vines
local MIST_INTRO = 1101 -- first level with mist
local MUDDY_INTRO = 1126 -- first level with muddy pumpkins
local INTROS = { [MUDDY_INTRO] = true, [MIST_INTRO] = true, [VINE_INTRO] = true, [VANE_INTRO] = true, [CHEST_INTRO] = true, [JAR_INTRO] = true, [GOPHER_INTRO] = true, [MOWER_INTRO] = true, [PACKET_INTRO] = true, [PUMP_INTRO] = true, [BIN_INTRO] = true, [TRAY_INTRO] = true, [FIREFLY_INTRO] = true, [LAMB_INTRO] = true, [BUD_INTRO] = true, [SNAIL_INTRO] = true, [TRUCK_INTRO] = true, [HIVE_INTRO] = true, [HEDGE_INTRO] = true, [BOX_INTRO] = true, [BUCKET_INTRO] = true, [SCARECROW_INTRO] = true, [MAIL_INTRO] = true, [CLAY_INTRO] = true, [SNOW_INTRO] = true, [SACK_INTRO] = true, [QUILT_INTRO] = true, [WEB_INTRO] = true, [RAINBOW_INTRO] = true, [THICK_GOO_INTRO] = true, [TARP_INTRO] = true, [SPRING_INTRO] = true, [STATUE_INTRO] = true, [CRATE_INTRO] = true, [HEN_INTRO] = true, [GOO_INTRO] = true, [FENCE_INTRO] = true, [BASKET_INTRO] = true,  [FROST_INTRO] = true, [WEEDS_INTRO] = true, [PUMPKIN_INTRO] = true, [CLOVER_INTRO] = true, [STONE_INTRO] = true, [PORTAL_INTRO] = true }

local REWARDS = {
	Normal = { coins = 25, xp = 5 },
	Tough = { coins = 50, xp = 10 },
	["Super Tough"] = { coins = 75, xp = 15 },
}

local function difficultyOf(id: number): string
	if id >= 20 and id % 10 == 0 then
		return "Super Tough"
	elseif id % 5 == 0 then
		return "Tough"
	end
	return "Normal"
end

-- Bot win rate to aim for. People do much better than the bot, so these
-- read low; what matters is the step between Normal, Tough and Super Tough.
local function targetOf(id: number, difficulty: string): number
	if difficulty == "Super Tough" then
		return if id <= 50 then 0.25 else 0.2
	elseif difficulty == "Tough" then
		return if id <= 25 then 0.45 elseif id <= 50 then 0.38 else 0.32
	end
	return if id <= 12 then 0.8 elseif id <= 25 then 0.7 elseif id <= 50 then 0.6 else 0.5
end

-- Grid helpers -----------------------------------------------------------------

local function newGrid(w, h, ch)
	local g = { w = w, h = h }
	for y = 1, h do
		g[y] = {}
		for x = 1, w do
			g[y][x] = ch
		end
	end
	return g
end

-- Sets a cell and its left-right mirror (and top-bottom mirror if asked).
local function setSym(g, x, y, ch, both)
	local mx = g.w - x + 1
	local my = g.h - y + 1
	g[y][x] = ch
	g[y][mx] = ch
	if both then
		g[my][x] = ch
		g[my][mx] = ch
	end
end

local function isCell(g, x, y)
	return x >= 1 and x <= g.w and y >= 1 and y <= g.h and g[y][x] ~= "#"
end

local function countCells(g, pred)
	local n = 0
	for y = 1, g.h do
		for x = 1, g.w do
			if pred(g[y][x]) then
				n += 1
			end
		end
	end
	return n
end

-- Every cell reachable from every other, and every column has a cell.
local function connected(g)
	local start
	for y = 1, g.h do
		for x = 1, g.w do
			if g[y][x] ~= "#" then
				start = start or { x, y }
			end
		end
	end
	for x = 1, g.w do
		local any = false
		for y = 1, g.h do
			any = any or g[y][x] ~= "#"
		end
		if not any then
			return false
		end
	end
	local seen, stack, count = {}, { start }, 0
	seen[start[2] * 100 + start[1]] = true
	while #stack > 0 do
		local p = table.remove(stack)
		count += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, ny = p[1] + d[1], p[2] + d[2]
			if isCell(g, nx, ny) and not seen[ny * 100 + nx] then
				seen[ny * 100 + nx] = true
				table.insert(stack, { nx, ny })
			end
		end
	end
	return count == countCells(g, function(c)
		return c ~= "#"
	end)
end

-- Shapes: where the holes go ---------------------------------------------------

local SHAPES = {
	function() end, -- full board
	function(g, rng) -- cut corners
		local k = rng:int(1, 2)
		for y = 1, k do
			for x = 1, k - y + 1 do
				setSym(g, x, y, "#", true)
			end
		end
	end,
	function(g, rng) -- top corners only
		local k = rng:int(1, 3)
		for y = 1, k do
			for x = 1, k - y + 1 do
				setSym(g, x, y, "#")
			end
		end
	end,
	function(g) -- centre hole
		local cx, cy = math.ceil(g.w / 2), math.ceil(g.h / 2)
		setSym(g, cx, cy, "#", true)
		if g.w % 2 == 0 then
			setSym(g, cx, cy - 1, "#", true)
		end
	end,
	function(g, rng) -- side notches
		local y = rng:int(3, g.h - 2)
		setSym(g, 1, y, "#")
		if rng:int(1, 2) == 1 then
			setSym(g, 1, g.h - y + 1, "#")
		end
	end,
	function(g) -- diamond
		local r = math.max(g.w, g.h) // 2 + 1
		local cx, cy = (g.w + 1) / 2, (g.h + 1) / 2
		for y = 1, g.h do
			for x = 1, g.w do
				if math.abs(x - cx) + math.abs(y - cy) > r + 0.5 then
					g[y][x] = "#"
				end
			end
		end
	end,
	function(g, rng) -- pillars
		local x = rng:int(2, math.max(2, g.w // 2 - 1))
		local y = rng:int(3, g.h - 3)
		setSym(g, x, y, "#")
		setSym(g, x, y + 1, "#")
	end,
	function(g) -- hourglass
		local mid = math.ceil(g.h / 2)
		setSym(g, 1, mid, "#")
		if g.h % 2 == 0 then
			setSym(g, 1, mid + 1, "#")
		end
		setSym(g, 1, 1, "#")
		setSym(g, 1, g.h, "#")
	end,
	function(g) -- top teeth
		for x = 1, g.w // 2, 2 do
			setSym(g, x, 1, "#")
		end
	end,
	function(g) -- plus in the middle
		local cx, cy = math.ceil(g.w / 2), math.ceil(g.h / 2)
		setSym(g, cx, cy, "#")
		setSym(g, cx - 1, cy, "#")
		setSym(g, cx, cy - 1, "#")
		setSym(g, cx, cy + 1, "#")
	end,
	function(g) -- bottom corners
		setSym(g, 1, g.h, "#")
		setSym(g, 2, g.h, "#")
		setSym(g, 1, g.h - 1, "#")
	end,
}

-- Obstacle patterns: which cells get mud or bales ------------------------------

-- Each returns a list of {x, y} on the left half (mirrored when placed).
local PATTERNS = {
	rows = function(g, rng)
		local out, step = {}, rng:int(2, 3)
		for y = rng:int(2, 3), g.h, step do
			for x = 2, math.ceil(g.w / 2) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	frame = function(g, rng)
		local out, d = {}, rng:int(1, 2)
		for y = d, g.h - d + 1 do
			for x = d, math.ceil(g.w / 2) do
				if y == d or y == g.h - d + 1 or x == d then
					table.insert(out, { x, y })
				end
			end
		end
		return out
	end,
	bottom = function(g, rng)
		local out = {}
		for y = g.h - rng:int(1, 2), g.h do
			for x = 1, math.ceil(g.w / 2) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	centre = function(g, rng)
		local out, r = {}, rng:int(1, 2)
		local cy = math.ceil(g.h / 2)
		for y = cy - r, cy + r do
			for x = math.ceil(g.w / 2) - r, math.ceil(g.w / 2) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	checker = function(g, rng)
		local out, top = {}, rng:int(1, 3)
		for y = top, g.h do
			for x = 1, math.ceil(g.w / 2) do
				if (x + y) % 2 == 0 then
					table.insert(out, { x, y })
				end
			end
		end
		return out
	end,
	columns = function(g, rng)
		local out, x = {}, rng:int(1, math.ceil(g.w / 2) - 1)
		for y = rng:int(2, 3), g.h do
			table.insert(out, { x, y })
		end
		return out
	end,
	diagonal = function(g)
		local out = {}
		for y = 1, g.h do
			local x = (y % math.ceil(g.w / 2)) + 1
			table.insert(out, { x, y })
		end
		return out
	end,
	scatter = function(g, rng)
		local out = {}
		for _ = 1, rng:int(3, 6) do
			table.insert(out, { rng:int(1, math.ceil(g.w / 2)), rng:int(2, g.h) })
		end
		return out
	end,
}

local MUD_PATTERNS = { "rows", "frame", "bottom", "centre", "checker", "diagonal", "scatter" }
local BALE_PATTERNS = { "fence", "corners", "columns", "centre", "scatter", "pairs" }

local BALES = {
	fence = function(g, rng)
		-- A broken row: never the full width, so pieces can slide past.
		local y, out = rng:int(3, g.h - 1), {}
		for x = 1, math.ceil(g.w / 2) - 1 do
			if x ~= rng:int(1, 3) then
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	corners = function(g, rng)
		local out, k = {}, rng:int(1, 2)
		for y = g.h - k, g.h do
			for x = 1, k + 1 - (g.h - y) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	columns = PATTERNS.columns,
	centre = function(g, rng)
		local cy = rng:int(3, g.h - 2)
		local cx = math.ceil(g.w / 2)
		return { { cx, cy }, { cx, cy + 1 }, { cx - 1, cy + 1 } }
	end,
	scatter = PATTERNS.scatter,
	pairs = function(g, rng)
		local out = {}
		for _ = 1, rng:int(2, 3) do
			local x, y = rng:int(1, math.ceil(g.w / 2) - 1), rng:int(3, g.h)
			table.insert(out, { x, y })
			table.insert(out, { x + 1, y })
		end
		return out
	end,
}

-- What a level is about, by id ---------------------------------------------------

local function mechanics(id)
	return {
		thickMud = id >= 13, -- "M"
		bales2 = id >= 9,
		bales3 = id >= 26,
		sixColors = id >= 30,
		frost = id >= FROST_INTRO, -- "f"
		thickFrost = id >= 33, -- "F"
		weeds = id >= WEEDS_INTRO, -- "w"
		pumpkins = id >= PUMPKIN_INTRO, -- "p"
		clover = id >= CLOVER_INTRO, -- "c"
		stones = id >= STONE_INTRO, -- "s"
		thickStones = id >= 160, -- "S"
		portals = id >= PORTAL_INTRO, -- level.portals
		baskets = id >= BASKET_INTRO, -- "d"
		fences = id >= FENCE_INTRO, -- level.fences
		goo = id >= GOO_INTRO, -- "g"
		hens = id >= HEN_INTRO, -- "h"
		crates = id >= CRATE_INTRO, -- "x"
		statues = id >= STATUE_INTRO, -- "b"
		springs = id >= SPRING_INTRO, -- "G"
		tarps = id >= TARP_INTRO, -- "t"
		thickGoo = id >= THICK_GOO_INTRO, -- "e"
		rainbow = id >= RAINBOW_INTRO, -- "r"
		webs = id >= WEB_INTRO, -- "n"
		quilts = id >= QUILT_INTRO, -- "q" and "k"
		sacks = id >= SACK_INTRO, -- "z"
		snowballs = id >= SNOW_INTRO, -- "i"
		clay = id >= CLAY_INTRO, -- "a" and "A"
		mail = id >= MAIL_INTRO, -- "l" and "L"
		scarecrows = id >= SCARECROW_INTRO, -- "y"
		buckets = id >= BUCKET_INTRO, -- "u"
		boxes = id >= BOX_INTRO, -- "v" and "V"
		hedges = id >= HEDGE_INTRO, -- level.fences with side "R" or "D"
		hives = id >= HIVE_INTRO, -- "j"
		trucks = id >= TRUCK_INTRO, -- "C"
		snails = id >= SNAIL_INTRO, -- "O"
		buds = id >= BUD_INTRO, -- "T"
		lambs = id >= LAMB_INTRO, -- "E" and pens "P"
		fireflies = id >= FIREFLY_INTRO, -- "N"
		trays = id >= TRAY_INTRO, -- "R"
		bins = id >= BIN_INTRO, -- "B"
		pumps = id >= PUMP_INTRO, -- flood water "W" and hand pumps "H"
		packets = id >= PACKET_INTRO, -- "K"
		mowers = id >= MOWER_INTRO, -- "U"
		gophers = id >= GOPHER_INTRO, -- "I"
		jars = id >= JAR_INTRO, -- "J"
		chests = id >= CHEST_INTRO, -- "X"
		vanes = id >= VANE_INTRO, -- "Z"
		vines = id >= VINE_INTRO, -- "Y"
		mist = id >= MIST_INTRO, -- "Q"
		muddy = id >= MUDDY_INTRO, -- "o"
	}
end

-- Rotates focus so neighbouring levels feel different.
local FOCUS = { "Collect", "Mud", "HayBale", "Mix", "Mud", "Collect", "HayBale", "Mix" }
local FOCUS_FROST = { "Collect", "Mud", "Frost", "HayBale", "Mix", "Mud", "Frost", "Collect", "HayBale", "Mix" }
local FOCUS_WEEDS = { "Collect", "Weeds", "Mud", "Frost", "HayBale", "Mix", "Mud", "Weeds", "Collect", "Frost", "HayBale", "Mix" }
local FOCUS_MUDDY = { "Muddy", "Mist", "Vines", "Collect", "Muddy", "Vanes", "Tools", "Jars", "Muddy", "Gophers", "Mowers", "Mix" }
local FOCUS_MIST = { "Mist", "Vines", "Vanes", "Collect", "Mist", "Tools", "Jars", "Gophers", "Mist", "Mowers", "Packets", "Mix" }
local FOCUS_VINES = { "Vines", "Vanes", "Tools", "Collect", "Vines", "Jars", "Gophers", "Mowers", "Vines", "Packets", "Floods", "Mix" }
local FOCUS_VANES = { "Vanes", "Tools", "Jars", "Collect", "Vanes", "Gophers", "Mowers", "Packets", "Vanes", "Floods", "Bins", "Mix" }
local FOCUS_CHESTS = { "Tools", "Jars", "Gophers", "Collect", "Tools", "Mowers", "Packets", "Floods", "Tools", "Bins", "Trays", "Mix" }
local FOCUS_JARS = { "Jars", "Gophers", "Mowers", "Collect", "Jars", "Packets", "Floods", "Bins", "Jars", "Trays", "Fireflies", "Mix" }
local FOCUS_GOPHERS = { "Gophers", "Mowers", "Packets", "Collect", "Gophers", "Floods", "Bins", "Trays", "Gophers", "Fireflies", "Lambs", "Mix" }
local FOCUS_MOWERS = { "Mowers", "Packets", "Floods", "Collect", "Mowers", "Bins", "Trays", "Fireflies", "Mowers", "Lambs", "Blooms", "Mix" }
local FOCUS_PACKETS = { "Packets", "Floods", "Bins", "Collect", "Packets", "Trays", "Fireflies", "Lambs", "Packets", "Blooms", "Snails", "Mix" }
local FOCUS_PUMPS = { "Floods", "Bins", "Trays", "Collect", "Floods", "Fireflies", "Lambs", "Blooms", "Floods", "Snails", "Trucks", "Mix" }
local FOCUS_BINS = { "Bins", "Trays", "Fireflies", "Collect", "Bins", "Lambs", "Blooms", "Snails", "Bins", "Trucks", "Honey", "Mix" }
local FOCUS_TRAYS = { "Trays", "Fireflies", "Lambs", "Collect", "Trays", "Blooms", "Snails", "Trucks", "Trays", "Honey", "Hedges", "Mix" }
local FOCUS_FIREFLIES = { "Fireflies", "Lambs", "Blooms", "Collect", "Fireflies", "Snails", "Trucks", "Honey", "Fireflies", "Hedges", "Boxes", "Mix" }
local FOCUS_LAMBS = { "Lambs", "Blooms", "Snails", "Collect", "Lambs", "Trucks", "Honey", "Hedges", "Lambs", "Boxes", "Buckets", "Mix" }
local FOCUS_BUDS = { "Blooms", "Snails", "Trucks", "Collect", "Blooms", "Honey", "Hedges", "Boxes", "Blooms", "Buckets", "Scarecrows", "Mix" }
local FOCUS_SNAILS = { "Snails", "Trucks", "Honey", "Collect", "Snails", "Hedges", "Boxes", "Buckets", "Snails", "Scarecrows", "Letters", "Mix" }
local FOCUS_TRUCKS = { "Trucks", "Honey", "Hedges", "Collect", "Trucks", "Boxes", "Buckets", "Scarecrows", "Trucks", "Letters", "Clay", "Mix" }
local FOCUS_HIVES = { "Honey", "Hedges", "Boxes", "Collect", "Honey", "Buckets", "Scarecrows", "Letters", "Honey", "Clay", "Snowballs", "Mix" }
local FOCUS_HEDGES = { "Hedges", "Boxes", "Buckets", "Collect", "Hedges", "Scarecrows", "Letters", "Clay", "Hedges", "Snowballs", "Fences", "Mix" }
local FOCUS_BOXES = { "Boxes", "Buckets", "Scarecrows", "Collect", "Boxes", "Letters", "Clay", "Snowballs", "Boxes", "Sacks", "Quilts", "Mix" }
local FOCUS_BUCKETS = { "Buckets", "Scarecrows", "Letters", "Collect", "Buckets", "Clay", "Snowballs", "Sacks", "Buckets", "Quilts", "Webs", "Mix" }
local FOCUS_CROWS = { "Scarecrows", "Letters", "Clay", "Collect", "Scarecrows", "Snowballs", "Sacks", "Quilts", "Scarecrows", "Webs", "Mud", "Mix" }
local FOCUS_MAIL = { "Letters", "Clay", "Snowballs", "Collect", "Letters", "Sacks", "Quilts", "Webs", "Letters", "Goo", "Mud", "Mix" }
local FOCUS_CLAY = { "Clay", "Snowballs", "Sacks", "Collect", "Clay", "Quilts", "Webs", "Goo", "Clay", "Rainbow", "Mud", "Mix" }
local FOCUS_SNOW = { "Snowballs", "Sacks", "Quilts", "Collect", "Snowballs", "Webs", "Goo", "Rainbow", "Snowballs", "Tarps", "Mud", "Mix" }
local FOCUS_SACKS = { "Sacks", "Quilts", "Webs", "Collect", "Sacks", "Rainbow", "Goo", "Tarps", "Sacks", "Statues", "Mud", "Mix" }
local FOCUS_QUILTS = { "Quilts", "Webs", "Rainbow", "Collect", "Quilts", "Goo", "Tarps", "Statues", "Quilts", "Springs", "Mud", "Mix" }
local FOCUS_WEBS = { "Webs", "Rainbow", "Goo", "Collect", "Webs", "Tarps", "Springs", "Statues", "Webs", "Crates", "Mud", "Mix" }
local FOCUS_RAINBOW = { "Rainbow", "Goo", "Tarps", "Collect", "Rainbow", "Springs", "Statues", "Crates", "Rainbow", "Fences", "Mud", "Mix" }
local FOCUS_THICK_GOO = { "Goo", "Tarps", "Springs", "Collect", "Goo", "Statues", "Crates", "Fences", "Goo", "Hens", "Mud", "Mix" }
local FOCUS_TARPS = { "Tarps", "Springs", "Statues", "Collect", "Tarps", "Crates", "Fences", "Goo", "Tarps", "Hens", "Mud", "Mix" }
local FOCUS_SPRINGS = { "Springs", "Statues", "Crates", "Collect", "Springs", "Hens", "Fences", "Baskets", "Springs", "Stones", "Mud", "Mix" }
local FOCUS_STATUES = { "Statues", "Crates", "Goo", "Collect", "Statues", "Hens", "Fences", "Baskets", "Statues", "Stones", "Mud", "Mix" }
local FOCUS_CRATES = { "Crates", "Hens", "Goo", "Collect", "Crates", "Fences", "Baskets", "Stones", "Crates", "Mud", "Clover", "Mix" }
local FOCUS_HENS = { "Hens", "Goo", "Collect", "Fences", "Hens", "Baskets", "Stones", "Mud", "Hens", "Clover", "Weeds", "Mix" }
local FOCUS_GOO = { "Goo", "Fences", "Collect", "Baskets", "Goo", "Stones", "Clover", "Mud", "Goo", "Weeds", "HayBale", "Mix" }
local FOCUS_FENCES = { "Fences", "Baskets", "Collect", "Stones", "Fences", "Clover", "Weeds", "Mud", "Fences", "Frost", "HayBale", "Mix" }
local FOCUS_BASKETS = { "Baskets", "Stones", "Collect", "Clover", "Baskets", "Weeds", "Mud", "Frost", "Baskets", "HayBale", "Mix", "Pumpkins" }
local FOCUS_STONES = { "Stones", "Clover", "Collect", "Pumpkins", "Stones", "Weeds", "Mud", "Frost", "Stones", "HayBale", "Mix", "Clover" }
local FOCUS_CLOVER = { "Clover", "Pumpkins", "Collect", "Weeds", "Clover", "Mud", "Frost", "HayBale", "Clover", "Mix", "Pumpkins", "Collect" }
local FOCUS_PUMPKINS = { "Pumpkins", "Collect", "Weeds", "Mud", "Pumpkins", "Frost", "HayBale", "Mix", "Pumpkins", "Weeds", "Collect", "Mix" }

-- Names that promise an obstacle get it (when it's in the game by then).
local NAME_HINTS = {
	{ words = { "Wash", "Rinse", "Rinsing", "Scrub", "Suds", "Soap", "Sponge", "Lather" }, focus = "Muddy", needs = "muddy" },
	{ words = { "Mud", "Puddle", "Ditch" }, focus = "Mud" },
	{ words = { "Bale", "Hay" }, focus = "HayBale" },
	{ words = { "Frost", "Foggy" }, focus = "Frost", needs = "frost" },
	{ words = { "Thistle", "Bramble", "Wild Oats" }, focus = "Weeds", needs = "weeds" },
	{ words = { "Pumpkin", "Gourd", "Squash" }, focus = "Pumpkins", needs = "pumpkins" },
	{ words = { "Clover", "Shamrock", "Green" }, focus = "Clover", needs = "clover" },
	{ words = { "Stone", "Quarry", "Rock" }, focus = "Stones", needs = "stones" },
	{ words = { "Basket", "Hamper", "Wicker" }, focus = "Baskets", needs = "baskets" },
	{ words = { "Fence", "Rail", "Pen", "Hurdle", "Gate" }, focus = "Fences", needs = "fences" },
	{ words = { "Mist", "Fog", "Haze", "Hazy", "Murky", "Steam", "Dew", "Cloud", "Vapour" }, focus = "Mist", needs = "mist" },
	{ words = { "Vine", "Ivy", "Creeper", "Clematis", "Tendril", "Trellis", "Wisteria", "Arbour", "Eleven Hundred" }, focus = "Vines", needs = "vines" },
	{ words = { "Vane", "Weathervane", "Weathercock", "Windy", "Compass", "Breez", "Cockerel", "Gust", "North Wind", "Spire", "Spinning", "Whirlwind" }, focus = "Vanes", needs = "vanes" },
	{ words = { "Tool", "Chest", "Spanner", "Wrench", "Hammer", "Workbench" }, focus = "Tools", needs = "chests" },
	{ words = { "Jam", "Jar", "Preserve", "Pickl", "Chutney", "Marmalade", "Pantry", "Larder", "Jelly" }, focus = "Jars", needs = "jars" },
	{ words = { "Gopher", "Burrow", "Molehill", "Warren", "Tunnel", "Hole", "Peekaboo", "Pop Up" }, focus = "Gophers", needs = "gophers" },
	{ words = { "Mower", "Mowing", "Grass", "Verge", "Stripe", "Croquet", "Cricket", "Clipping", "Trim", "Ride-On" }, focus = "Mowers", needs = "mowers" },
	{ words = { "Packet", "Sachet", "Pouch", "Catalogue", "Heirloom", "Variety", "Mixed", "Garden Centre" }, focus = "Packets", needs = "packets" },
	{ words = { "Flood", "Pump", "Water", "Soggy", "Drain", "Sluice", "Marsh", "Splash", "Downpour", "Deluge", "Overflow", "Wetland", "Brimming" }, focus = "Floods", needs = "pumps" },
	{ words = { "Compost", "Mulch", "Heap", "Worm", "Leaf Mould", "Peelings", "Scrap", "Humus", "Loam", "Black Gold", "Leaf Litter", "Peat Free", "Rotted" }, focus = "Bins", needs = "bins" },
	{ words = { "Tray", "Glasshouse", "Hothouse", "Cloche", "Propagator", "Punnet", "Windowsill", "Shoot", "Dibber", "Germinat", "Cutting", "Plug Plant", "Pricking Out", "Hardening Off", "Leafing" }, focus = "Trays", needs = "trays" },
	{ words = { "Firefly", "Glow", "Glimmer", "Lantern", "Twilight", "Dusk", "Night", "Moon", "Star", "Midsummer", "Evening" }, focus = "Fireflies", needs = "fireflies" },
	{ words = { "Lamb", "Sheep", "Ewe ", "Flock", "Fold", "Shepherd", "Bleat", "Fleece", "Shear", "Woolly", "Woolpack", "Ram'", "Crook", "Drover" }, focus = "Lambs", needs = "lambs" },
	{ words = { "Tulip", "Bulb", "Bloom", "Blossom", "Petal", "Posy", "Bouquet", "Florist", "Flower", "Rosebud", "Bud " }, focus = "Blooms", needs = "buds" },
	{ words = { "Snail", "Shell", "Slug", "Escargot", "Whorl", "Crawl", "Slow " }, focus = "Snails", needs = "snails" },
	{ words = { "Truck", "Wagon", "Lorry", "Haulage", "Pickup", "Convoy", "Flatbed", "Tow " }, focus = "Trucks", needs = "trucks" },
	{ words = { "Hive", "Honey", "Apiary", "Beekeep", "Nectar", "Mead", "Pollen", "Comb", "Swarm", "Buzz", "Bee ", "Drone", "Smoker" }, focus = "Honey", needs = "hives" },
	{ words = { "Hedge", "Privet", "Hawthorn", "Maze", "Topiary", "Laurel", "Yew", "Holly", "Shrub", "Hornbeam", "Thicket", "Briar", "Juniper", "Windbreak", "Labyrinth" }, focus = "Hedges", needs = "hedges" },
	{ words = { "Market", "Stall", "Produce", "Grocer", "Stack", "Pallet", "Packing", "Haul", "Loading" }, focus = "Boxes", needs = "boxes" },
	{ words = { "Bucket", "Pail", "Spill", "Spilt", "Slop", "Trough" }, focus = "Buckets", needs = "buckets" },
	{ words = { "Scarecrow", "Crow", "Straw", "Hat", "Rook", "Raven", "Magpie", "Jackdaw", "Blackbird", "Starling", "Corn Dolly", "Turnip Head" }, focus = "Scarecrows", needs = "scarecrows" },
	{ words = { "Mail", "Letter", "Post", "Stamp", "Envelope", "Courier", "Cards", "Notes", "Seal" }, focus = "Letters", needs = "mail" },
	{ words = { "Clay", "Kiln", "Pot", "Terracotta", "Pottery", "Jug", "Urn", "Glaze", "Crock", "Brick", "Earthenware", "Tile" }, focus = "Clay", needs = "clay" },
	{ words = { "Snow", "Ice", "Icicle", "Winter", "Blizzard", "Sleigh", "Sledge", "Chill", "Cold" }, focus = "Snowballs", needs = "snowballs" },
	{ words = { "Seed", "Sack", "Sow", "Turf", "Lawn", "Sprout", "Planting", "Allotment", "Topsoil", "Nursery" }, focus = "Sacks", needs = "sacks" },
	{ words = { "Quilt", "Patch", "Sewing", "Stitch", "Thimble", "Needle", "Bobbin", "Calico", "Gingham", "Button", "Mending", "Darning", "Seamstress", "Pincushion" }, focus = "Quilts", needs = "quilts" },
	{ words = { "Web", "Spider", "Silk", "Gossamer", "Tangle", "Netting", "Thread" }, focus = "Webs", needs = "webs" },
	{ words = { "Rainbow", "Dye", "Paint", "Colour", "Prism", "Hue", "Spectrum", "Chameleon", "Crayon" }, focus = "Rainbow", needs = "rainbow" },
	{ words = { "Tarp", "Canvas", "Awning", "Tent", "Marquee", "Shade", "Cover", "Big Top" }, focus = "Tarps", needs = "tarps" },
	{ words = { "Spring", "Well", "Fountain", "Geyser", "Seep", "Spout" }, focus = "Springs", needs = "springs" },
	{ words = { "Statue", "Relic", "Monument", "Bust", "Dig", "Plinth", "Fossil", "Unveiling" }, focus = "Statues", needs = "statues" },
	{ words = { "Crate", "Box", "Surprise", "Mystery", "Parcel", "Gift", "Prize" }, focus = "Crates", needs = "crates" },
	{ words = { "Hen", "Coop", "Egg", "Roost", "Chick", "Poultry", "Bantam" }, focus = "Hens", needs = "hens" },
	{ words = { "Goo", "Ooze", "Slim", "Sticky", "Sludge", "Bog", "Muck" }, focus = "Goo", needs = "goo" },
}

local function focusOf(id, name)
	local mech = mechanics(id)
	if id == FROST_INTRO then
		return "Frost"
	elseif id == WEEDS_INTRO then
		return "Weeds"
	elseif id == PUMPKIN_INTRO then
		return "Pumpkins"
	elseif id == CLOVER_INTRO then
		return "Clover"
	elseif id == STONE_INTRO then
		return "Stones"
	elseif id == PORTAL_INTRO then
		return "Collect" -- portals have no goal of their own
	elseif id == BASKET_INTRO then
		return "Baskets"
	elseif id == FENCE_INTRO then
		return "Fences"
	elseif id == GOO_INTRO then
		return "Goo"
	elseif id == HEN_INTRO then
		return "Hens"
	elseif id == CRATE_INTRO then
		return "Crates"
	elseif id == STATUE_INTRO then
		return "Statues"
	elseif id == SPRING_INTRO then
		return "Springs"
	elseif id == TARP_INTRO then
		return "Tarps"
	elseif id == THICK_GOO_INTRO then
		return "Goo"
	elseif id == RAINBOW_INTRO then
		return "Rainbow"
	elseif id == WEB_INTRO then
		return "Webs"
	elseif id == QUILT_INTRO then
		return "Quilts"
	elseif id == SACK_INTRO then
		return "Sacks"
	elseif id == SNOW_INTRO then
		return "Snowballs"
	elseif id == CLAY_INTRO then
		return "Clay"
	elseif id == MAIL_INTRO then
		return "Letters"
	elseif id == SCARECROW_INTRO then
		return "Scarecrows"
	elseif id == BUCKET_INTRO then
		return "Buckets"
	elseif id == BOX_INTRO then
		return "Boxes"
	elseif id == HEDGE_INTRO then
		return "Hedges"
	elseif id == HIVE_INTRO then
		return "Honey"
	elseif id == TRUCK_INTRO then
		return "Trucks"
	elseif id == SNAIL_INTRO then
		return "Snails"
	elseif id == BUD_INTRO then
		return "Blooms"
	elseif id == LAMB_INTRO then
		return "Lambs"
	elseif id == FIREFLY_INTRO then
		return "Fireflies"
	elseif id == TRAY_INTRO then
		return "Trays"
	elseif id == BIN_INTRO then
		return "Bins"
	elseif id == PUMP_INTRO then
		return "Floods"
	elseif id == PACKET_INTRO then
		return "Packets"
	elseif id == MOWER_INTRO then
		return "Mowers"
	elseif id == GOPHER_INTRO then
		return "Gophers"
	elseif id == JAR_INTRO then
		return "Jars"
	elseif id == CHEST_INTRO then
		return "Tools"
	elseif id == VANE_INTRO then
		return "Vanes"
	elseif id == VINE_INTRO then
		return "Vines"
	elseif id == MIST_INTRO then
		return "Mist"
	elseif id == MUDDY_INTRO then
		return "Muddy"
	end
	for _, hint in NAME_HINTS do
		for _, word in hint.words do
			if string.find(name, word, 1, true) and (hint.needs == nil or mech[hint.needs]) then
				return hint.focus
			end
		end
	end
	if id <= 7 then
		return ({ "Collect", "Mud", "Collect" })[id - 5] or "Mud"
	end
	local list = if mech.muddy then FOCUS_MUDDY elseif mech.mist then FOCUS_MIST elseif mech.vines then FOCUS_VINES elseif mech.vanes then FOCUS_VANES elseif mech.chests then FOCUS_CHESTS elseif mech.jars then FOCUS_JARS elseif mech.gophers then FOCUS_GOPHERS elseif mech.mowers then FOCUS_MOWERS elseif mech.packets then FOCUS_PACKETS elseif mech.pumps then FOCUS_PUMPS elseif mech.bins then FOCUS_BINS elseif mech.trays then FOCUS_TRAYS elseif mech.fireflies then FOCUS_FIREFLIES elseif mech.lambs then FOCUS_LAMBS elseif mech.buds then FOCUS_BUDS elseif mech.snails then FOCUS_SNAILS elseif mech.trucks then FOCUS_TRUCKS elseif mech.hives then FOCUS_HIVES elseif mech.hedges then FOCUS_HEDGES elseif mech.boxes then FOCUS_BOXES elseif mech.buckets then FOCUS_BUCKETS elseif mech.scarecrows then FOCUS_CROWS elseif mech.mail then FOCUS_MAIL elseif mech.clay then FOCUS_CLAY elseif mech.snowballs then FOCUS_SNOW elseif mech.sacks then FOCUS_SACKS elseif mech.quilts then FOCUS_QUILTS elseif mech.webs then FOCUS_WEBS elseif mech.rainbow then FOCUS_RAINBOW elseif mech.thickGoo then FOCUS_THICK_GOO elseif mech.tarps then FOCUS_TARPS elseif mech.springs then FOCUS_SPRINGS elseif mech.statues then FOCUS_STATUES elseif mech.crates then FOCUS_CRATES elseif mech.hens then FOCUS_HENS elseif mech.goo then FOCUS_GOO elseif mech.fences then FOCUS_FENCES elseif mech.baskets then FOCUS_BASKETS elseif mech.stones then FOCUS_STONES elseif mech.clover then FOCUS_CLOVER elseif mech.pumpkins then FOCUS_PUMPKINS elseif mech.weeds then FOCUS_WEEDS elseif mech.frost then FOCUS_FROST else FOCUS
	return list[(id % #list) + 1]
end

local function placeMud(g, rng, id, mech)
	local name = rng:pick(MUD_PATTERNS)
	local thick = mech.thickMud and rng:int(1, 100) <= math.min(60, (id - 10) * 2)
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) then
			setSym(g, p[1], p[2], if thick and (p[1] + p[2]) % 2 == 0 then "M" else "m")
		end
	end
end

local function placeBales(g, rng, id, mech)
	local name = rng:pick(BALE_PATTERNS)
	local top = if mech.bales3 then 3 elseif mech.bales2 then 2 else 1
	for _, p in BALES[name](g, rng) do
		if isCell(g, p[1], p[2]) and p[2] > 1 then
			local layers = rng:int(math.max(1, top - 1), top)
			setSym(g, p[1], p[2], tostring(layers))
		end
	end
end

-- No checker pattern: it freezes every other tile and leaves no swaps.
local FROST_PATTERNS = { "rows", "centre", "diagonal", "scatter", "columns" }

-- Frost goes on plain cells only (not mud or bales).
local function placeFrost(g, rng, id, mech)
	-- The first frost level keeps it small and in the middle.
	local name = if id == FROST_INTRO then "centre" else rng:pick(FROST_PATTERNS)
	local thick = mech.thickFrost and rng:int(1, 100) <= math.min(50, (id - 30) * 2)
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) and g[p[2]][p[1]] == "." then
			setSym(g, p[1], p[2], if thick and (p[1] + p[2]) % 2 == 1 then "F" else "f")
		end
	end
end

-- Surprise crates on plain cells, mirrored; the first crate level has four.
local function placeCrates(g, rng, id)
	local want = if id == CRATE_INTRO then 2 else rng:int(2, 4)
	for _ = 1, 30 do
		if want <= 0 then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(2, g.h - 1)
		if g[y][x] == "." and g[y][g.w - x + 1] == "." then
			setSym(g, x, y, "x")
			want -= 1
		end
	end
end

-- Buried statues: mirrored pairs of 2x2, 1x2 or 2x1 blocks on plain cells,
-- never touching another statue (touching ones would join up). The first
-- statue level has one pair of small ones.
local STATUE_SHAPES = { { 2, 2 }, { 1, 2 }, { 2, 1 }, { 2, 2 } }
local function placeStatues(g, rng, id)
	local pairsWanted = if id == STATUE_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= pairsWanted then
			break
		end
		local shape = if id == STATUE_INTRO then { 1, 2 } else rng:pick(STATUE_SHAPES)
		local sw, sh = shape[1], shape[2]
		local x, y = rng:int(1, g.w // 2 - sw), rng:int(2, g.h - sh)
		local ok = x + sw - 1 < g.w - (x + sw - 1) -- a gap between the pair
		for yy = y - 1, y + sh do
			for xx = x - 1, x + sw do
				local row = g[yy]
				local c = row and row[xx]
				local inside = xx >= x and xx < x + sw and yy >= y and yy < y + sh
				if c == "b" or (inside and c ~= ".") then
					ok = false
				end
			end
		end
		if ok then
			for yy = y, y + sh - 1 do
				for xx = x, x + sw - 1 do
					setSym(g, xx, yy, "b")
				end
			end
			placed += 1
		end
	end
	return placed
end

-- Tarps: centred runs of plain cells in a row (so they stay mirrored), with
-- tiles above them to fall in once they roll up, never stacked. The first
-- tarp level has one run of four.
local NOT_FALLING = "123wsSxtfF#dhGqkzlLyuvVjCOTEBHKUJXZ" -- cells nothing falls out of
local function placeTarps(g, rng, id)
	local want = if id == TARP_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 30 do
		if placed >= want then
			break
		end
		local len = if id == TARP_INTRO then 4 else rng:int(3, math.min(6, g.w - 2))
		if (g.w - len) % 2 == 1 then
			len += 1
		end
		local x0 = (g.w - len) // 2 + 1
		local y = rng:int(3, g.h - 1)
		local ok = true
		for x = x0, x0 + len - 1 do
			local above, below = g[y - 1][x], g[y + 1] and g[y + 1][x]
			if g[y][x] ~= "." or string.find(NOT_FALLING, above, 1, true) or below == "t" then
				ok = false
			end
		end
		if ok then
			for x = x0, x0 + len - 1 do
				g[y][x] = "t"
			end
			placed += 1
		end
	end
	return placed
end

-- Quilts: a centred block of plain cells (so it stays mirrored), with tiles
-- above it to fall in once it lifts off; later levels sometimes add a second
-- one lower down. Then one sewing tin per quilt cell (rounded up to mirrored
-- pairs, and now and then a spare pair). The first quilt level has one small
-- quilt. Returns the quilt cells placed (0 if there weren't tins enough).
local function placeQuilts(g, rng, id)
	local odd = g.w % 2 == 1
	local want = if id == QUILT_INTRO or rng:int(1, 3) < 3 then 1 else 2
	local cells, placed, lastY = 0, 0, 0
	for _ = 1, 30 do
		if placed >= want then
			break
		end
		local qw = if id == QUILT_INTRO then (if odd then 3 else 2) elseif odd then rng:pick({ 1, 3, 3 }) else rng:pick({ 2, 2, 4 })
		local qh = if id == QUILT_INTRO then (if odd then 1 else 2) else rng:int(1, 2)
		if qw * qh > 6 or (placed > 0 and qw * qh > 4) then
			qh = 1
		end
		local x0 = (g.w - qw) // 2 + 1
		local y0 = rng:int(math.max(3, lastY + 2), g.h - qh)
		local ok = y0 + qh - 1 <= g.h - 1 or placed > 0
		for y = y0 - 1, y0 + qh do
			for x = x0, x0 + qw - 1 do
				local c = g[y] and g[y][x]
				local inside = y >= y0 and y < y0 + qh
				if (inside and c ~= ".") or (y == y0 - 1 and (c == nil or string.find(NOT_FALLING, c, 1, true))) or (not inside and c == "q") then
					ok = false
				end
			end
		end
		if ok then
			for y = y0, y0 + qh - 1 do
				for x = x0, x0 + qw - 1 do
					g[y][x] = "q"
				end
			end
			cells += qw * qh
			placed += 1
			lastY = y0 + qh - 1
		end
	end
	if placed == 0 then
		return 0
	end
	local tins = cells + cells % 2 + (if id ~= QUILT_INTRO and rng:int(1, 2) == 1 then 2 else 0)
	for _ = 1, 60 do
		if tins <= 0 then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(2, g.h - 1)
		if g[y][x] == "." and g[y][g.w - x + 1] == "." and g[y - 1][x] ~= "q" then
			setSym(g, x, y, "k")
			tins -= 2
		end
	end
	if tins > 0 then
		return 0
	end
	return cells
end

-- Webs on a few plain cells, mirrored (only blasts clear them, so not many):
-- two pairs on the first web level, two to four pairs later.
local function placeWebs(g, rng, id)
	local want = if id == WEB_INTRO then 2 else rng:int(2, 4)
	for _ = 1, 40 do
		if want <= 0 then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(2, g.h - 1)
		if g[y][x] == "." and g[y][g.w - x + 1] == "." then
			setSym(g, x, y, "n")
			want -= 1
		end
	end
end

-- Rainbow patches on plain cells, mirrored; the first rainbow level keeps
-- them in the middle.
local function placeRainbow(g, rng, id)
	local name = if id == RAINBOW_INTRO then "centre" else rng:pick(FROST_PATTERNS)
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) and g[p[2]][p[1]] == "." then
			setSym(g, p[1], p[2], "r")
		end
	end
end

-- Goo on plain cells; the first goo level starts with a small patch in the middle.
local function placeGoo(g, rng, id, mech)
	local name = if id == GOO_INTRO or id == THICK_GOO_INTRO or id == SNAIL_INTRO then "centre" else rng:pick(FROST_PATTERNS)
	-- From the thick goo level on, some goo is thick (all of it on the intro;
	-- none on the first snail level).
	local thick = if id == THICK_GOO_INTRO then 100 elseif id == SNAIL_INTRO then 0 elseif mech.thickGoo then rng:int(25, 60) else 0
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) and g[p[2]][p[1]] == "." then
			setSym(g, p[1], p[2], if thick > 0 and rng:int(1, 100) <= thick then "e" else "g")
		end
	end
end

-- A few weeds to start with, low on the board; they spread from there.
local function placeWeeds(g, rng)
	local placed = 0
	for _ = 1, 20 do
		if placed >= rng:int(1, 2) then
			break
		end
		local x, y = rng:int(1, math.ceil(g.w / 2) - 1), rng:int(math.ceil(g.h / 2), g.h)
		if isCell(g, x, y) and g[y][x] == "." then
			setSym(g, x, y, "w")
			placed += 1
		end
	end
end

-- Pumpkins start near the top, never in a column's bottom cell. Returns how
-- many the goal asks for (more drop in as these are collected).
local function placePumpkins(g, rng, id)
	local want = if id == PUMPKIN_INTRO then 2 else rng:int(1, 3)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w), rng:int(1, 2)
		local below = false
		for yy = y + 1, g.h do
			below = below or isCell(g, x, yy)
		end
		if isCell(g, x, y) and g[y][x] == "." and below then
			g[y][x] = "p"
			placed += 1
		end
	end
	if placed == 0 then
		return 0
	end
	return placed + (if id == PUMPKIN_INTRO then 0 else rng:int(0, 1))
end

-- Muddy pumpkins anywhere on plain cells (the bottom row too: washing one
-- there collects it); the first level has two in the middle rows. Returns how
-- many the goal asks for (clean pumpkins drop in for any extra).
local function placeMuddy(g, rng, id)
	local intro = id == MUDDY_INTRO
	local want = if intro then 2 else rng:int(2, 4)
	local placed = 0
	for _ = 1, 60 do
		if placed >= want then
			break
		end
		local x = rng:int(1, g.w)
		local y = if intro then rng:int(3, math.max(3, g.h - 2)) else rng:int(1, g.h)
		if isCell(g, x, y) and g[y][x] == "." then
			g[y][x] = "o"
			placed += 1
		end
	end
	if placed == 0 then
		return 0
	end
	return placed + (if intro then 0 else rng:int(0, 1))
end

-- Stone walls use the bale shapes; the first stone level keeps them few and thin.
local function placeStones(g, rng, id, mech)
	local name = if id == STONE_INTRO then "centre" else rng:pick(BALE_PATTERNS)
	for _, p in BALES[name](g, rng) do
		if isCell(g, p[1], p[2]) and p[2] > 1 and g[p[2]][p[1]] == "." then
			local thick = mech.thickStones and rng:int(1, 3) == 1
			setSym(g, p[1], p[2], if thick then "S" else "s")
		end
	end
end

-- A small clover patch to grow from, low and in the middle (mirrored).
local function placeClover(g, rng, id)
	local size = if id == CLOVER_INTRO then 2 else rng:int(1, 3)
	local cx = math.ceil(g.w / 2)
	local y = rng:int(math.ceil(g.h / 2), g.h)
	for i = 0, size - 1 do
		local x = cx - i
		if isCell(g, x, y) and g[y][x] == "." then
			setSym(g, x, y, "c")
		end
	end
end

-- Produce box stacks: mirrored pairs on plain cells away from the edges, not
-- touching each other. The first box level has one pair of 3-box stacks.
local function placeBoxes(g, rng, id)
	local want = if id == BOX_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and (row[x + dx] == "v" or row[x + dx] == "V") then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, if id == BOX_INTRO or rng:int(1, 2) == 1 then "v" else "V")
			placed += 1
		end
	end
	return placed
end

-- Mud buckets: mirrored pairs on plain cells away from the edges, with room
-- between them for their spills. The first bucket level has one pair.
local function placeBuckets(g, rng, id)
	local want = if id == BUCKET_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 3 and g[y][x] == "." and g[y][mx] == "." -- the pair's spills don't overlap
		for dy = -2, 2 do
			for dx = -2, 2 do
				local row = g[y + dy]
				if row and row[x + dx] == "u" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "u")
			placed += 1
		end
	end
	return placed
end

-- Hay trucks: one mirrored pair on plain cells away from the edges (two pairs
-- now and then after the first truck level), with room around them.
local function placeTrucks(g, rng, id)
	local want = if id == TRUCK_INTRO or rng:int(1, 3) < 3 then 1 else 2
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "C" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "C")
			placed += 1
		end
	end
	return placed
end

-- Garden snails: one mirrored pair on plain cells away from the edges, not
-- touching each other (now and then two pairs after the first snail level).
local function placeSnails(g, rng, id)
	local want = if id == SNAIL_INTRO or rng:int(1, 3) < 3 then 1 else 2
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 3 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "O" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "O")
			placed += 1
		end
	end
	return placed
end

-- Seed trays: mirrored blocks of plain cells, 2x2 or three in a line, kept
-- apart from other trays (touching R cells would make one tray). One pair of
-- 2x2 trays on the first tray level, one or two pairs after (now and then
-- three later on). Returns how many pairs were placed.
local TRAY_SHAPES = {
	{ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
	{ { 0, 0 }, { 1, 0 }, { 2, 0 } },
	{ { 0, 0 }, { 0, 1 }, { 0, 2 } },
}
local function placeTrays(g, rng, id)
	local want = if id == TRAY_INTRO then 1 else rng:int(1, 2) + (if id >= TRAY_INTRO + 12 and rng:int(1, 3) == 1 then 1 else 0)
	local placed = 0
	for _ = 1, 100 do
		if placed >= want then
			break
		end
		local shape = if id == TRAY_INTRO then TRAY_SHAPES[1] else rng:pick(TRAY_SHAPES)
		local x, y = rng:int(1, g.w // 2), rng:int(1, g.h)
		local ok = true
		for _, d in shape do
			local cx, cy = x + d[1], y + d[2]
			local row = g[cy]
			if cx > g.w // 2 or not row or row[cx] ~= "." or row[g.w - cx + 1] ~= "." then
				ok = false
			end
			for _, n in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local nrow = g[cy + n[2]]
				if nrow and nrow[cx + n[1]] == "R" then
					ok = false
				end
			end
		end
		if ok then
			for _, d in shape do
				setSym(g, x + d[1], y + d[2], "R")
			end
			placed += 1
		end
	end
	return placed
end

-- Firefly spots: mirrored plain cells spread over the board, three to five
-- pairs (three on the first firefly level). Returns how many were placed.
local function placeSpots(g, rng, id)
	local want = if id == FIREFLY_INTRO then 3 else rng:int(3, 5)
	local placed = 0
	for _ = 1, 80 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(1, g.h)
		local mx = g.w - x + 1
		local ok = mx ~= x and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "N" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "N")
			placed += 1
		end
	end
	return placed
end

-- Lost lambs: a mirrored pair in the top half, each with its pen a few rows
-- below (straight down, or a step or two across), and no holes in the column
-- between. Now and then two pairs after the first lamb level.
local function placeLambs(g, rng, id)
	local want = if id == LAMB_INTRO or rng:int(1, 3) < 3 then 1 else 2
	local placed = 0
	for _ = 1, 60 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(1, math.max(1, g.h // 2 - 1))
		local drop = if id == LAMB_INTRO then 4 else rng:int(3, 6)
		local px, py = x + (if id == LAMB_INTRO then 0 else rng:int(-1, 2)), y + drop
		local mx, mpx = g.w - x + 1, g.w - px + 1
		local ok = mx - x >= 2 and mpx - px >= 2 and px >= 1 and py <= g.h
			and g[y][x] == "." and g[y][mx] == "." and g[py] ~= nil and g[py][px] == "." and g[py][mpx] == "."
		if ok then
			for yy = y, py do
				ok = ok and isCell(g, x, yy) and isCell(g, px, yy)
			end
			for dy = -1, 1 do
				for dx = -1, 1 do
					local row = g[y + dy]
					if row and (row[x + dx] == "E" or row[x + dx] == "P") then
						ok = false
					end
				end
			end
		end
		if ok then
			setSym(g, x, y, "E")
			setSym(g, px, py, "P")
			placed += 1
		end
	end
	return placed
end

-- Tulip buds: one or two mirrored pairs on plain cells away from the edges,
-- not touching each other. The first bud level has one pair.
local function placeBuds(g, rng, id)
	local want = if id == BUD_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "T" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "T")
			placed += 1
		end
	end
	return placed
end

-- Gopher burrows: mirrored pairs of plain cells spread over the board, not
-- touching each other: two pairs on the first gopher level, two or three
-- after. Returns how many burrows were placed.
local function placeBurrows(g, rng, id)
	local want = if id == GOPHER_INTRO then 2 else rng:int(2, 3)
	local placed = 0
	for _ = 1, 80 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(1, g.h)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "I" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "I")
			placed += 1
		end
	end
	return placed * 2
end

-- Lawn mowers: a mirrored pair at the two ends of a row near the bottom,
-- with hay bales across the row between them for the mowers to cut (the
-- bottom rows, so the bales don't cut off refills for much of the board).
-- One row of 1-layer bales on the first mower level; later now and then a
-- second row, and some 2-layer bales. Returns how many mowers were placed.
local function placeMowers(g, rng, id)
	local rows = if id >= MOWER_INTRO + 10 and rng:int(1, 3) == 1 then 2 else 1
	local placed = 0
	for _, y in { g.h, g.h - 1 } do
		if placed >= rows * 2 then
			break
		end
		local x = nil
		for cx = 1, g.w // 2 do
			if not x and g[y][cx] == "." and g[y][g.w - cx + 1] == "." then
				x = cx
			end
		end
		if x and g.w - x + 1 - x >= 3 then
			setSym(g, x, y, "U")
			for cx = x + 1, g.w - x do
				if g[y][cx] == "." then
					g[y][cx] = if id ~= MOWER_INTRO and rng:int(1, 4) == 1 then "2" else "1"
				end
			end
			placed += 2
		end
	end
	return placed
end

-- Seed packets: one or two mirrored pairs on plain cells away from the
-- edges, not touching each other (each packet of a pair gets its own colour).
-- The first packet level has one pair.
local function placePackets(g, rng, id)
	local want = if id == PACKET_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "K" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "K")
			placed += 1
		end
	end
	return placed
end

-- Mist on plain cells in one of the frost patterns; the first mist level
-- scatters it, so each patch needs its own match.
local function placeMist(g, rng, id)
	local name = if id == MIST_INTRO then "scatter" else rng:pick(FROST_PATTERNS)
	local placed = 0
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) and g[p[2]][p[1]] == "." then
			setSym(g, p[1], p[2], "Q")
			placed += 1
		end
	end
	return placed
end

-- Vines: a few mirrored pairs on plain cells; they creep from there. The
-- first vine level has two pairs.
local function placeVines(g, rng, id)
	local want = if id == VINE_INTRO then 2 else rng:int(2, 3)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(2, g.h - 1)
		if g[y][x] == "." and g[y][g.w - x + 1] == "." then
			setSym(g, x, y, "Y")
			placed += 1
		end
	end
	return placed
end

-- Weathervanes: one or two mirrored pairs on plain cells away from the
-- edges, not touching each other, a chest, a jar or a seed packet. The
-- first vane level has one pair.
local function placeVanes(g, rng, id)
	local want = if id == VANE_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				local c = row and row[x + dx]
				if c == "Z" or c == "X" or c == "J" or c == "K" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "Z")
			placed += 1
		end
	end
	return placed
end

-- Tool chests: one or two mirrored pairs on plain cells away from the
-- edges, not touching each other, a jar or a seed packet. The first chest
-- level has one pair.
local function placeChests(g, rng, id)
	local want = if id == CHEST_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				local c = row and row[x + dx]
				if c == "X" or c == "J" or c == "K" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "X")
			placed += 1
		end
	end
	return placed
end

-- Jam jars: one or two mirrored pairs on plain cells away from the edges,
-- not touching each other or a seed packet (each jar of a pair gets its own
-- colour). The first jar level has one pair.
local function placeJars(g, rng, id)
	local want = if id == JAR_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and (row[x + dx] == "J" or row[x + dx] == "K") then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "J")
			placed += 1
		end
	end
	return placed
end

-- Flood water and hand pumps: a mirrored pair of water patches (3x3 on the
-- first pump level, up to 3x3 after, now and then a second pair later on),
-- then a mirrored pair of pumps on plain cells 2 to 4 steps from the water
-- (so it takes a few matches to reach them).
-- Returns how many pumps were placed (0 if it didn't fit).
local function placeFloods(g, rng, id)
	local patches = if id >= PUMP_INTRO + 12 and rng:int(1, 3) == 1 then 2 else 1
	local water = 0
	for _ = 1, 60 do
		if patches == 0 then
			break
		end
		local pw = if id == PUMP_INTRO then 3 else rng:int(2, 3)
		local ph = if id == PUMP_INTRO then 3 else rng:int(2, 3)
		local x, y = rng:int(1, math.max(1, g.w // 2 - pw + 1)), rng:int(1, math.max(1, g.h - ph + 1))
		local ok = x + pw - 1 <= g.w // 2
		for dy = 0, ph - 1 do
			for dx = 0, pw - 1 do
				local row = g[y + dy]
				if not row or row[x + dx] ~= "." or row[g.w - (x + dx) + 1] ~= "." then
					ok = false
				end
			end
		end
		if ok then
			for dy = 0, ph - 1 do
				for dx = 0, pw - 1 do
					setSym(g, x + dx, y + dy, "W")
				end
			end
			water += pw * ph * 2
			patches -= 1
		end
	end
	if water == 0 then
		return 0
	end
	local spots = {}
	for y = 1, g.h do
		for x = 1, g.w // 2 do
			local mx = g.w - x + 1
			if mx ~= x and g[y][x] == "." and g[y][mx] == "." then
				local nearest = math.huge
				for dy = -4, 4 do
					for dx = -4, 4 do
						local row = g[y + dy]
						if row and row[x + dx] == "W" then
							nearest = math.min(nearest, math.abs(dx) + math.abs(dy))
						end
					end
				end
				if nearest >= 2 and nearest <= 4 then
					table.insert(spots, { x, y })
				end
			end
		end
	end
	if #spots == 0 then
		return 0
	end
	local spot = rng:pick(spots)
	setSym(g, spot[1], spot[2], "H")
	return 2
end

-- Compost bins: one or two mirrored pairs on plain cells away from the
-- edges, not touching each other. The first bin level has one pair.
local function placeBins(g, rng, id)
	local want = if id == BIN_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "B" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "B")
			placed += 1
		end
	end
	return placed
end

-- Beehives: one or two mirrored pairs on plain cells away from the edges,
-- not touching each other. The first hive level has one pair.
local function placeHives(g, rng, id)
	local want = if id == HIVE_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx - x >= 2 and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "j" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "j")
			placed += 1
		end
	end
	return placed
end

-- Scarecrows: one mirrored pair on plain cells away from the edges (two
-- pairs now and then after the first scarecrow level).
local function placeScarecrows(g, rng, id)
	local want = if id == SCARECROW_INTRO or rng:int(1, 3) < 3 then 1 else 2
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(2, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx ~= x and g[y][x] == "." and g[y][mx] == "."
		for dy = -1, 1 do
			for dx = -1, 1 do
				local row = g[y + dy]
				if row and row[x + dx] == "y" then
					ok = false
				end
			end
		end
		if ok then
			setSym(g, x, y, "y")
			placed += 1
		end
	end
	return placed
end

-- Mailboxes: mirrored pairs on plain cells, not touching each other; each
-- holds a letter or not (at least one does). The first mailbox level has two
-- pairs and three letters.
local function placeMailboxes(g, rng, id)
	local want = if id == MAIL_INTRO then 2 else rng:int(2, 3)
	local spots = {}
	for _ = 1, 40 do
		if #spots >= want * 2 then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(2, g.h - 1)
		local mx = g.w - x + 1
		local ok = mx ~= x and g[y][x] == "." and g[y][mx] == "."
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local row = g[y + d[2]]
			if row and (row[x + d[1]] == "l" or row[x + d[1]] == "L") then
				ok = false
			end
		end
		if ok then
			g[y][x], g[y][mx] = "L", "L"
			table.insert(spots, { x, y })
			table.insert(spots, { mx, y })
		end
	end
	if #spots == 0 then
		return 0
	end
	local letters = if id == MAIL_INTRO then math.min(3, #spots) else rng:int(math.max(1, #spots // 2), #spots)
	rng:shuffle(spots)
	for i = 1, letters do
		g[spots[i][2]][spots[i][1]] = "l"
	end
	return letters
end

-- Clay under plain cells in one of the frost patterns; the first clay level
-- has a small glazed patch in the middle, later ones glaze about half.
local function placeClay(g, rng, id)
	local name = if id == CLAY_INTRO then "centre" else rng:pick(FROST_PATTERNS)
	local glazed = if id == CLAY_INTRO then 100 else rng:int(30, 70)
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) and g[p[2]][p[1]] == "." then
			setSym(g, p[1], p[2], if rng:int(1, 100) <= glazed then "a" else "A")
		end
	end
end

-- Snowballs: mirrored pairs of plain cells, two pairs on the first snowball
-- level and two to four later.
local function placeSnowballs(g, rng, id)
	local want = if id == SNOW_INTRO then 2 else rng:int(2, 4)
	for _ = 1, 40 do
		if want <= 0 then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(1, g.h)
		if g[y][x] == "." and g[y][g.w - x + 1] == "." then
			setSym(g, x, y, "i")
			want -= 1
		end
	end
	return want <= 0
end

-- Seed sacks: one or two mirrored pairs on plain cells, not touching each
-- other (one pair on the first sack level).
local function placeSacks(g, rng, id)
	local want = if id == SACK_INTRO then 1 else rng:int(1, 2)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w // 2), rng:int(2, g.h - 1)
		local ok = g[y][x] == "." and g[y][g.w - x + 1] == "."
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local row = g[y + d[2]]
			if row and row[x + d[1]] == "z" then
				ok = false
			end
		end
		if ok then
			setSym(g, x, y, "z")
			placed += 1
		end
	end
	return placed
end

-- Portals cross the board: a row of holes cuts some columns, and each cut
-- column pours into its mirror below (x -> w-x+1), so the two sides swap.
-- Returns the level's portal list (empty if no columns fit).
local function placePortals(g, rng, id)
	local r = rng:int(3, g.h - 2)
	local columns = {}
	for x = 1, g.w // 2 do
		local mx = g.w - x + 1
		local fits = true
		for dy = -1, 1 do
			fits = fits and isCell(g, x, r + dy) and isCell(g, mx, r + dy)
			-- Don't cut a seed tray in pieces.
			fits = fits and g[r + dy][x] ~= "R" and g[r + dy][mx] ~= "R"
		end
		if fits then
			table.insert(columns, x)
		end
	end
	rng:shuffle(columns)
	local wanted = if id == PORTAL_INTRO then 1 else rng:int(1, 2)
	local portals = {}
	for i = 1, math.min(wanted, #columns) do
		local x = columns[i]
		local mx = g.w - x + 1
		setSym(g, x, r, "#")
		setSym(g, x, r - 1, ".")
		setSym(g, x, r + 1, ".")
		table.insert(portals, { from = { x, r - 1 }, to = { mx, r + 1 } })
		table.insert(portals, { from = { mx, r - 1 }, to = { x, r + 1 } })
	end
	return portals
end

-- Pumpkin baskets near the top (one, or a mirrored pair), each over a plain
-- cell. Returns how many pumpkins the goal asks for (0 if none fit).
local function placeBaskets(g, rng, id, portals)
	local portalEnd = {}
	for _, portal in portals do
		portalEnd[portal.from[2] * 100 + portal.from[1]] = true
		portalEnd[portal.to[2] * 100 + portal.to[1]] = true
	end
	local function free(x, y)
		return isCell(g, x, y) and g[y][x] == "." and not portalEnd[y * 100 + x]
	end
	local spots = {}
	for y = 1, 3 do
		for x = 1, (g.w + 1) // 2 do
			local mx = g.w - x + 1
			if free(x, y) and free(mx, y) and free(x, y + 1) and free(mx, y + 1) then
				table.insert(spots, { x, y })
			end
		end
	end
	if #spots == 0 then
		return 0
	end
	local spot = rng:pick(spots)
	local pair = id ~= BASKET_INTRO and spot[1] * 2 <= g.w and rng:int(1, 2) == 1
	if pair then
		setSym(g, spot[1], spot[2], "d")
	else
		g[spot[2]][spot[1]] = "d"
	end
	return if id == BASKET_INTRO then 3 else rng:int(3, 4 + id // 60) + (if pair then 1 else 0)
end

-- Fences on edges between cells, mirrored left to right: a wall down the
-- middle, a pen around the centre, or rails under a row.
local FENCE_PATTERNS = { "wall", "pen", "rails" }

-- Hedges (hedge = true) come out with "R" and "D" sides, never on an edge in
-- `taken` (the fences already placed).
local function placeFences(g, rng, id, hedge, taken)
	local fences, seen = {}, {}
	for _, f in taken or {} do
		seen[f[1] .. "," .. f[2] .. string.lower(f[3])] = true
	end
	local intro = if hedge then id == HEDGE_INTRO else id == FENCE_INTRO
	local function plain(x, y)
		return isCell(g, x, y) and g[y][x] ~= "d" and g[y][x] ~= "h" and g[y][x] ~= "G"
	end
	local function add(x, y, side)
		local ox, oy = if side == "r" then x + 1 else x, if side == "d" then y + 1 else y
		local key = x .. "," .. y .. side
		if plain(x, y) and plain(ox, oy) and not seen[key] then
			seen[key] = true
			table.insert(fences, { x, y, if hedge then string.upper(side) else side })
		end
	end
	local function addSym(x, y, side)
		add(x, y, side)
		if side == "r" then
			add(g.w - x, y, "r")
		else
			add(g.w - x + 1, y, "d")
		end
	end
	local name = if intro then "wall" else rng:pick(FENCE_PATTERNS)
	local cx, cy = g.w // 2, g.h // 2
	if name == "wall" then
		local x = if intro or rng:int(1, 2) == 1 then cx else rng:int(2, cx)
		local top = rng:int(2, math.max(2, cy - 1))
		for y = top, math.min(g.h - 1, top + (if intro then 3 else rng:int(3, 5))) do
			addSym(x, y, "r")
		end
	elseif name == "pen" then
		local x0, y0 = cx, cy
		for x = x0, g.w - x0 + 1 do
			addSym(x, y0 - 1, "d")
			addSym(x, y0 + 1, "d")
		end
		for y = y0, y0 + 1 do
			addSym(x0 - 1, y, "r")
		end
	else
		local y = rng:int(3, g.h - 2)
		for x = 1, cx do
			if (x + y) % 2 == 0 or rng:int(1, 3) == 1 then
				addSym(x, y, "d")
			end
		end
	end
	return fences
end

-- Hen houses in the upper half (one, or a mirrored pair), each over a plain cell.
local function placeHens(g, rng, id, portals)
	local portalEnd = {}
	for _, portal in portals do
		portalEnd[portal.from[2] * 100 + portal.from[1]] = true
		portalEnd[portal.to[2] * 100 + portal.to[1]] = true
	end
	local function free(x, y)
		return isCell(g, x, y) and g[y][x] == "." and not portalEnd[y * 100 + x]
	end
	local spots = {}
	for y = 2, g.h // 2 do
		for x = 1, (g.w + 1) // 2 do
			local mx = g.w - x + 1
			if free(x, y) and free(mx, y) and free(x, y + 1) and free(mx, y + 1) then
				table.insert(spots, { x, y })
			end
		end
	end
	if #spots == 0 then
		return 0
	end
	local spot = rng:pick(spots)
	if id ~= HEN_INTRO and spot[1] * 2 <= g.w and rng:int(1, 2) == 1 then
		setSym(g, spot[1], spot[2], "h")
		return 2
	end
	g[spot[2]][spot[1]] = "h"
	return 1
end

-- Goo springs, each with a goo tile below or beside it to start; the first
-- spring level has one, later ones one or a mirrored pair.
local function placeSprings(g, rng, id, portals)
	local portalEnd = {}
	for _, portal in portals do
		portalEnd[portal.from[2] * 100 + portal.from[1]] = true
		portalEnd[portal.to[2] * 100 + portal.to[1]] = true
	end
	local function free(x, y)
		return isCell(g, x, y) and g[y][x] == "." and not portalEnd[y * 100 + x]
	end
	local spots = {}
	for y = 2, g.h - 1 do
		for x = 2, (g.w + 1) // 2 do
			local mx = g.w - x + 1
			if free(x, y) and free(mx, y) and free(x, y + 1) and free(mx, y + 1) then
				table.insert(spots, { x, y })
			end
		end
	end
	if #spots == 0 then
		return 0
	end
	local spot = rng:pick(spots)
	local x, y = spot[1], spot[2]
	if id ~= SPRING_INTRO and x * 2 <= g.w and rng:int(1, 2) == 1 then
		setSym(g, x, y, "G")
		setSym(g, x, y + 1, "g")
		return 2
	end
	g[y][x] = "G"
	g[y + 1][x] = "g"
	return 1
end

-- Keep a gap in every row so nothing is sealed off: bales, weeds and frozen
-- tiles all stop falling tiles.
local function keepRowsOpen(g)
	for y = 1, g.h do
		local open = false
		for x = 1, g.w do
			local c = g[y][x]
			open = open or c == "." or c == "m" or c == "M" or c == "g" or c == "e" or c == "b" or c == "r" or c == "i" or c == "a" or c == "A"
		end
		if not open then
			setSym(g, math.ceil(g.w / 2), y, ".")
		end
	end
end

local function layoutText(g)
	local rows = {}
	for y = 1, g.h do
		rows[y] = table.concat(g[y])
	end
	return rows
end

local function has(g, chars)
	return countCells(g, function(c)
		return string.find(chars, c, 1, true) ~= nil
	end)
end

local function draft(id, variant)
	local rng = Rng.new(id * 7919 + variant * 104729)
	local mech = mechanics(id)
	local difficulty = difficultyOf(id)
	local name = NAMES[id - 5] or ("Level " .. id)
	local focus = focusOf(id, name)
	-- Hen levels after the intro add one other obstacle: eggs alone are too easy.
	-- Seed sack levels are clover levels with sacks to sow it.
	-- Hay truck levels are hay bale levels with trucks dropping more.
	-- Snail levels are goo levels with snails leaving more.
	local snailFocus = focus == "Snails"
	if snailFocus then
		focus = "Goo"
	end
	local truckFocus = focus == "Trucks"
	if truckFocus then
		focus = "HayBale"
	end
	-- Mud bucket levels are mud levels with buckets to spill it.
	local bucketFocus = focus == "Buckets"
	if bucketFocus then
		focus = "Mud"
	end
	local sackFocus = focus == "Sacks"
	if sackFocus then
		focus = "Clover"
	end
	local henFocus = focus == "Hens"
	if henFocus and id ~= HEN_INTRO then
		focus = ({ "Mud", "HayBale", "Frost", "Weeds" })[id % 4 + 1]
	end
	local w = rng:int(7, if id < 15 then 8 else 9)
	local h = rng:int(7, if id < 15 then 8 else 9)
	local g
	repeat
		g = newGrid(w, h, ".")
		rng:pick(SHAPES)(g, rng)
	until connected(g) and countCells(g, function(c)
		return c ~= "#"
	end) >= 42

	local wantMud = focus == "Mud" or (focus == "Mix" and rng:int(1, 2) == 1)
	local wantBales = id >= 7 and (focus == "HayBale" or (focus == "Mix" and not wantMud) or (focus == "Mix" and id >= 40))
	if focus == "Clover" then
		-- Clover can't grow under bales from matches, so clover levels go without them.
		wantBales = false
		wantMud = id ~= CLOVER_INTRO and rng:int(1, 3) == 1
	end
	if truckFocus and id == TRUCK_INTRO then
		wantBales = false -- the first truck level's bales all come off its trucks
	end
	if bucketFocus and id == BUCKET_INTRO then
		wantMud = false -- the first bucket level's mud all comes from its buckets
	end
	if wantMud then
		placeMud(g, rng, id, mech)
	end
	if bucketFocus or (mech.buckets and (focus == "Mud" or focus == "Mix") and rng:int(1, 3) == 1) then
		if placeBuckets(g, rng, id) == 0 then
			return nil
		end
	end
	if wantBales then
		placeBales(g, rng, id, mech)
	end
	if focus == "Frost" or (focus == "Mix" and mech.frost and rng:int(1, 3) == 1) then
		placeFrost(g, rng, id, mech)
	end
	if focus == "Weeds" or (focus == "Mix" and mech.weeds and rng:int(1, 3) == 1) then
		placeWeeds(g, rng)
	end
	if focus == "Clover" then
		if id ~= SACK_INTRO then
			placeClover(g, rng, id) -- the first sack level grows clover from its sacks alone
		end
		if sackFocus or (mech.sacks and rng:int(1, 3) <= 2) then
			if placeSacks(g, rng, id) == 0 then
				return nil
			end
		end
	end
	if focus == "Stones" or (focus == "Mix" and mech.stones and rng:int(1, 3) == 1) then
		placeStones(g, rng, id, mech)
	end
	if focus == "Goo" or (focus == "Mix" and mech.goo and rng:int(1, 3) == 1) then
		placeGoo(g, rng, id, mech)
		if snailFocus or (mech.snails and focus == "Goo" and rng:int(1, 2) == 1) then
			if placeSnails(g, rng, id) == 0 then
				return nil
			end
		end
	end
	if focus == "Crates" or (focus == "Mix" and mech.crates and rng:int(1, 3) == 1) then
		placeCrates(g, rng, id)
	end
	if truckFocus or (mech.trucks and (focus == "HayBale" or focus == "Mix") and rng:int(1, 3) == 1) then
		if placeTrucks(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Honey" or (focus == "Mix" and mech.hives and rng:int(1, 3) == 1) then
		if placeHives(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Blooms" or (focus == "Mix" and mech.buds and rng:int(1, 3) == 1) then
		if placeBuds(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Lambs" or (focus == "Mix" and mech.lambs and rng:int(1, 3) == 1) then
		if placeLambs(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Mist" or (focus == "Mix" and mech.mist and rng:int(1, 3) == 1) then
		if placeMist(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Vines" or (focus == "Mix" and mech.vines and rng:int(1, 3) == 1) then
		if placeVines(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Vanes" or (focus == "Mix" and mech.vanes and rng:int(1, 3) == 1) then
		if placeVanes(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Tools" or (focus == "Mix" and mech.chests and rng:int(1, 3) == 1) then
		if placeChests(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Jars" or (focus == "Mix" and mech.jars and rng:int(1, 3) == 1) then
		if placeJars(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Gophers" or (focus == "Mix" and mech.gophers and rng:int(1, 3) == 1) then
		if placeBurrows(g, rng, id) < 4 then
			return nil
		end
	end
	if focus == "Mowers" or (focus == "Mix" and mech.mowers and rng:int(1, 3) == 1) then
		if placeMowers(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Packets" or (focus == "Mix" and mech.packets and rng:int(1, 3) == 1) then
		if placePackets(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Floods" or (focus == "Mix" and mech.pumps and rng:int(1, 3) == 1) then
		if placeFloods(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Bins" or (focus == "Mix" and mech.bins and rng:int(1, 3) == 1) then
		if placeBins(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Trays" or (focus == "Mix" and mech.trays and rng:int(1, 3) == 1) then
		if placeTrays(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Fireflies" or (focus == "Mix" and mech.fireflies and rng:int(1, 3) == 1) then
		if placeSpots(g, rng, id) < 2 then
			return nil
		end
	end
	if focus == "Boxes" or (focus == "Mix" and mech.boxes and rng:int(1, 3) == 1) then
		if placeBoxes(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Scarecrows" or (focus == "Mix" and mech.scarecrows and rng:int(1, 3) == 1) then
		if placeScarecrows(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Letters" or (focus == "Mix" and mech.mail and rng:int(1, 3) == 1) then
		if placeMailboxes(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Clay" or (focus == "Mix" and mech.clay and rng:int(1, 3) == 1) then
		placeClay(g, rng, id)
		if has(g, "aA") == 0 then
			return nil
		end
	end
	if focus == "Snowballs" or (focus == "Mix" and mech.snowballs and rng:int(1, 3) == 1) then
		if not placeSnowballs(g, rng, id) then
			return nil
		end
	end
	if focus == "Webs" or (focus == "Mix" and mech.webs and rng:int(1, 3) == 1) then
		placeWebs(g, rng, id)
	end
	if focus == "Rainbow" or (focus == "Mix" and mech.rainbow and rng:int(1, 3) == 1) then
		placeRainbow(g, rng, id)
	end
	if focus == "Tarps" or (focus == "Mix" and mech.tarps and rng:int(1, 3) == 1) then
		if placeTarps(g, rng, id) == 0 and focus == "Tarps" then
			return nil
		end
	end
	if focus == "Quilts" or (focus == "Mix" and mech.quilts and rng:int(1, 3) == 1) then
		if placeQuilts(g, rng, id) == 0 then
			return nil
		end
	end
	if focus == "Statues" or (focus == "Mix" and mech.statues and rng:int(1, 3) == 1) then
		if placeStatues(g, rng, id) == 0 and focus == "Statues" then
			return nil
		end
	end
	local pumpkins = 0
	if focus == "Pumpkins" or (focus == "Mix" and mech.pumpkins and rng:int(1, 3) == 1) then
		pumpkins = placePumpkins(g, rng, id)
	end
	if focus == "Muddy" or (focus == "Mix" and mech.muddy and rng:int(1, 3) == 1) then
		local muddy = placeMuddy(g, rng, id)
		if muddy == 0 and focus == "Muddy" then
			return nil
		end
		pumpkins += muddy
	end
	keepRowsOpen(g)
	local portals = {}
	if mech.portals and (id == PORTAL_INTRO or (not INTROS[id] and rng:int(1, 3) <= 2)) then
		portals = placePortals(g, rng, id)
		if #portals == 0 and id == PORTAL_INTRO then
			return nil
		end
	end
	if focus == "Baskets" or (focus == "Mix" and mech.baskets and rng:int(1, 3) == 1) then
		if pumpkins > 0 then
			return nil -- basket levels get their pumpkins from the baskets
		end
		pumpkins = placeBaskets(g, rng, id, portals)
		if pumpkins == 0 then
			return nil
		end
	end
	local hens = 0
	if henFocus or (focus == "Mix" and mech.hens and rng:int(1, 3) == 1) then
		hens = placeHens(g, rng, id, portals)
		if hens == 0 then
			return nil
		end
	end
	if focus == "Springs" or (focus == "Mix" and mech.springs and rng:int(1, 3) == 1) then
		if placeSprings(g, rng, id, portals) == 0 then
			return nil
		end
	end
	local fences = {}
	if focus == "Fences" or (focus == "Mix" and mech.fences and rng:int(1, 3) == 1) then
		fences = placeFences(g, rng, id)
		if #fences < 3 then
			return nil
		end
	end
	if focus == "Hedges" or (focus == "Mix" and mech.hedges and rng:int(1, 3) == 1) then
		local hedges = placeFences(g, rng, id, true, fences)
		if #hedges < 3 then
			return nil
		end
		table.move(hedges, 1, #hedges, #fences + 1, fences)
	end
	if #portals > 0 or pumpkins > 0 then
		for y = 1, g.h do
			local open = false
			for x = 1, g.w do
				open = open or g[y][x] == "." or g[y][x] == "m" or g[y][x] == "M" or g[y][x] == "g" or g[y][x] == "e" or g[y][x] == "b" or g[y][x] == "r" or g[y][x] == "i" or g[y][x] == "a" or g[y][x] == "A"
			end
			if not open then
				return nil
			end
		end
	end
	if not connected(g) then
		return nil
	end

	local colorCount = if mech.sixColors and difficulty ~= "Normal" and rng:int(1, 3) == 1 then 6 else 5
	local colors = table.clone(Tiles.Names)
	rng:shuffle(colors)
	colors = table.move(colors, 1, colorCount, 1, {})
	if hens > 0 and not table.find(colors, "Egg") then
		colors[#colors] = "Egg" -- hen houses lay eggs
	end
	table.sort(colors, function(a, b)
		return Tiles.ByName[a] < Tiles.ByName[b]
	end)

	local goals = {}
	if has(g, "mMu") > 0 then
		table.insert(goals, { kind = "Mud" })
	end
	if has(g, "123C") > 0 then
		table.insert(goals, { kind = "HayBale" })
	end
	if has(g, "fF") > 0 then
		table.insert(goals, { kind = "Frost" })
	end
	if has(g, "w") > 0 then
		table.insert(goals, { kind = "Weeds" })
	end
	if pumpkins > 0 then
		table.insert(goals, { kind = "Pumpkins", count = pumpkins })
	end
	if has(g, "cz") > 0 then
		table.insert(goals, { kind = "Clover" })
	end
	if has(g, "sS") > 0 then
		table.insert(goals, { kind = "Stones" })
	end
	local breakable = 0
	for _, f in fences do
		if f[3] == "r" or f[3] == "d" then
			breakable += 1
		end
	end
	if breakable > 0 then
		table.insert(goals, { kind = "Fences" })
	end
	if has(g, "ge") > 0 then
		table.insert(goals, { kind = "Goo" })
	end
	if has(g, "b") > 0 then
		table.insert(goals, { kind = "Statues" })
	end
	if has(g, "t") > 0 then
		table.insert(goals, { kind = "Tarps" })
	end
	if has(g, "n") > 0 then
		table.insert(goals, { kind = "Webs" })
	end
	if has(g, "q") > 0 then
		table.insert(goals, { kind = "Quilts" })
	end
	if has(g, "i") > 0 then
		table.insert(goals, { kind = "Snowballs" })
	end
	if has(g, "aA") > 0 then
		table.insert(goals, { kind = "Clay" })
	end
	if has(g, "l") > 0 then
		table.insert(goals, { kind = "Letters" })
	end
	if has(g, "vV") > 0 then
		table.insert(goals, { kind = "Boxes" })
	end
	if has(g, "T") > 0 then
		table.insert(goals, { kind = "Blooms" })
	end
	if has(g, "E") > 0 then
		table.insert(goals, { kind = "Lambs" })
	end
	if has(g, "R") > 0 then
		table.insert(goals, { kind = "Trays" })
	end
	if has(g, "B") > 0 then
		table.insert(goals, { kind = "Bins" })
	end
	if has(g, "W") > 0 then
		table.insert(goals, { kind = "Floods" })
	end
	if has(g, "K") > 0 then
		table.insert(goals, { kind = "Packets" })
	end
	if has(g, "I") > 0 then
		table.insert(goals, { kind = "Gophers" })
	end
	if has(g, "J") > 0 then
		table.insert(goals, { kind = "Jars" })
	end
	if has(g, "X") > 0 then
		table.insert(goals, { kind = "Tools" })
	end
	if has(g, "Z") > 0 then
		table.insert(goals, { kind = "Vanes" })
	end
	if has(g, "Y") > 0 then
		table.insert(goals, { kind = "Vines" })
	end
	if has(g, "Q") > 0 then
		table.insert(goals, { kind = "Mist" })
	end
	if has(g, "N") > 0 then
		-- About one firefly per lit spot every couple of swaps; a few more as levels go on.
		local count = if id == FIREFLY_INTRO then 6 else rng:int(6, 9) + (id - FIREFLY_INTRO) // 6
		table.insert(goals, { kind = "Fireflies", count = math.min(count, 20) })
	end
	local hives = has(g, "j")
	if hives > 0 then
		-- Each hit sends one jar: about four per hive, a few more as levels go on.
		local count = if id == HIVE_INTRO then 8 else 3 * hives + rng:int(2, 4) + (id - HIVE_INTRO) // 10
		table.insert(goals, { kind = "Honey", count = math.min(count, 40) })
	end
	if #goals > 3 then
		return nil -- the goal bar shows 3 at most
	end
	-- Frost and bales can leave too few swappable tiles: the board must deal playable.
	local probe = { layout = layoutText(g), portals = portals, fences = fences, colors = colors, goals = { { kind = "Collect", tile = colors[1], count = 1 } }, moves = 1 }
	for seed = 1, 10 do
		if not Matcher.hasPossibleMove(Engine.new(probe, seed).board) then
			return nil
		end
	end
	local collects = if #goals == 0 then rng:int(1, 2) elseif id >= 20 and #goals < 2 and rng:int(1, 2) == 1 then 1 else 0
	if focus == "Collect" and collects == 0 then
		collects = 1
	end
	if (focus == "Crates" or focus == "Rainbow" or focus == "Scarecrows" or focus == "Hedges") and collects == 0 then
		collects = 1 -- crates, rainbow patches, scarecrows and hedges have no goal of their own
	end
	if INTROS[id] and id ~= PORTAL_INTRO and id ~= CRATE_INTRO and id ~= RAINBOW_INTRO and id ~= SCARECROW_INTRO and id ~= HEDGE_INTRO then
		collects = 0 -- an intro level is about the new obstacle alone
	end
	local picks = table.clone(colors)
	rng:shuffle(picks)
	if hens > 0 then
		-- Hen levels always ask for eggs; other collect goals pick other tiles.
		if #goals >= 3 then
			return nil -- no room in the goal bar for the eggs
		end
		table.remove(picks, table.find(picks, "Egg"))
		table.insert(goals, { kind = "Collect", tile = "Egg", count = math.min(MAX_COLLECT, 12 + id // 20 + hens * 4) })
		collects = math.min(collects, 2 - #goals + 1)
	end
	for i = 1, collects do
		local count = 10 + math.floor(id / 4) + rng:int(0, 6)
		if collects == 1 and #goals == 0 then
			count = math.floor(count * 1.6)
		end
		count = math.min(count, MAX_COLLECT)
		table.insert(goals, { kind = "Collect", tile = picks[i], count = count })
	end

	return {
		id = id,
		name = name,
		difficulty = difficulty,
		moves = 25,
		colors = colors,
		layout = layoutText(g),
		portals = if #portals > 0 then portals else nil,
		fences = if #fences > 0 then fences else nil,
		goals = goals,
		rewards = table.clone(REWARDS[difficulty]),
	}
end

-- Tuning --------------------------------------------------------------------------


local function rate(level, moves)
	local copy = table.clone(level)
	copy.moves = moves
	return Bot.play(copy, GAMES, level.id).winRate
end

-- Fewest moves that reach the target (binary search; the bot is noisy but
-- the trend is steady enough).
local function tune(level, target)
	local lo, hi = MIN_MOVES, MAX_MOVES
	if rate(level, hi) < target then
		return nil, "too hard"
	end
	if rate(level, lo) >= target then
		return lo, "too easy"
	end
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if rate(level, mid) >= target then
			hi = mid
		else
			lo = mid
		end
	end
	return hi
end

local function scaleCollects(level, factor)
	for _, goal in level.goals do
		if goal.kind == "Collect" then
			goal.count = math.clamp(math.floor(goal.count * factor + 0.5), 6, MAX_COLLECT)
		end
	end
end

-- The bot is much worse than a person at steering pumpkins down and at
-- spreading clover, so it gets a lower bar on those levels (their intro
-- levels use the usual one).
local GUIDED_TARGET_SCALE = 0.7

local function hasGoal(level, kind)
	for _, goal in level.goals do
		if goal.kind == kind then
			return true
		end
	end
	return false
end

local function build(id)
	local baseTarget = targetOf(id, difficultyOf(id))
	for variant = 0, 19 do -- later variants only matter to levels the first ten fail
		local level = draft(id, variant)
		local target = baseTarget
		if level and not INTROS[id] and (hasGoal(level, "Pumpkins") or hasGoal(level, "Clover")) then
			target *= GUIDED_TARGET_SCALE
		end
		if level and Levels.validate(level) == nil then
			local moves, note = tune(level, target)
			if note == "too easy" and INTROS[id] then
				-- An intro level may be easy; it only teaches the new obstacle.
				moves, note = MIN_MOVES + 3, nil
			end
			if note == "too easy" then
				-- Ask for more: bigger collect goals, or an extra one.
				local hasCollect = false
				for _, goal in level.goals do
					hasCollect = hasCollect or goal.kind == "Collect"
				end
				if not hasCollect and #level.goals < 3 then
					table.insert(level.goals, { kind = "Collect", tile = level.colors[(id % #level.colors) + 1], count = 12 + id // 5 })
				else
					scaleCollects(level, 1.5)
				end
				moves, note = tune(level, target)
			end
			if moves and note == nil then
				level.moves = moves
				return level, rate(level, moves), variant, target
			end
		end
	end
	error("could not build level " .. id)
end

for id = FIRST, LAST do
	local started = clock()
	local level, winRate, variant, target = build(id)
	print(string.format("-- level %d: bot wins %d%% (target %d%%), variant %d, %.0fs", id, winRate * 100, target * 100, variant, clock() - started))
	print(LevelText.write(level))
end

-- Builds the art models outside Roblox and writes every part as JSON, for the preview
-- renderer in tools/artpreview/ (see tools/artpreview/README.md).
-- Run from the farm/ folder:  lune run tools/artdump.luau <scene> <out.json>
-- Scenes: crops, animals, buildings, factories, houses, community, plot, decor, all

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- The Art modules use Roblox's globals; Lune keeps them in @lune/roblox.
Instance = roblox.Instance
Vector3 = roblox.Vector3
CFrame = roblox.CFrame
Color3 = roblox.Color3
Enum = roblox.Enum

local Showcase = require("./Showcase")

local sceneName = process.args[1] or "all"
local outPath = process.args[2] or "scene.json"

local root = Instance.new("Model")
Showcase.build(sceneName, root)

local parts = {}
local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
		local shape = "Block"
		if d:IsA("WedgePart") then
			shape = "Wedge"
		elseif d:IsA("Part") then
			shape = tostring(d.Shape):match("%.(%w+)$") or "Block"
		end
		local c = d.Color
		table.insert(parts, {
			shape = shape,
			size = { d.Size.X, d.Size.Y, d.Size.Z },
			cf = { d.CFrame:GetComponents() },
			c = { c.R, c.G, c.B },
			t = d.Transparency,
			shadow = d.CastShadow,
			neon = d.Material == Enum.Material.Neon,
		})
	end
end

fs.writeFile(outPath, require("@lune/serde").encode("json", { parts = parts }))
print(string.format("%s: %d parts -> %s", sceneName, count, outPath))

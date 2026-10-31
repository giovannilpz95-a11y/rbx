--!strict
-- Reward fly-ins (Township's convention C12): Coins, Gems and XP icons, or an item's picture,
-- fly from where they were earned to their HUD counter, which bumps as they land.
-- A layer above every panel so the icons are never hidden. Reduce Motion skips the flight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcons = require(ReplicatedStorage:WaitForChild("FarmShared").Art.Icons)

local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit
local Motion = Ui.theme.Motion

local Fx = {}

local layer: ScreenGui? = nil

local function getLayer(): ScreenGui
	if layer == nil then
		layer = Ui.new("ScreenGui", {
			Name = "FarmFx",
			ResetOnSpawn = false,
			IgnoreGuiInset = false, -- same as the HUD, so the pill positions line up
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 30,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
	end
	return layer :: ScreenGui
end

-- Up to `copies` icons of a currency (Coins, Gems, XP) fly from `from` to its pill.
function Fx.currency(kind: string, from: Vector2, copies: number?)
	local to, target = Hud.flyTarget(kind)
	if to == nil then
		return
	end
	local n = math.clamp(copies or 3, 1, 6)
	for i = 1, n do
		task.delay((i - 1) * 0.08, function()
			local icon = Kit.icon(kind, 36)
			icon.Parent = getLayer()
			local jitter = Vector2.new(((i * 37) % 40) - 20, ((i * 53) % 30) - 15)
			Motion.flyTo(icon, from + jitter, to :: Vector2, function()
				if target then
					Motion.bump(target)
				end
			end)
		end)
	end
end

-- An item's picture flies from `from` to the Barn pill.
function Fx.item(itemId: string, from: Vector2)
	local to, target = Hud.flyTarget("Barn")
	if to == nil then
		return
	end
	local ok, icon = pcall(ArtIcons.viewport, itemId, 44)
	if not ok then
		return
	end
	icon.Parent = getLayer()
	Motion.flyTo(icon, from, to :: Vector2, function()
		if target then
			Motion.bump(target)
		end
	end)
end

-- The middle of a GuiObject, in the same pixels Fx and the HUD use.
function Fx.centerOf(gui: GuiObject): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

-- Where the next reward of a kind should fly from: a button remembers its spot when pressed,
-- and the server's pop-up, a moment later, picks it up. Stale after a few seconds.
local ORIGIN_SECONDS = 5
local origins: { [string]: { at: number, pos: Vector2 } } = {}

function Fx.remember(key: string, gui: GuiObject)
	origins[key] = { at = os.clock(), pos = Fx.centerOf(gui) }
end

-- The remembered spot, or the middle of the screen
function Fx.takeOrigin(key: string): Vector2
	local entry = origins[key]
	origins[key] = nil
	if entry and os.clock() - entry.at <= ORIGIN_SECONDS then
		return entry.pos
	end
	return getLayer().AbsoluteSize / 2
end

function Fx.init()
	-- An order's Coins and XP fly from its Deliver (or Buy missing) button to their pills
	Hud.handlers.Order = function(payload)
		Hud.toast(string.format("Order delivered!  +%d Coins  +%d XP", payload.coins, payload.xp))
		local from = Fx.takeOrigin("Order")
		if (payload.coins or 0) > 0 then
			Fx.currency("Coins", from, 4)
		end
		if (payload.xp or 0) > 0 then
			task.delay(0.15, Fx.currency, "XP", from, 3)
		end
	end
end

return Fx

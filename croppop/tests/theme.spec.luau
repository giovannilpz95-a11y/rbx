-- Smoke test of the shared UiTheme (uitheme/, Design/25 UI Style Guide) against the mock
-- Roblox API: every Kit and Motion builder runs, and themed buttons keep their API.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy

local Mock = loadmodule(readfile(Harness.root .. "/tests/roblox_mock.luau"), "tests/roblox_mock.luau", setmetatable({}, { __index = _G }))()
local mockEnv = Mock.environment(game)
local mockRequire = Harness.makeRequire(mockEnv)
local Theme = mockRequire(game.ReplicatedStorage.UiTheme)
local Kit, Motion, Palette = Theme.Kit, Theme.Motion, Theme.Palette
local MouseButton1 = { UserInputType = mockEnv.Enum.UserInputType.MouseButton1 }

test("a themed button draws a lip, face and label and keeps its API", function()
	local root = Mock.newInstance("Frame")
	local b = Kit.button("Collect", "primary", { Parent = root, Size = mockEnv.UDim2.fromOffset(100, 40) })
	eq(b.Parent, root)
	eq(b.ButtonLabel.Text, "Collect")
	eq(b.TextTransparency, 1)
	eq(b.BackgroundTransparency, 1)
	eq(b.ButtonFace.BackgroundColor3, Palette.button.primary.face)
	eq(b.ButtonLip.BackgroundColor3, Palette.button.primary.lip)
	truthy(b.ButtonLabel.TextOutline.Enabled, "white text is outlined")
	-- Press sinks the face, release and leave bring it back
	b.Active = true
	b.InputBegan:Fire(MouseButton1)
	truthy(b.ButtonFace.Position.Y.Offset > 0, "face sinks")
	b.InputEnded:Fire(MouseButton1)
	eq(b.ButtonFace.Position.Y.Offset, 0)
	b.MouseLeave:Fire()
end)

test("skinning an existing button moves its padding onto the text", function()
	local plain = Mock.newInstance("TextButton", {
		Text = "Back",
		BackgroundColor3 = Palette.cream,
		TextColor3 = Palette.text,
	})
	local padding = Mock.newInstance("UIPadding")
	padding.Parent = plain
	Kit.skinButton(plain)
	eq(padding.Parent, plain.ButtonLabel)
	falsy(plain.ButtonLabel.TextOutline.Enabled, "dark text isn't outlined")
	eq(plain.ButtonLip.BackgroundColor3, Palette.button.neutral.lip)
end)

test("windows, pills, icons, bars, badges, toasts and bubbles build", function()
	local root = Mock.newInstance("Frame")
	local closed = false
	local window = Kit.panel(function()
		closed = true
	end)
	window.root.Parent = root
	window.title.Text = "Barn"
	window.close.Activated:Fire()
	truthy(closed, "close button calls back")
	truthy(window.body and window.ribbon and window.card)
	for _, kind in { "Coins", "Gems", "XP", "Barn" } do
		local pill = Kit.pill(kind, 100, { Parent = root })
		pill.label.Text = "5"
		truthy(pill.icon, kind .. " icon")
	end
	local bar = Kit.bar(Palette.xp, { Parent = root })
	Kit.setBar(bar, 0.5)
	truthy(bar.fill.Visible)
	Kit.setBar(bar, 0)
	falsy(bar.fill.Visible)
	local holder = Mock.newInstance("Frame")
	eq(Kit.badge(holder, "3").Text, "3")
	falsy(Kit.badge(holder, "").Visible)
	local toast = Kit.toast(root, "Level 4!", "celebrate")
	eq(toast.Parent, root)
	Mock.runDelayed()
	Mock.runDelayed()
	eq(toast.Parent, nil, "toast removes itself")
	local bubble = Mock.newInstance("TextLabel")
	Kit.skinBubble(bubble)
	eq(bubble.Font, Theme.Type.display)
	Kit.skinPanel(Mock.newInstance("Frame"))
	Kit.skinPanel(Mock.newInstance("TextLabel"))
end)

test("motion helpers run, and Reduce Motion skips them", function()
	local label = Mock.newInstance("TextLabel")
	Motion.popIn(label)
	eq(label.MotionScale.Scale, 1)
	Motion.bump(label)
	Motion.loop(label, { Rotation = 3 }):Cancel()
	Motion.tick(label, 10, 12500, Kit.short)
	eq(label.Text, "12.5K")
	Motion.reduced = true
	local other = Mock.newInstance("TextLabel")
	Motion.popIn(other)
	eq(other.MotionScale, nil)
	eq(Motion.loop(other, { Rotation = 3 }), nil)
	Motion.tick(other, 1, 2, tostring)
	eq(other.Text, "2")
	Motion.reduced = false
end)

test("tabs, stepper, have/need chips, portraits, icon bubbles and edge icons build", function()
	local root = Mock.newInstance("Frame")
	local picked = nil
	local tabs = Kit.tabs({ "All", "Crops", "Goods" }, "All", function(name)
		picked = name
	end, { Parent = root }, { Goods = "2" })
	eq(tabs.frame.Parent, root)
	eq(tabs.buttons.All.ButtonFace.BackgroundColor3, Palette.button.secondary.face, "picked tab is blue")
	eq(tabs.buttons.Crops.ButtonFace.BackgroundColor3, Palette.button.neutral.face)
	eq(tabs.buttons.Goods.Badge.Text, "2")
	tabs.buttons.All.Active = true
	tabs.buttons.All.InputBegan:Fire(MouseButton1)
	eq(picked, nil, "the picked tab does nothing")
	tabs.buttons.Crops.Active = true
	tabs.buttons.Crops.InputBegan:Fire(MouseButton1)
	tabs.buttons.Crops.Activated:Fire()
	eq(picked, "Crops", "press picks the tab once")

	local seen = {}
	local stepper = Kit.stepper(1, 1, 3, function(v)
		table.insert(seen, v)
	end, { Parent = root })
	eq(stepper.label.Text, "1")
	falsy(stepper.minus.Active, "minus greys out at the bottom")
	stepper.set(5)
	eq(stepper.get(), 3, "clamped to max")
	eq(stepper.label.Text, "3")
	falsy(stepper.plus.Active, "plus greys out at the top")
	stepper.set(2)
	eq(#seen, 2)

	local short = Kit.needChip(2, 5, { Parent = root })
	eq(short.label.Text, "2/5")
	falsy(short.met)
	eq(short.frame:FindFirstChild("Tick"), nil)
	local enough = Kit.needChip(57, 3, { Parent = root })
	eq(enough.label.Text, "3/3", "more than needed reads as need/need")
	truthy(enough.met and enough.frame:FindFirstChild("Tick"), "tick when covered")

	for _, style in { "sunhat", "cap", "scarf", "hardhat", "hair" } do
		local portrait = Kit.portrait({ skin = Palette.cream, hat = Palette.coins, style = style }, 56, "Pip", { Parent = root })
		truthy(portrait.face and portrait.plate, style .. " portrait")
	end
	eq(Kit.portrait({ skin = Palette.cream, hat = Palette.coins, style = "cap" }, 40).plate, nil, "no name, no plate")

	local bubble = Kit.iconBubble({ Parent = root })
	Kit.setIconBubble(bubble, "x3")
	truthy(bubble.count.Visible)
	Kit.setIconBubble(bubble, "")
	falsy(bubble.count.Visible)

	local edge = Kit.edgeIcon("🎁", { Parent = root })
	eq(edge.button.Parent, root)
	Kit.setEdgeTimer(edge, "2:10")
	truthy(edge.timer.Visible)
	Kit.setEdgeTimer(edge, "")
	falsy(edge.timer.Visible)
end)

test("rewards fly to their counter, or arrive at once with Reduce Motion", function()
	local layer = Mock.newInstance("Frame")
	local arrived = 0
	local icon = Mock.newInstance("Frame")
	icon.Parent = layer
	Motion.flyTo(icon, mockEnv.Vector2.new(10, 10), mockEnv.Vector2.new(300, 20), function()
		arrived += 1
	end)
	eq(arrived, 0, "still flying")
	Mock.runDelayed()
	Mock.runDelayed()
	eq(arrived, 1)
	eq(icon.Parent, nil, "icon removed on arrival")
	Motion.reduced = true
	local quick = Mock.newInstance("Frame")
	quick.Parent = layer
	Motion.flyTo(quick, mockEnv.Vector2.new(0, 0), mockEnv.Vector2.new(1, 1), function()
		arrived += 1
	end)
	eq(arrived, 2, "arrives at once")
	Motion.reduced = false
end)

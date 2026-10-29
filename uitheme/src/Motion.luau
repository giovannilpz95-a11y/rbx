--!strict
-- Bouncy UI motion (Design/25 UI Style Guide): windows pop in with a little overshoot, buttons
-- squash when pressed, counters tick up and bump. Set Motion.reduced = true (the Reduce
-- Motion setting) to skip the scale effects; state changes still happen instantly.

local TweenService = game:GetService("TweenService")

local Motion = {
	reduced = false,
	time = {
		press = 0.06,
		release = 0.18,
		popIn = 0.28,
		popOut = 0.12,
		bump = 0.1,
		tick = 0.45,
		bob = 0.9,
		fade = 0.35,
	},
}

local function info(seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, reverses: boolean?)
	return TweenInfo.new(
		seconds,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		0,
		reverses or false
	)
end
Motion.info = info

function Motion.tween(
	instance: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(instance, info(seconds, style, direction), props)
	tween:Play()
	return tween
end

-- The UIScale a GuiObject animates with, created on first use.
function Motion.scaleOf(gui: Instance): UIScale
	local scale = gui:FindFirstChild("MotionScale")
	if scale == nil then
		local created = Instance.new("UIScale")
		created.Name = "MotionScale"
		created.Parent = gui
		scale = created
	end
	return scale :: UIScale
end

-- A window or toast appearing: 60% -> overshoot -> 100%.
function Motion.popIn(gui: Instance)
	if Motion.reduced then
		return
	end
	local scale = Motion.scaleOf(gui)
	scale.Scale = 0.6
	Motion.tween(scale, Motion.time.popIn, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- A quick bump, for a counter that just changed or a button that wants attention.
function Motion.bump(gui: Instance, amount: number?)
	if Motion.reduced then
		return
	end
	local scale = Motion.scaleOf(gui)
	scale.Scale = 1
	local tween = TweenService:Create(
		scale,
		info(Motion.time.bump, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, true),
		{ Scale = amount or 1.18 }
	)
	tween:Play()
end

-- Squash on press, spring back on release. `onPress(pressed)` lets a button move its face too.
function Motion.press(button: GuiButton, onPress: ((pressed: boolean) -> ())?)
	local scale = Motion.scaleOf(button)
	local down = false
	local function set(pressed: boolean)
		if pressed == down then
			return
		end
		down = pressed
		if onPress then
			onPress(pressed)
		end
		if Motion.reduced then
			return
		end
		if pressed then
			Motion.tween(scale, Motion.time.press, { Scale = 0.93 })
		else
			Motion.tween(scale, Motion.time.release, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input)
		if isPointer(input) and button.Active then
			set(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPointer(input) then
			set(false)
		end
	end)
	button.MouseLeave:Connect(function()
		set(false)
	end)
end

-- Gentle endless bob, e.g. a ready bubble's StudsOffset. Returns the tween so it can be cancelled.
function Motion.loop(instance: Instance, props: { [string]: any }, seconds: number?): Tween?
	if Motion.reduced then
		return nil
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds or Motion.time.bob, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		props
	)
	tween:Play()
	return tween
end

-- Counts a label from one number to another. A newer tick on the same label wins.
local ticking: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

function Motion.tick(label: TextLabel, from: number, to: number, format: (n: number) -> string)
	local token = (ticking[label] or 0) + 1
	ticking[label] = token
	if Motion.reduced or from == to then
		label.Text = format(to)
		return
	end
	task.spawn(function()
		local steps = 12
		for i = 1, steps do
			task.wait(Motion.time.tick / steps)
			if ticking[label] ~= token then
				return
			end
			local t = i / steps
			local eased = 1 - (1 - t) * (1 - t)
			label.Text = format(math.floor(from + (to - from) * eased + 0.5))
		end
		label.Text = format(to)
	end)
end

return Motion

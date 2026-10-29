--[[
	Just enough of the Roblox API to smoke-test Crop Pop's client and server
	scripts outside Studio: instances with properties and children, signals,
	tweens that finish instantly, task.* that runs right away, and remotes
	that call the server handler directly.

	This checks our own logic (bookkeeping, nil errors, flow between screens),
	not Roblox's behaviour. Real layout and feel still need a Studio play test.
]]

local Mock = {}
Mock.delayed = {}

-- Runs the task.delay callbacks queued so far (not ones they queue).
function Mock.runDelayed()
	local queue = Mock.delayed
	Mock.delayed = {}
	for _, item in queue do
		item.fn(table.unpack(item.args))
	end
end

-- Signals ----------------------------------------------------------------------

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		local entry = { fn = fn, connected = true }
		table.insert(self.handlers, entry)
		return {
			Connected = true,
			Disconnect = function(connection)
				entry.connected = false
				connection.Connected = false
			end,
		}
	end
	function signal:Fire(...)
		for _, entry in table.clone(self.handlers) do
			if entry.connected then
				entry.fn(...)
			end
		end
	end
	function signal:Wait()
		return nil
	end
	return signal
end
Mock.newSignal = newSignal

-- Datatypes --------------------------------------------------------------------

local UDimMeta = {
	__eq = function(a, b)
		return a.Scale == b.Scale and a.Offset == b.Offset
	end,
}
local UDim = {
	new = function(scale, offset)
		return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMeta)
	end,
}

local UDim2Meta = {
	__eq = function(a, b)
		return a.X == b.X and a.Y == b.Y
	end,
	__tostring = function(u)
		return string.format("{%g,%g},{%g,%g}", u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset)
	end,
}
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2Meta)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

local Vector3Meta = {}
local Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3Meta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

local Vector2 = {
	new = function(x, y)
		return { X = x or 0, Y = y or 0 }
	end,
}

local Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}

local TweenInfo = {
	new = function(time, style, direction)
		return { Time = time, EasingStyle = style, EasingDirection = direction }
	end,
}

local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, category)
		local items = enumCache[category]
		if not items then
			items = setmetatable({}, {
				__index = function(_, item)
					return "Enum." .. category .. "." .. item
				end,
			})
			enumCache[category] = items
		end
		return items
	end,
})

-- Instances --------------------------------------------------------------------
-- Same raw layout as the test runner's instances (Name, ClassName, Parent,
-- _children, _order) so mock objects can be parented into the Rojo tree.

local GUI_CLASSES = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
}

local EVENTS = {
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	Activated = true,
	Event = true,
	PlayerRemoving = true,
	PlayerAdded = true,
}

local DEFAULTS = {
	Visible = true,
	Enabled = true,
	AbsoluteSize = Vector2.new(400, 400),
	AbsolutePosition = Vector2.new(0, 0),
	BackgroundTransparency = 0,
	Text = "",
}

local Methods = {}
local MockMeta = {}

-- Mock instances keep Name and Parent in _props (so assignments reach
-- __newindex); the runner's instances keep them as raw fields.
local function nameOf(inst)
	local props = rawget(inst, "_props")
	return if props then props.Name else rawget(inst, "Name")
end

local function parentOf(inst)
	local props = rawget(inst, "_props")
	return if props then props.Parent else rawget(inst, "Parent")
end

local function detach(inst)
	local parent = parentOf(inst)
	if parent then
		local name = nameOf(inst)
		local children = rawget(parent, "_children")
		local order = rawget(parent, "_order")
		local index = table.find(order, inst)
		if index then
			table.remove(order, index)
		end
		if children[name] == inst then
			children[name] = nil
			-- Another child with the same name takes its place, like FindFirstChild.
			for _, other in order do
				if nameOf(other) == name then
					children[name] = other
					break
				end
			end
		end
	end
	rawget(inst, "_props").Parent = nil
end

local function attach(inst, parent)
	detach(inst)
	if parent then
		local children = rawget(parent, "_children")
		if children[nameOf(inst)] == nil then
			children[nameOf(inst)] = inst
		end
		table.insert(rawget(parent, "_order"), inst)
	end
	rawget(inst, "_props").Parent = parent
end

MockMeta.__index = function(self, key)
	local props = rawget(self, "_props")
	local value = props[key]
	if value ~= nil then
		return value
	end
	local method = Methods[key]
	if method then
		return method
	end
	if EVENTS[key] then
		local signal = newSignal()
		props[key] = signal
		return signal
	end
	local child = rawget(self, "_children")[key]
	if child then
		return child
	end
	if DEFAULTS[key] ~= nil then
		return DEFAULTS[key]
	end
	return nil
end

MockMeta.__newindex = function(self, key, value)
	if rawget(self, "_destroyed") and key ~= "Parent" then
		return
	end
	if key == "Parent" then
		attach(self, value)
	elseif key == "Name" then
		local parent = parentOf(self)
		detach(self)
		rawget(self, "_props").Name = value
		if parent then
			attach(self, parent)
		end
	else
		rawget(self, "_props")[key] = value
	end
end

MockMeta.__tostring = function(self)
	return nameOf(self)
end

function Methods.FindFirstChild(self, name)
	return rawget(self, "_children")[name]
end
Methods.WaitForChild = Methods.FindFirstChild

function Methods.GetChildren(self)
	return table.clone(rawget(self, "_order"))
end

function Methods.GetPropertyChangedSignal(self, property)
	local key = "_changed_" .. property
	local props = rawget(self, "_props")
	if not props[key] then
		props[key] = newSignal()
	end
	return props[key]
end

function Methods.IsA(self, className)
	local own = rawget(self, "ClassName")
	if own == className then
		return true
	end
	if className == "GuiObject" then
		return GUI_CLASSES[own] == true
	end
	return className == "Instance"
end

function Methods.Destroy(self)
	for _, child in table.clone(rawget(self, "_order")) do
		child:Destroy()
	end
	detach(self)
	rawset(self, "_destroyed", true)
end

function Methods.GetFullName(self)
	local parent = parentOf(self)
	if parent then
		return parent:GetFullName() .. "." .. nameOf(self)
	end
	return nameOf(self)
end

local function newInstance(className, props)
	local inst = setmetatable({
		ClassName = className,
		_children = {},
		_order = {},
		_props = { Name = className },
	}, MockMeta)
	if className == "BindableEvent" then
		rawget(inst, "_props").Fire = function(self, ...)
			self.Event:Fire(...)
		end
	elseif className == "BindableFunction" then
		rawget(inst, "_props").Invoke = function(self, ...)
			local handler = self.OnInvoke
			assert(handler, "BindableFunction " .. self.Name .. " has no OnInvoke")
			return handler(...)
		end
	elseif className == "RemoteFunction" then
		rawget(inst, "_props").InvokeServer = function(self, ...)
			local handler = self.OnServerInvoke
			assert(handler, "RemoteFunction " .. self.Name .. " has no OnServerInvoke")
			return handler(Mock.localPlayer, ...)
		end
	end
	for k, v in props or {} do
		inst[k] = v
	end
	return inst
end
Mock.newInstance = newInstance

-- Services and globals -----------------------------------------------------------

--[[
	Builds the globals for scripts. `tree` is the runner's DataModel with the
	Rojo-built ReplicatedStorage / ServerScriptService / StarterPlayerScripts.
]]
function Mock.environment(tree)
	local services = {}
	services.ReplicatedStorage = tree.ReplicatedStorage
	services.ServerScriptService = tree.ServerScriptService
	services.ServerStorage = newInstance("ServerStorage")
	services.TweenService = {
		Create = function(_, instance, _info, props)
			local tween = { Completed = newSignal() }
			function tween.Play()
				for k, v in props do
					instance[k] = v
				end
				tween.Completed:Fire(Enum.PlaybackState.Completed)
			end
			function tween.Cancel() end
			return tween
		end,
	}
	services.UserInputService = {
		InputBegan = newSignal(),
		InputChanged = newSignal(),
		InputEnded = newSignal(),
	}
	services.RunService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return true
		end,
	}

	local player = newInstance("Player", { Name = "Tester" })
	player.UserId = 1
	newInstance("PlayerGui").Parent = player
	Mock.localPlayer = player
	services.Players = newInstance("Players")
	services.Players.LocalPlayer = player
	player.Parent = services.Players
	services.Players.GetPlayers = function()
		return { player }
	end
	services.Players.GetPlayerByUserId = function(_, userId)
		return if userId == player.UserId then player else nil
	end

	local fakeGame = setmetatable({}, {
		__index = function(_, key)
			if key == "GetService" then
				return function(_, name)
					return services[name] or error("mock has no service " .. name)
				end
			end
			return services[key]
		end,
	})

	local tasks = {
		wait = function()
			return 0
		end,
		spawn = function(fn, ...)
			fn(...)
		end,
		defer = function(fn, ...)
			fn(...)
		end,
		-- Delayed work waits for Mock.runDelayed(), so timer loops can't spin forever.
		delay = function(_, fn, ...)
			table.insert(Mock.delayed, { fn = fn, args = { ... } })
		end,
	}

	local env = {
		game = fakeGame,
		Instance = { new = newInstance },
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector3 = Vector3,
		Color3 = Color3,
		TweenInfo = TweenInfo,
		Enum = Enum,
		task = tasks,
		warn = function(...)
			print("    warn:", ...)
		end,
		Random = {
			new = function()
				return {
					NextInteger = function(_, lo, hi)
						return math.random(lo, hi)
					end,
				}
			end,
		},
	}
	return env, services
end

Mock.Vector3 = Vector3
Mock.UDim2 = UDim2
Mock.Enum = Enum

return Mock

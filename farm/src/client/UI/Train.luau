--!strict
-- The Train Station panel (Config/Train, shared/Train): one train at a time. At the platform it
-- lists the cars, what each wants and the reward it brings back, with Load (or Buy missing) for
-- each, the bonus for loading them all and Send. While away it shows the time left and a Gem
-- button to bring it back; once back, Unload. The next train can be bought here too.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Train)
local Items = require(Shared.Items)
local QuarryConfig = require(Shared.Config.Quarry)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)
local Train = require(Shared.Train)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local TrainUi = {}

local CAR_HEIGHT = 64
local HELP_CAR_HEIGHT = 92 -- with the help flag button under Load
local BUTTON_WIDTH = 176 -- fits "Buy missing  70 Gems"
local ARM_SECONDS = 10
local sendArmedAt = 0 -- sending with empty cars takes a second tap within ARM_SECONDS

local function line(text: string, order: number, body: Instance, height: number?, color: Color3?)
	return Ui.label(text, {
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, height or 22),
		TextSize = 14,
		TextColor3 = color or Ui.colors.text,
		LayoutOrder = order,
		Parent = body,
	})
end

local function fullButton(text: string, order: number, body: Instance, fn: () -> ()): TextButton
	return Ui.button(text, fn, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order, Parent = body })
end

-- Shrink a button's text to fit it rather than clip it
local function fit(button: TextButton?)
	if button == nil then
		return
	end
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = button.TextSize
	limit.MinTextSize = 9
	limit.Parent = button
	button.TextScaled = true
end

local function rewardName(reward: Train.Reward): string
	local item, qty = reward.item, reward.qty
	local tool = Tools.tools[item]
	local name = if tool
		then (if qty == 1 then tool.displayName else tool.plural)
		elseif item == QuarryConfig.pickaxe then (if qty == 1 then "Pickaxe" else "Pickaxes")
		elseif Items[item] then Items[item].displayName
		else item
	return string.format("%d %s", qty, name)
end

local function describe(rewards: { [string]: number }): string
	local parts = {}
	for item, qty in rewards do
		table.insert(parts, rewardName({ item = item, qty = qty }))
	end
	table.sort(parts)
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

local function carCard(index: number, c: number, car: Train.Car, body: Instance, order: number)
	local state = ClientStore.state or {}
	local canFlag = not car.loaded and (state.level or 0) >= Config.helpFromLevel
	local card = Ui.card({
		Size = UDim2.new(1, -8, 0, if canFlag then HELP_CAR_HEIGHT else CAR_HEIGHT),
		LayoutOrder = order,
		Parent = body,
	})
	local def = Items[car.item]
	local have = ClientStore.itemCount(car.item)
	Ui.label(string.format("Car %d: %d %s", c, car.qty, def.displayName), {
		Font = Ui.theme.Type.display,
		TextSize = 15,
		Size = UDim2.new(1, -(BUTTON_WIDTH + 16), 0, 22),
		Position = UDim2.fromOffset(8, 4),
		Parent = card,
	})
	local status = if car.loaded
			and car.helpedBy
			and car.helpedBy ~= Players.LocalPlayer.UserId
		then "Loaded by a neighbor. Thank you!   ·   brings back " .. rewardName(car.reward)
		elseif car.loaded then "Loaded ✓   ·   brings back " .. rewardName(car.reward)
		else string.format(
			"You have %d   ·   +%d XP   ·   brings back %s",
			have,
			Train.carXp(car),
			rewardName(car.reward)
		)
	Ui.label(status, {
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = if car.loaded
			then Ui.colors.ready
			elseif have >= car.qty then Ui.colors.muted
			else Ui.colors.danger,
		Size = UDim2.new(1, -(BUTTON_WIDTH + 16), 0, 34),
		Position = UDim2.fromOffset(8, 26),
		Parent = card,
	})
	if car.loaded then
		return
	end
	local props = {
		Size = UDim2.fromOffset(BUTTON_WIDTH, 40),
		Position = UDim2.new(1, -(BUTTON_WIDTH + 6), 0, 12),
		Parent = card,
	}
	if canFlag then
		-- Neighbors on this server can load a flagged car from their own Barns (one a train)
		local flag = Ui.button(if car.flagged then "Help asked ✓" else "Ask for help", function()
			Remotes.fire("Train_Flag", index, c)
		end, {
			Size = UDim2.fromOffset(BUTTON_WIDTH, 34),
			Position = UDim2.new(1, -(BUTTON_WIDTH + 6), 0, 54),
			Parent = card,
		})
		fit(flag)
		if car.flagged then
			Ui.setEnabled(flag, true, Ui.colors.selected)
		end
	end
	if have >= car.qty then
		fit(Ui.button("Load", function()
			Remotes.fire("Train_Load", index, c)
		end, props))
	else
		local button = Panels.missingButton(
			string.format("train:%d:%d", index, c),
			{ [car.item] = car.qty },
			props,
			"Train",
			index,
			c
		)
		fit(button)
		if button == nil then
			Ui.setEnabled(Ui.button("Load", function() end, props), false)
		end
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel, arg: string?)
	title.Text = "Train Station"
	local trains = state.trains
	if trains == nil then
		return
	end
	if state.level < Config.unlockLevel then
		line(string.format("The first train pulls in at level %d.", Config.unlockLevel), 1, body)
		return
	end
	local lines = trains.lines or {}
	local index = math.clamp(tonumber(arg) or 1, 1, math.max(1, #lines))
	local now = ClientStore.now()
	local order = 1

	-- Switch between trains
	if #lines > 1 then
		local row = Ui.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 36),
			LayoutOrder = order,
			Parent = body,
		})
		local width = 1 / #lines
		for i, other in lines do
			local mark = if Train.isBack(other, now) then " ✓" elseif Train.isAway(other, now) then " ⏱" else ""
			local button = Ui.button("Train " .. i .. mark, function()
				Panels.open("Train", tostring(i))
			end, {
				Size = UDim2.new(width, -6, 1, 0),
				Position = UDim2.new(width * (i - 1), 3, 0, 0),
				Parent = row,
			})
			if i == index then
				Ui.setEnabled(button, true, Ui.colors.selected)
			end
		end
		order += 1
	end

	local train = lines[index] :: Train.Line?
	if train == nil then
		line("Your first train is on its way.", order, body)
		return
	end
	if Train.isBack(train, now) then
		line(
			string.format("Train %d is back with %s.", index, describe(Train.rewards(train))),
			order,
			body,
			38,
			Ui.colors.ready
		)
		fullButton("Unload", order + 1, body, function()
			Remotes.fire("Train_Unload", index)
		end)
		order += 2
	elseif Train.isAway(train, now) then
		local left = (train.returnAt :: number) - now
		line(
			string.format(
				"Train %d is out with %d of %d cars loaded. It's back in %s with %s.",
				index,
				Train.loadedCount(train),
				#train.cars,
				Timer.format(left),
				describe(Train.rewards(train))
			),
			order,
			body,
			38
		)
		Panels.gemButton("TrainSpeedUp" .. index, "Bring it back now", Speedup.train(left), function()
			Remotes.fire("Train_SpeedUp", index)
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order + 1, Parent = body })
		order += 2
	else
		line(
			"Load the cars from your Barn, then send the train off. Each loaded car brings back the "
				.. "reward on its side; cars that go empty bring nothing.",
			order,
			body,
			38,
			Ui.colors.muted
		)
		order += 1
		for c, car in train.cars do
			carCard(index, c, car, body, order)
			order += 1
		end
		local loaded = Train.loadedCount(train)
		line(
			"Load every car for a bonus: " .. rewardName(train.bonus) .. (if Train.isFull(train) then " ✓" else ""),
			order,
			body,
			nil,
			if Train.isFull(train) then Ui.colors.ready else Ui.colors.text
		)
		order += 1
		local trip = Timer.format(Train.travelSeconds(state.level))
		local armed = os.clock() - sendArmedAt < ARM_SECONDS
		local label = if loaded == 0
			then (if armed then "Tap again to send it empty" else "Send it empty (new cars next time)")
			else string.format("Send it off (%d of %d loaded, back in %s)", loaded, #train.cars, trip)
		fit(fullButton(label, order, body, function()
			if loaded == 0 and os.clock() - sendArmedAt >= ARM_SECONDS then
				sendArmedAt = os.clock()
				Panels.open("Train", tostring(index)) -- redraw with the second-tap label
				return
			end
			sendArmedAt = 0
			Remotes.fire("Train_Send", index)
		end))
		order += 1
	end

	-- The next train
	local nextIndex, def = Train.nextTrain(state)
	if nextIndex and def then
		local can = state.level >= def.level
		line(
			if can
				then string.format("Train %d can join your station for %d Coins.", nextIndex, def.coins)
				else string.format(
					"Train %d can be bought at level %d for %d Coins.",
					nextIndex,
					def.level,
					def.coins
				),
			order,
			body,
			nil,
			Ui.colors.muted
		)
		if can then
			local button = fullButton(
				string.format("Buy train %d  (%d Coins)", nextIndex, def.coins),
				order + 1,
				body,
				function()
					Remotes.fire("Train_Buy")
				end
			)
			Ui.setEnabled(button, state.currencies.Coins >= def.coins)
		end
		order += 2
	end
	line(string.format("Trains sent: %d", trains.trips or 0), order, body, nil, Ui.colors.muted)
end

function TrainUi.init()
	Panels.register("Train", render)
end

return TrainUi

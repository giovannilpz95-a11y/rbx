--!strict
-- Daily Quests (Design/08 Social & Events, shared/Quests): a top-right HUD button with a
-- dot when something can be claimed (11 UI & UX HUD layout), and the Quests panel.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local DailyRules = require(Shared.Daily)
local QuestRules = require(Shared.Quests)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Palette = Ui.theme.Palette

local QuestsUi = {}

local lastTap = 0

-- One tap, acting on press: the panel re-renders every second, which can swap a button out
-- between press and release. Press and Activated can both arrive; the first one wins.
local function pressButton(text: string, fire: () -> (), props: { [string]: any }, enabled: boolean): TextButton
	local function tap()
		if not enabled or time() - lastTap < 0.35 then
			return
		end
		lastTap = time()
		fire()
	end
	local button = Ui.button(text, tap, props)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
	Ui.setEnabled(button, enabled, props.BackgroundColor3)
	return button
end

local function claimable(quests: { [string]: any }?): boolean
	if quests == nil then
		return false
	end
	for _, quest in quests.list do
		if not quest.claimed and quest.progress >= quest.target then
			return true
		end
	end
	return QuestRules.chestReady({ quests = quests })
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Daily Quests"
	local quests = state.quests
	if quests == nil or #quests.list == 0 then
		Ui.label("Daily Quests open when the first-session guide is done.", {
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 40),
			Parent = body,
		})
		return
	end
	for i, quest in quests.list do
		local def = QuestRules.def(quest.kind)
		local card = Ui.card({ Size = UDim2.new(1, -8, 0, 54), LayoutOrder = i, Parent = body })
		Ui.padding(6).Parent = card
		Ui.label(QuestRules.text(quest), {
			Font = Ui.theme.Type.display,
			Size = UDim2.new(1, -120, 0, 20),
			Parent = card,
		})
		Ui.label(
			string.format(
				"%d / %d   ·   %d Coins, %d XP",
				quest.progress,
				quest.target,
				if def then def.coins else 0,
				if def then def.xp else 0
			),
			{
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, -120, 0, 18),
				TextSize = 14,
				TextColor3 = Ui.colors.muted,
				Parent = card,
			}
		)
		local props = {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(110, 34),
			Parent = card,
		}
		if quest.claimed then
			pressButton("Done", function() end, props, false)
		elseif quest.progress >= quest.target then
			pressButton("Claim", function()
				Remotes.fire("Quest_Claim", i)
			end, props, true)
		elseif not quests.rerolled then
			props.BackgroundColor3 = Ui.colors.selected
			pressButton("Swap (free)", function()
				Remotes.fire("Quest_Reroll", i)
			end, props, true)
		end
	end

	local chest = Ui.card({ Size = UDim2.new(1, -8, 0, 46), LayoutOrder = 10, Parent = body })
	Ui.padding(6).Parent = chest
	Ui.label("Bonus chest for all three: Gems or a tool", {
		Size = UDim2.new(1, -120, 1, 0),
		TextWrapped = true,
		TextSize = 14,
		Parent = chest,
	})
	local ready = QuestRules.chestReady({ quests = quests })
	pressButton(if quests.chest then "Opened" else "Open", function()
		Remotes.fire("Quest_Chest")
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = Ui.colors.gems,
		Parent = chest,
	}, ready)

	local now = ClientStore.now()
	local reset = (DailyRules.utcDay(now) + 1) * 86400
	Ui.label(
		string.format("New quests in %s (00:00 UTC). One free swap a day.", Timer.format(math.max(0, reset - now))),
		{
			Size = UDim2.new(1, -8, 0, 20),
			TextSize = 13,
			TextColor3 = Ui.colors.muted,
			LayoutOrder = 11,
			Parent = body,
		}
	)
end

function QuestsUi.init()
	Panels.register("Quests", function(state, body, title)
		render(state, body, title)
	end)

	-- Right side, under the top pills (clear of them on a 750-wide phone): the Quests button, shown once quests are open, with a dot when claimable
	local gui = Ui.new("ScreenGui", {
		Name = "FarmQuests",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local button = Ui.button('📜\n<font size="14">Quests</font>', function()
		Panels.open("Quests")
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 74), -- under the Studio-only Crop Pop launcher too
		Size = UDim2.fromOffset(70, 58),
		RichText = true,
		TextSize = 20,
		LineHeight = 0.9,
		TextColor3 = Palette.text,
		BackgroundColor3 = Palette.button.neutral.face,
		Visible = false,
		Parent = gui,
	})
	local dot = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Palette.button.danger.face,
		Visible = false,
		ZIndex = 6,
		Parent = button,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local function update(state: { [string]: any }?)
		local quests = state and state.quests
		button.Visible = quests ~= nil and #quests.list > 0
		dot.Visible = claimable(quests)
	end
	ClientStore.changed.Event:Connect(update)
	update(ClientStore.state)
end

return QuestsUi

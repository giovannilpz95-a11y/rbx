--!strict
-- The Tonic Shed panel (Config/Tonics, shared/Tonics): build the shed, then switch Farm Tonics
-- on. It lists what's running with the time left and a Stop button, then every tonic with
-- its effect, how long it runs, and its price: free for one found in a Full Hold chest, else
-- Gems (earned-only tonics can't be bought).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Tonics)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tonics = require(Shared.Tonics)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Hud = require(script.Parent.Hud)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local TonicShedUi = {}

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

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Tonic Shed"
	local shed = state.tonics
	if shed == nil then
		return
	end
	local now = ClientStore.now()
	if shed.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Tonic Shed opens at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"Brew Farm Tonics: double crops, double animal goods, richer orders, faster factories and more. "
				.. string.format("Up to %d can run at once, never two of the same.", Config.maxActive),
			1,
			body,
			56
		)
		local population = TownRules.population(state, now)
		line(
			string.format(
				"Build it for %d Coins. Takes %s.  +%d XP  (Population %d / %d)",
				Config.buildCoins,
				Timer.format(Config.buildSeconds),
				Config.buildXp,
				population,
				Config.population
			),
			2,
			body,
			38
		)
		local button = fullButton("Build the Tonic Shed", 3, body, function()
			Remotes.fire("Tonic_Build")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= Config.buildCoins and population >= Config.population)
		-- The Place bar, the same one a new building offers (Main's Place handler closes this
		-- panel and picks the building up)
		Ui.button("Choose its spot", function()
			Hud.popup({ kind = "Place", key = "tonics:TonicShed" })
		end, { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 4, Parent = body })
		line("Or press Move (M) any time to walk it somewhere else.", 5, body, 22, Ui.colors.muted)
		return
	end
	if now < shed.readyAt then
		local left = shed.readyAt - now
		line("Building: " .. Timer.format(left) .. " left.", 1, body)
		Panels.gemButton("TonicShedSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Tonic_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end

	-- Running now
	local order = 1
	local running = Tonics.activeCount(state, now)
	line(
		string.format("Running: %d of %d", running, Config.maxActive),
		order,
		body,
		nil,
		if running > 0 then Ui.colors.ready else Ui.colors.muted
	)
	order += 1
	for _, def in Config.list do
		local entry = Tonics.running(state, def.id, now)
		if entry then
			line(
				string.format("%s: %s. %s left.", def.displayName, def.effect, Timer.format(entry.endsAt - now)),
				order,
				body,
				38
			)
			Ui.button("Stop " .. def.displayName .. " (its time is lost)", function()
				Remotes.fire("Tonic_Cancel", def.id)
			end, { Size = UDim2.new(1, -8, 0, 32), LayoutOrder = order + 1, Parent = body })
			order += 2
		end
	end

	-- Every tonic
	line("Tonics", order, body, nil, Ui.colors.muted)
	order += 1
	local full = running >= Config.maxActive
	for _, def in Config.list do
		local owned = Tonics.owned(state, def.id)
		local isOn = Tonics.running(state, def.id, now) ~= nil
		local runs = Timer.format(def.seconds * (state.timeScale or 1))
		line(
			string.format(
				"%s: %s for %s.%s",
				def.displayName,
				def.effect,
				runs,
				if owned > 0 then string.format(" You have %d.", owned) else ""
			),
			order,
			body,
			38,
			if isOn then Ui.colors.muted else Ui.colors.text
		)
		local opts = { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = order + 1, Parent = body }
		if owned > 0 then
			local button = Ui.button("Switch on (free)", function()
				Remotes.fire("Tonic_Activate", def.id)
			end, opts)
			Ui.setEnabled(button, not isOn and not full)
		elseif def.gems then
			local button = Panels.gemButton("Tonic_" .. def.id, "Switch on", def.gems, function()
				Remotes.fire("Tonic_Activate", def.id)
			end, opts)
			if button and (isOn or full) then
				Ui.setEnabled(button, false)
			end
		else
			line("Found in Full Hold chests on the Cargo Blimp.", order + 1, body, nil, Ui.colors.muted)
		end
		order += 2
	end
	line("Tonics keep running while you're away. Stopping one throws its time away.", order, body, 38, Ui.colors.muted)
end

function TonicShedUi.init()
	Panels.register("TonicShed", render)
end

return TonicShedUi

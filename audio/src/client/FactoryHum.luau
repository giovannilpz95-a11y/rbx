--[[
	Busy factories hum. The farm server sets the attribute Busy = true on a factory's model
	while it works (farm PlotService; the same flag FactoryMotion turns the wheels by), so
	the factory loop plays from the building itself and fades with distance, with no farm
	edits. Works on every plot, so a visitor hears a busy neighbour's mill too.

	Only the few busy factories nearest the camera play, so a farm full of them stays a soft
	bed under the music instead of a wall of motors.
]]

local Workspace = game:GetService("Workspace")

local FactoryHum = {}

local MAX_HUMS = 3 -- busy factories heard at once
local HEAR = 80 -- studs from the camera (the loop's own roll-off ends at 70)
local CHECK = 0.5 -- seconds between looks

-- A small pitch per factory, so a row of different mills doesn't sound like one machine.
local function pitchFor(name: string): number
	local h = 0
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 997
	end
	return (h % 7) - 3 -- -3..+3 semitones
end

local function anchorOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

function FactoryHum.start(GameAudio)
	local plots = Workspace:WaitForChild("Plots", 60)
	if plots == nil then
		return -- no farm in this place
	end
	local playing: { [Model]: { stop: () -> () } } = {}

	while true do
		task.wait(CHECK)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			continue
		end
		local eye = camera.CFrame.Position
		local near: { { model: Model, d: number } } = {}
		for _, plot in plots:GetChildren() do
			for _, child in plot:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("Busy") == true then
					local d = (child:GetPivot().Position - eye).Magnitude
					if d <= HEAR then
						table.insert(near, { model = child, d = d })
					end
				end
			end
		end
		table.sort(near, function(a, b)
			return a.d < b.d
		end)
		local keep: { [Model]: boolean } = {}
		for i = 1, math.min(#near, MAX_HUMS) do
			keep[near[i].model] = true
		end
		for model, handle in playing do
			if not keep[model] or not model:IsDescendantOf(Workspace) then
				handle.stop()
				playing[model] = nil
			end
		end
		for model in keep do
			if playing[model] == nil then
				local anchor = anchorOf(model)
				if anchor then
					playing[model] = GameAudio.attachLoop("FactoryHum", anchor, { pitch = pitchFor(model.Name) })
				end
			end
		end
	end
end

FactoryHum.pitchFor = pitchFor

return FactoryHum

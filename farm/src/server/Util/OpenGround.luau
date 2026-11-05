--!strict
-- Open ground on the Town Square plaza for things the server puts there (photo spots, the Fair
-- Stand): flat paving with nothing standing in a box around the spot. Spots are tried in order
-- (plaza-local degrees and studs out from the middle) and each faces the middle (local -Z).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local OpenGround = {}

-- `clearance` is the box to keep clear, centred at `clearanceAt` in the spot's own frame
function OpenGround.find(angles: { number }, radii: { number }, clearance: Vector3, clearanceAt: CFrame): CFrame?
	local skip: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = skip
	for _, radius in radii do
		for _, degrees in angles do
			local a = math.rad(degrees)
			local x, z = math.cos(a) * radius, math.sin(a) * radius
			local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
			if hit and hit.Position.Y < 2 and hit.Normal.Y > 0.9 then
				local cf = CFrame.lookAt(hit.Position, Vector3.new(0, hit.Position.Y, 0))
				local blocked = false
				for _, p in Workspace:GetPartBoundsInBox(cf * clearanceAt, clearance, overlap) do
					if p.Transparency < 1 or p.CanCollide then -- not an invisible zone
						blocked = true
						break
					end
				end
				if not blocked then
					return cf
				end
			end
		end
	end
	return nil
end

return OpenGround

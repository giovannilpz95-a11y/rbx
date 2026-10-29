--!strict
-- Client access to the server's remotes by name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("FarmRemotes")

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.fire(name: string, ...: any)
	Remotes.get(name):FireServer(...)
end

return Remotes

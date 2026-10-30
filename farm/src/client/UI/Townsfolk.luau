--!strict
-- The townsfolk who place Order Board orders (UI Reference & Gaps G6, Township's convention
-- C14): original peg-folk residents (Design/16 Model Catalog 2.15), drawn by Kit.portrait.
-- Names and looks are ours. Each order gets the same customer for as long as it's on the
-- board, picked from what it asks for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("UiTheme")).Palette

export type Person = { name: string, look: { skin: Color3, hat: Color3, style: string, backdrop: Color3 } }

local hex = Palette.hex

-- stylua: ignore
local PEOPLE: { Person } = {
	{ name = "Nell", look = { skin = hex("#F6D2B4"), hat = hex("#E86A5C"), style = "scarf", backdrop = hex("#FFE3B3") } },
	{ name = "Otis", look = { skin = hex("#C68A62"), hat = hex("#3E8FC9"), style = "cap", backdrop = hex("#CDEBFA") } },
	{ name = "Juniper", look = { skin = hex("#8D5A3B"), hat = hex("#F2C94C"), style = "sunhat", backdrop = hex("#DFF3C8") } },
	{ name = "Bertie", look = { skin = hex("#F1C7A0"), hat = hex("#7A5236"), style = "hair", backdrop = hex("#F6D9E8") } },
	{ name = "Marigold", look = { skin = hex("#E2A97E"), hat = hex("#F08A24"), style = "sunhat", backdrop = hex("#FFF0C2") } },
	{ name = "Wren", look = { skin = hex("#6E4530"), hat = hex("#2FA58A"), style = "scarf", backdrop = hex("#D2F1EA") } },
	{ name = "Dot", look = { skin = hex("#FADCC6"), hat = hex("#9B6BD1"), style = "cap", backdrop = hex("#E8DDF8") } },
	{ name = "Barnaby", look = { skin = hex("#B9774E"), hat = hex("#E0B23A"), style = "hardhat", backdrop = hex("#F3E6C9") } },
}

local Townsfolk = {}

Townsfolk.people = PEOPLE

-- A stable customer for an order: the same wants on the same slot give the same person.
function Townsfolk.forOrder(slot: number, wants: { [string]: number }): Person
	local keys = {}
	for item, qty in wants do
		table.insert(keys, item .. qty)
	end
	table.sort(keys)
	local hash = slot * 7
	for _, key in keys do
		for i = 1, #key do
			hash = (hash * 31 + string.byte(key, i)) % 100003
		end
	end
	return PEOPLE[hash % #PEOPLE + 1]
end

return Townsfolk

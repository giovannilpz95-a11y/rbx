--!strict
-- Number formatting for the HUD and panels (11 UI & UX: numbers abbreviate).

local Format = {}

-- 9999 stays as is; 12400 -> "12.4K"; 3200000 -> "3.2M". Rounds down so a counter never
-- shows more than you have.
function Format.short(n: number): string
	local function trim(value: number, suffix: string): string
		local text = string.format("%.1f", math.floor(value * 10) / 10)
		text = string.gsub(text, "%.0$", "")
		return text .. suffix
	end
	if n < 10000 then
		return tostring(math.floor(n))
	elseif n < 1000000 then
		return trim(n / 1000, "K")
	end
	return trim(n / 1000000, "M")
end

return Format

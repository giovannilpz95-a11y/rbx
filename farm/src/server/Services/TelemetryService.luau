--!strict
-- The one analytics wrapper (Design/09 Roblox Architecture §11, Launch/19 Analytics &
-- Metrics §4). Server-side only, called after an action succeeded. Custom fields: 1 = level
-- band, 2 = context, 3 = cohort tag. Economy events are summed per (currency, flow, SKU) and
-- flushed every 120 s, on level-up and on leaving, to stay inside the experience-wide rate
-- limit; funnel, progression and custom events go out at once.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Analytics = require(Shared.Analytics)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Clock = require(script.Parent.Parent.Util.Clock)

local TelemetryService = {}

type PlayerState = {
	band: string,
	cohort: string,
	balances: { [string]: number }, -- latest balance per currency, for the flush
	buffer: Analytics.Buffer,
	joinedAt: number, -- os.clock()
	social: boolean, -- a friend was on the server at some point this session
	lastSent: { [string]: number }, -- throttled event -> os.clock()
	shopSession: string?, -- the open Shop funnel run
}

local states: { [Player]: PlayerState } = {}

local FIELD1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local FIELD2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local FIELD3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name

local function stateFor(player: Player): PlayerState
	local state = states[player]
	if state == nil then
		state = {
			band = "L01-04",
			cohort = "new_nonpayer",
			balances = {},
			buffer = Analytics.newBuffer(),
			joinedAt = os.clock(),
			social = false,
			lastSent = {},
		}
		states[player] = state
	end
	-- Refresh the cached fields while the profile is loaded (it may be gone on leaving)
	local data = DataService.get(player)
	if data then
		state.band = Analytics.levelBand(data.level)
		state.cohort = Analytics.cohort(data, Clock.now())
	end
	return state
end

local function fields(state: PlayerState, context: string?): { [string]: string }
	local out = { [FIELD1] = state.band, [FIELD3] = state.cohort }
	if context then
		out[FIELD2] = context
	end
	return out
end

local function send(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Telemetry]", err)
	end
end

-- A custom event (19 Analytics §4.6). `throttle`: send at most once per player per 5 min.
function TelemetryService.custom(player: Player, name: string, value: number?, context: string?, throttle: boolean?)
	local state = stateFor(player)
	if throttle then
		local last = state.lastSent[name]
		if last and os.clock() - last < Analytics.throttleSeconds then
			return
		end
		state.lastSent[name] = os.clock()
	end
	send(function()
		AnalyticsService:LogCustomEvent(player, name, value or 0, fields(state, context))
	end)
end

-- Buffered economy event. `reason` is the EconomyService reason; it becomes the SKU.
function TelemetryService.economy(
	player: Player,
	currency: string,
	flow: "Source" | "Sink",
	amount: number,
	balance: number,
	reason: string,
	transactionType: string?,
	context: string?
)
	local state = stateFor(player)
	local sku, txType = Analytics.sku(reason, currency)
	state.balances[currency] = balance
	Analytics.add(state.buffer, currency, flow, sku, transactionType or txType, amount, context)
	if flow == "Sink" and currency == "Gems" and Analytics.isSkip(sku) then
		TelemetryService.custom(player, "GemSkipUsed", amount, sku)
	end
end

-- Send the player's buffered economy events now
function TelemetryService.flush(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	for _, entry in Analytics.drain(state.buffer) do
		send(function()
			AnalyticsService:LogEconomyEvent(
				player,
				if entry.flow == "Source"
					then Enum.AnalyticsEconomyFlowType.Source
					else Enum.AnalyticsEconomyFlowType.Sink,
				entry.currency,
				entry.amount,
				state.balances[entry.currency] or 0,
				entry.transactionType,
				entry.sku,
				fields(state, entry.context)
			)
		end)
	end
end

-- PlayerLevel progression (§4.5): `completed` is the level just finished, named like "L07".
-- EconomyService flushes the buffer before the level changes, so summed events keep the
-- level band they were earned in.
function TelemetryService.levelUp(player: Player, completed: number)
	local state = stateFor(player)
	send(function()
		AnalyticsService:LogProgressionCompleteEvent(
			player,
			"PlayerLevel",
			completed,
			string.format("L%02d", completed),
			fields(state)
		)
	end)
end

local function funnelStep(player: Player, funnel: string, sessionId: string, step: number, stepName: string)
	local state = stateFor(player)
	send(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, stepName, fields(state))
	end)
end

-- The Shop funnel (§4.3 #1): Opened -> Prompted -> Granted. One screen, so no
-- "view product" step; a prompt without an open (a pop-up offer later) starts a new run.
local function shopStep(player: Player, step: number, name: string, fresh: boolean)
	local state = stateFor(player)
	if fresh or state.shopSession == nil then
		state.shopSession = HttpService:GenerateGUID(false)
	end
	funnelStep(player, "Shop", state.shopSession :: string, step, name)
end

function TelemetryService.shopPrompted(player: Player)
	shopStep(player, 2, "Prompted", false)
end

function TelemetryService.shopGranted(player: Player)
	shopStep(player, 3, "Granted", false)
	TelemetryService.flush(player) -- the IAP Gems show without waiting for the next flush
end

-- SessionStart (§4.6): value = minutes away (capped), context = gap bucket, or "first"
function TelemetryService.playerLoaded(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local state = stateFor(player)
	state.joinedAt = os.clock()
	local first = data.meta.sessionCount <= 1 or data.meta.lastSeenAt == 0
	local gap = if first then 0 else math.max(0, Clock.now() - data.meta.lastSeenAt)
	TelemetryService.custom(
		player,
		"SessionStart",
		math.min(math.floor(gap / 60), Analytics.maxGapMinutes),
		if first then "first" else Analytics.gapBucket(gap)
	)
	-- Social vs. solo: is a friend on this server? (checked both ways as players join)
	task.spawn(function()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and friends then
					state.social = true
					local otherState = states[other]
					if otherState then
						otherState.social = true
					end
				end
			end
		end
	end)
end

local function playerRemoving(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	TelemetryService.flush(player)
	local minutes = math.floor((os.clock() - state.joinedAt) / 60)
	send(function()
		AnalyticsService:LogCustomEvent(
			player,
			"SessionEnd",
			minutes,
			fields(state, if state.social then "social" else "solo")
		)
	end)
	states[player] = nil
end

local productPrices: { [number]: number } = {}

local function robuxPrice(productId: number, infoType: Enum.InfoType): number
	local cached = productPrices[productId]
	if cached then
		return cached
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, infoType)
	local price = if ok and type(info) == "table" then tonumber(info.PriceInRobux) or 0 else 0
	productPrices[productId] = price
	return price
end

function TelemetryService.init()
	-- Step 1 of the Shop funnel comes from the client (the panel opening)
	NetService.on(Net.Shop_Opened, 2, 4, function(player)
		shopStep(player, 1, "Opened", true)
		return false
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local price = robuxPrice(productId, Enum.InfoType.Product)
			TelemetryService.custom(player, "PurchasePromptResult", price, if purchased then "bought" else "cancelled")
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local price = robuxPrice(passId, Enum.InfoType.GamePass)
		TelemetryService.custom(player, "PurchasePromptResult", price, if purchased then "bought_pass" else "cancelled")
	end)

	Players.PlayerRemoving:Connect(playerRemoving)

	task.spawn(function()
		while true do
			task.wait(Analytics.flushSeconds)
			for player in states do
				TelemetryService.flush(player)
			end
		end
	end)
end

return TelemetryService

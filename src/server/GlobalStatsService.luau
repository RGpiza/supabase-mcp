local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent.PlayerDataService)

local GlobalStatsService = {}

local DATASTORE_NAME = "GlobalStats"
local DATASTORE_KEY = "Totals"
local SAVE_INTERVAL = 60

local statsStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local statsState = {
	totalDataGenerated = 0,
	totalPrestiges = 0,
}

local initialized = false
local saveDirty = false
local accumulatedTime = 0

local function sanitizeNumber(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return 0
	end
	return math.max(numberValue, 0)
end

local function loadStats()
	local success, stored = pcall(function()
		return statsStore:GetAsync(DATASTORE_KEY)
	end)

	if success and typeof(stored) == "table" then
		statsState.totalDataGenerated = sanitizeNumber(stored.totalDataGenerated or stored.totalData)
		statsState.totalPrestiges = sanitizeNumber(stored.totalPrestiges)
	else
		statsState.totalDataGenerated = 0
		statsState.totalPrestiges = 0
	end
end

local function saveStats()
	if not saveDirty then
		return
	end

	local payload = {
		totalDataGenerated = statsState.totalDataGenerated,
		totalPrestiges = statsState.totalPrestiges,
	}

	local success, err = pcall(function()
		statsStore:SetAsync(DATASTORE_KEY, payload)
	end)

	if success then
		saveDirty = false
	else
		warn("[GlobalStatsService] Failed to save stats:", err)
	end
end

local function applyDataDelta(delta)
	if not delta or delta <= 0 then
		return
	end
	statsState.totalDataGenerated += delta
	saveDirty = true
end

local function applyPrestigeDelta(delta)
	if not delta or delta <= 0 then
		return
	end
	statsState.totalPrestiges += delta
	saveDirty = true
end

function GlobalStatsService.GetStats()
	return {
		totalDataGenerated = statsState.totalDataGenerated,
		totalPrestiges = statsState.totalPrestiges,
	}
end

function GlobalStatsService.Save()
	saveStats()
end

local function onPlayerDataChanged(player, previousState, newState)
	if typeof(newState) ~= "table" then
		return
	end

	local prevData = 0
	if typeof(previousState) == "table" and typeof(previousState.data) == "number" then
		prevData = previousState.data
	end
	local newData = typeof(newState.data) == "number" and newState.data or 0
	applyDataDelta(newData - prevData)

	local prevPrestige = 0
	if typeof(previousState) == "table" and typeof(previousState.prestige) == "number" then
		prevPrestige = previousState.prestige
	end
	local newPrestige = typeof(newState.prestige) == "number" and newState.prestige or 0
	applyPrestigeDelta(newPrestige - prevPrestige)
end

function GlobalStatsService.Init()
	if initialized then
		return
	end
	initialized = true

	loadStats()

	PlayerDataService.OnAfterSet(onPlayerDataChanged)

	RunService.Heartbeat:Connect(function(dt)
		accumulatedTime += dt
		if accumulatedTime >= SAVE_INTERVAL then
			accumulatedTime -= SAVE_INTERVAL
			saveStats()
		end
	end)
end

GlobalStatsService.Init()

return GlobalStatsService

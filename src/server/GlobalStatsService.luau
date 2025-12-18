local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local GlobalStatsService = {}

local DATASTORE_NAME = "GlobalStats"
local DATASTORE_KEY = "Totals"
local SAVE_INTERVAL = 60

local statsStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local statsState = {
	LifetimeData = 0,
	TotalPrestiges = 0,
}
local changedEvent = Instance.new("BindableEvent")

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
		statsState.LifetimeData = sanitizeNumber(stored.LifetimeData or stored.totalDataGenerated or stored.totalData)
		statsState.TotalPrestiges = sanitizeNumber(stored.TotalPrestiges or stored.totalPrestiges)
	else
		statsState.LifetimeData = 0
		statsState.TotalPrestiges = 0
	end
end

local function saveStats()
	if not saveDirty then
		return
	end

	local payload = {
		LifetimeData = statsState.LifetimeData,
		TotalPrestiges = statsState.TotalPrestiges,
		totalDataGenerated = statsState.LifetimeData,
		totalPrestiges = statsState.TotalPrestiges,
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
	statsState.LifetimeData += delta
	saveDirty = true
	changedEvent:Fire("data", delta, statsState.LifetimeData, statsState.TotalPrestiges)
end

local function applyPrestigeDelta(delta)
	if not delta or delta <= 0 then
		return
	end
	statsState.TotalPrestiges += delta
	saveDirty = true
	changedEvent:Fire("prestige", delta, statsState.LifetimeData, statsState.TotalPrestiges)
end

function GlobalStatsService.GetStats()
	return {
		totalDataGenerated = statsState.LifetimeData,
		totalPrestiges = statsState.TotalPrestiges,
		LifetimeData = statsState.LifetimeData,
		TotalPrestiges = statsState.TotalPrestiges,
	}
end

function GlobalStatsService.Save()
	saveStats()
end

function GlobalStatsService.AddData(delta)
	applyDataDelta(delta)
end

function GlobalStatsService.AddPrestige(delta)
	applyPrestigeDelta(delta)
end

function GlobalStatsService.OnChanged(callback)
	if typeof(callback) ~= "function" then
		return { Disconnect = function() end }
	end
	return changedEvent.Event:Connect(callback)
end

function GlobalStatsService.Init()
	if initialized then
		return
	end
	initialized = true

	loadStats()

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

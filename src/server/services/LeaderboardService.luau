local DataStoreService = game:GetService("DataStoreService")

local LeaderboardService = {}

local STORE_NAME = "LeaderboardData"
local orderedStore = DataStoreService:GetOrderedDataStore(STORE_NAME)
local SCALE = 100
local WRITE_COOLDOWN = 60
local DEBUG_LEADERBOARD = false
local lastWriteByUser = {}
local lastValueByUser = {}

local function toNumber(value)
	local num = tonumber(value)
	if not num then
		return 0
	end
	return num
end

local function normalizeValue(value)
	return math.floor(toNumber(value) * SCALE)
end

function LeaderboardService.UpdatePlayerStat(player, value)
	if not player then
		return false
	end

	local key = tostring(player.UserId)
	local statValue = normalizeValue(value)
	local lastValue = lastValueByUser[key]
	if lastValue ~= nil and lastValue == statValue then
		return false
	end
	local now = os.time()
	local lastWrite = lastWriteByUser[key] or 0
	if (now - lastWrite) < WRITE_COOLDOWN then
		return false
	end
	local ok, err = pcall(function()
		orderedStore:SetAsync(key, statValue)
	end)
	if not ok then
		warn("[LeaderboardService] Failed to update stat", key, err)
		return false
	end
	lastWriteByUser[key] = now
	lastValueByUser[key] = statValue
	if DEBUG_LEADERBOARD then
		print(("[LeaderboardService] Write success userId=%s"):format(key))
	end
	return true
end

function LeaderboardService.EnsurePlayerEntry(player, value)
	if not player then
		return false
	end

	local key = tostring(player.UserId)
	local ok, existing = pcall(function()
		return orderedStore:GetAsync(key)
	end)
	if not ok then
		warn("[LeaderboardService] Failed to read stat", key, existing)
		return false
	end
	if existing ~= nil then
		lastValueByUser[key] = tonumber(existing)
		return true
	end

	local statValue = normalizeValue(value)
	local wrote, err = pcall(function()
		orderedStore:SetAsync(key, statValue)
	end)
	if not wrote then
		warn("[LeaderboardService] Failed to seed stat", key, err)
		return false
	end
	lastWriteByUser[key] = os.time()
	lastValueByUser[key] = statValue
	if DEBUG_LEADERBOARD then
		print(("[LeaderboardService] Seed success userId=%s"):format(key))
	end
	return true
end

function LeaderboardService.GetTopPlayers(limit)
	local capped = math.clamp(tonumber(limit) or 10, 1, 50)
	local ok, page = pcall(function()
		return orderedStore:GetSortedAsync(false, capped)
	end)
	if not ok or not page then
		warn("[LeaderboardService] Failed to fetch leaderboard", page)
		return {}
	end

	local entries = page:GetCurrentPage()
	local result = {}
	for _, entry in ipairs(entries) do
		result[#result + 1] = {
			userId = tonumber(entry.key) or 0,
			value = toNumber(entry.value) / SCALE,
		}
	end
	return result
end

return LeaderboardService

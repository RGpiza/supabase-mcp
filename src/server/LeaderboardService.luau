local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderboardService = {}

local GlobalStatsService = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent.GlobalStatsService)
	end)
	if ok and type(mod) == "table" then
		GlobalStatsService = mod
	end
end

local function fireGlobalStatsUpdate()
	local ok, remotes = pcall(function()
		return ReplicatedStorage:FindFirstChild("Remotes")
	end)
	if not ok or not remotes then
		return
	end
	local ev = remotes:FindFirstChild("GlobalStatsUpdate")
	if ev and ev.ClassName == "RemoteEvent" then
		local stats = nil
		if GlobalStatsService and type(GlobalStatsService.GetStats) == "function" then
			pcall(function() stats = GlobalStatsService.GetStats() end)
		end
		pcall(function() ev:FireAllClients(stats) end)
	end
end

local LIFETIME_STORE_NAME = "LifetimeDataLeaderboard"
local WEEKLY_STORE_NAME = "WeeklyDataLeaderboard"
local REWARD_STORE_NAME = "WeeklyLeaderboardRewards"
local ANNOUNCEMENT_STORE_NAME = "WeeklyWinnerAnnouncements"

local LEADERBOARD_DISPLAY_SIZE = 25
local TITLE_RANK_SCOPE = 50
local ORDERED_FETCH_SIZE = math.max(LEADERBOARD_DISPLAY_SIZE, TITLE_RANK_SCOPE)
local SNAPSHOT_SIZE = 100
local CACHE_TTL = 60
local FRIEND_CACHE_TTL = 60
local VALUE_CACHE_TTL = 120
local UPLOAD_INTERVAL = 45
local UPLOAD_POLL_INTERVAL = 10
local WEEK_SECONDS = 7 * 24 * 3600
local STORE_SCALE = 100

local lifetimeStore = DataStoreService:GetOrderedDataStore(LIFETIME_STORE_NAME)
local weeklyStore = DataStoreService:GetOrderedDataStore(WEEKLY_STORE_NAME)
local rewardStore = DataStoreService:GetDataStore(REWARD_STORE_NAME)
local announcementStore = DataStoreService:GetDataStore(ANNOUNCEMENT_STORE_NAME)

local playerSnapshots = {}
local uploadQueue = {}
local lastLifetimeUpload = {}
local lastWeeklyUpload = {}
local lifetimeValueCache = {}
local weeklyValueCache = {}
local topCacheLifetime = {}
local lastLifetimeCacheUpdate = 0
local topCacheWeekly = {}
local lastWeeklyCacheUpdate = 0
local friendCacheByUser = {}
local nameCache = {}
local lifetimeRankMap = {}
local weeklyRankMap = {}

local currentWeekKey = nil
local lastSnapshotWeek = nil
local uploadLoopActive = false
local initialized = false
local lastAnnouncedWeekKey = nil
local latestWeeklyWinnerInfo = nil
local weeklyWinnerListeners = {}
local cacheLoopActive = false
local CACHE_REFRESH_INTERVAL = 60

local function getCurrentWeekInfo()
	local utc = os.date("!*t")
	local dayOfYear = utc.yday or 1
	local weekIndex = math.floor(math.max(dayOfYear - 1, 0) / 7)
	local weekNumber = weekIndex + 1
	local weekKey = string.format("%04d-W%02d", utc.year, weekNumber)

	local secondsIntoWeek = (dayOfYear - (weekIndex * 7 + 1)) * 86400
	secondsIntoWeek += (utc.hour or 0) * 3600
	secondsIntoWeek += (utc.min or 0) * 60
	secondsIntoWeek += utc.sec or 0
	local resetSeconds = math.max(WEEK_SECONDS - secondsIntoWeek, 0)

	return weekKey, resetSeconds
end

local function resolvePlayerName(userId, fallback)
	if not userId then
		return fallback or "Player"
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName or player.Name
	end

	if nameCache[userId] then
		return nameCache[userId]
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		nameCache[userId] = name
		return name
	end

	return fallback or string.format("User %d", userId)
end

local function getSnapshot(userId)
	local snapshot = playerSnapshots[userId]
	if not snapshot then
		snapshot = {
			name = string.format("User %d", userId),
			lifetimeValue = 0,
			weeklyValue = 0,
		}
		playerSnapshots[userId] = snapshot
	end
	return snapshot
end

local function notifyWeeklyWinnerListeners(info)
	if typeof(info) ~= "table" then
		return
	end

	for _, callback in ipairs(weeklyWinnerListeners) do
		local ok, err = pcall(callback, info)
		if not ok then
			warn("[LeaderboardService] Weekly winner listener failed:", err)
		end
	end
end

local function setLatestWeeklyWinner(info, shouldAnnounce)
	if typeof(info) ~= "table" or typeof(info.weekKey) ~= "string" then
		return
	end

	latestWeeklyWinnerInfo = info
	lastAnnouncedWeekKey = info.weekKey

	if shouldAnnounce then
		notifyWeeklyWinnerListeners(info)
	end
end

local function recordWeeklyWinner(info)
	if typeof(info) ~= "table" or typeof(info.weekKey) ~= "string" then
		return
	end

	local storedInfo = info
	local announce = false

	local success = pcall(function()
		announcementStore:UpdateAsync("LatestWeeklyWinner", function(previous)
			if typeof(previous) ~= "table" or previous.weekKey ~= info.weekKey then
				announce = true
				return info
			end
			storedInfo = previous
			return previous
		end)
	end)

	if not success and lastAnnouncedWeekKey ~= info.weekKey then
		announce = true
	end

	setLatestWeeklyWinner(storedInfo, announce)
end

local function loadLatestWeeklyWinner()
	local ok, stored = pcall(function()
		return announcementStore:GetAsync("LatestWeeklyWinner")
	end)
	if ok and typeof(stored) == "table" and typeof(stored.weekKey) == "string" then
		latestWeeklyWinnerInfo = stored
		lastAnnouncedWeekKey = stored.weekKey
	end
end

local function resolveTitle(lifetimeRank, weeklyRank)
	if weeklyRank == 1 then
		return "WEEKLY DOMINATOR"
	end
	if lifetimeRank == 1 then
		return "SYSTEM OVERLORD"
	end
	if lifetimeRank and lifetimeRank <= 10 then
		return "CORE ARCHITECT"
	end
	if lifetimeRank and lifetimeRank <= 50 then
		return "DATA ENGINEER"
	end
	return nil
end

local function updatePlayerTitleFor(userId)
	if not userId then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	local title = resolveTitle(lifetimeRankMap[userId], weeklyRankMap[userId])
	local resolved = title or ""
	if player:GetAttribute("ActiveTitle") ~= resolved then
		player:SetAttribute("ActiveTitle", resolved)
	end
end

local function updateAllPlayerTitles()
	for _, player in ipairs(Players:GetPlayers()) do
		updatePlayerTitleFor(player.UserId)
	end
end

local function trackPlayerValue(player, newState)
	if not player or typeof(newState) ~= "table" then
		return
	end

	local snapshot = getSnapshot(player.UserId)
	snapshot.name = player.DisplayName or player.Name or snapshot.name
	if typeof(newState.lifetimeData) == "number" then
		snapshot.lifetimeValue = math.floor(math.max(newState.lifetimeData or 0, 0) * STORE_SCALE) / STORE_SCALE
	end
	if typeof(newState.weeklyData) == "number" then
		snapshot.weeklyValue = math.floor(math.max(newState.weeklyData or 0, 0) * STORE_SCALE) / STORE_SCALE	end
	uploadQueue[player.UserId] = true
end

local function tryUpload(store, cache, userId, value, force)
	local now = os.clock()
	local last = cache[userId] or 0
	if not force and (now - last) < UPLOAD_INTERVAL then
		return false
	end

	if typeof(value) ~= "number" then
		return false
	end

	value = tonumber(value)
	if not value then
		return false
	end

	local scaled = math.floor(value * STORE_SCALE + 0.5)
	if typeof(scaled) ~= "number" then
		return false
	end
	if scaled ~= scaled then
		return false
	end
	if scaled == math.huge or scaled == -math.huge then
		return false
	end
	if scaled % 1 ~= 0 then
		return false
	end

	local ok = pcall(function()
		store:SetAsync(tostring(userId), scaled)
	end)

	if ok then
		cache[userId] = now
	end

	return ok
end

local function uploadValue(userId, snapshot, force)
	if not snapshot then
		return
	end

	local lifetimeOk = tryUpload(lifetimeStore, lastLifetimeUpload, userId, snapshot.lifetimeValue or 0, force)
	local weeklyOk = tryUpload(weeklyStore, lastWeeklyUpload, userId, snapshot.weeklyValue or 0, force)

	if lifetimeOk or weeklyOk or force then
		if not force then
			uploadQueue[userId] = nil
		end
	end
end

local function ensureUploadLoop()
	if uploadLoopActive then
		return
	end

	uploadLoopActive = true
	task.spawn(function()
		while next(uploadQueue) do
			for userId in pairs(uploadQueue) do
				local snapshot = playerSnapshots[userId]
				if not snapshot then
					uploadQueue[userId] = nil
				else
					uploadValue(userId, snapshot, false)
				end
			end
			task.wait(UPLOAD_POLL_INTERVAL)
		end
		uploadLoopActive = false
	end)
end

local function cleanupFriendCache(userId)
	if userId then
		friendCacheByUser[userId] = nil
	else
		table.clear(friendCacheByUser)
	end
end

local function getCachedValue(userId, metric)
	local snapshot = playerSnapshots[userId]
	if snapshot then
		if metric == "weekly" then
			return snapshot.weeklyValue or 0, snapshot.name
		else
			return snapshot.lifetimeValue or 0, snapshot.name
		end
	end

	local cache = metric == "weekly" and weeklyValueCache or lifetimeValueCache
	local entry = cache[userId]
	if entry and (os.clock() - entry.timestamp) < VALUE_CACHE_TTL then
		return entry.value or 0, entry.name
	end

	local store = metric == "weekly" and weeklyStore or lifetimeStore
	local ok, value = pcall(function()
		return store:GetAsync(tostring(userId))
	end)

	local name = resolvePlayerName(userId)
	local numeric = (ok and typeof(value) == "number" and value or 0) / STORE_SCALE
	cache[userId] = {
		value = numeric,
		name = name,
		timestamp = os.clock(),
	}
	return numeric, name
end

local function copyEntries(source)
	local results = {}
	for _, entry in ipairs(source) do
		table.insert(results, {
			userId = entry.userId,
			name = entry.name,
			value = entry.value,
			rank = entry.rank,
		})
	end
	return results
end

local function refreshLifetimeCache(force)
	local now = os.clock()
	if not force and (now - lastLifetimeCacheUpdate) < CACHE_TTL then
		return true
	end

	local ok, pages = pcall(function()
		return lifetimeStore:GetSortedAsync(false, ORDERED_FETCH_SIZE)
	end)
	if not ok or not pages then
		return false
	end

	table.clear(topCacheLifetime)
	table.clear(lifetimeRankMap)
	for index, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key) or tonumber(entry.scope) or 0
		if index <= LEADERBOARD_DISPLAY_SIZE then
			table.insert(topCacheLifetime, {
				userId = userId,
				name = resolvePlayerName(userId, (playerSnapshots[userId] and playerSnapshots[userId].name) or nil),
				value = (typeof(entry.value) == "number" and entry.value or 0) / STORE_SCALE,
				rank = index,
			})
		end
		if userId ~= 0 and index <= TITLE_RANK_SCOPE then
			lifetimeRankMap[userId] = index
		end
	end
	lastLifetimeCacheUpdate = now
	updateAllPlayerTitles()
	-- notify listeners (GlobalStats)
	pcall(fireGlobalStatsUpdate)
	return true
end

local function refreshWeeklyCache(force)
	local ok, pages = pcall(function()
		return weeklyStore:GetSortedAsync(false, ORDERED_FETCH_SIZE)
	end)
	if not ok or not pages then
		return false
	end
	local now = os.clock()
	if not force and (now - lastWeeklyCacheUpdate) < CACHE_TTL then
		return true
	end

	if not ok or not pages then
		return false
	end

	table.clear(topCacheWeekly)
	table.clear(weeklyRankMap)
	for index, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key) or tonumber(entry.scope) or 0
		if index <= LEADERBOARD_DISPLAY_SIZE then
			table.insert(topCacheWeekly, {
				userId = userId,
				name = resolvePlayerName(userId, (playerSnapshots[userId] and playerSnapshots[userId].name) or nil),
				value = (typeof(entry.value) == "number" and entry.value or 0) / STORE_SCALE,				rank = index,
			})
		end
		if userId ~= 0 and index <= TITLE_RANK_SCOPE then
			weeklyRankMap[userId] = index
		end
	end
	lastWeeklyCacheUpdate = now
	updateAllPlayerTitles()
		-- notify listeners (GlobalStats)
		pcall(fireGlobalStatsUpdate)
		return true
end

local function getLifetimePayload(player, force)
	if force then
		refreshLifetimeCache(true)
	else
		if not refreshLifetimeCache(false) then
			refreshLifetimeCache(true)
		end
	end
	return buildGlobalPayload(player)
end

local function startCacheRefreshLoop()
	if cacheLoopActive then
		return
	end
	cacheLoopActive = true

	task.spawn(function()
		while true do
			refreshLifetimeCache(true)
			refreshWeeklyCache(true)
			task.wait(CACHE_REFRESH_INTERVAL)
		end
	end)
end

local function grantReward(userId, tier)
	local expiresAt = os.time() + WEEK_SECONDS
	local player = Players:GetPlayerByUserId(userId)
	if player then
		PlayerDataService.Set(player, {
			weeklyReward = {
				tier = tier,
				expiresAt = expiresAt,
			},
		})
		return
	end

	local key = tostring(userId)
	pcall(function()
		rewardStore:UpdateAsync(key, function(old)
			local queue = old or {}
			table.insert(queue, {
				tier = tier,
				expiresAt = expiresAt,
			})
			return queue
		end)
	end)
end

local function getTierForRank(rank)
	if rank == 1 then
		return "gold"
	elseif rank <= 10 then
		return "silver"
	elseif rank <= 50 then
		return "bronze"
	end
	return nil
end

local function captureWeeklySnapshot(weekKey)
	if not weekKey or lastSnapshotWeek == weekKey then
		return
	end

	local ok, pages = pcall(function()
		return weeklyStore:GetSortedAsync(false, SNAPSHOT_SIZE)
	end)
	if not ok or not pages then
		return
	end

	local topEntryInfo = nil

	for index, entry in ipairs(pages:GetCurrentPage()) do
		local tier = getTierForRank(index)
		if tier then
			local userId = tonumber(entry.key) or tonumber(entry.scope) or 0
			if userId and userId ~= 0 then
				if index == 1 then
					topEntryInfo = {
						weekKey = weekKey,
						userId = userId,
						name = resolvePlayerName(userId, (playerSnapshots[userId] and playerSnapshots[userId].name) or nil),
						value = (typeof(entry.value) == "number" and entry.value or 0) / STORE_SCALE,
					}
				end
				grantReward(userId, tier)
				pcall(function()
					weeklyStore:SetAsync(tostring(userId), 0)
				end)
			end
		end
	end

	if topEntryInfo then
		recordWeeklyWinner(topEntryInfo)
	end

	lastSnapshotWeek = weekKey
	table.clear(weeklyValueCache)
	table.clear(topCacheWeekly)
	table.clear(weeklyRankMap)
	lastWeeklyCacheUpdate = 0
	cleanupFriendCache()
	updateAllPlayerTitles()
end

local function ensureWeekState()
	local weekKey = getCurrentWeekInfo()
	if not currentWeekKey then
		currentWeekKey = weekKey
		lastSnapshotWeek = weekKey
		return
	end

	if weekKey ~= currentWeekKey then
		captureWeeklySnapshot(currentWeekKey)
		currentWeekKey = weekKey
	end
end

local function collectFriendIds(player)
	local friends = {}
	if not player then
		return friends
	end

	local success, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not success or not pages then
		return friends
	end

	local collecting = true
	while collecting do
		for _, item in ipairs(pages:GetCurrentPage()) do
			if typeof(item) == "table" and typeof(item.Id) == "number" then
				table.insert(friends, item.Id)
			end
		end

		if pages.IsFinished then
			collecting = false
		else
			local ok = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)
			if not ok then
				break
			end
		end
	end

	return friends
end

local function buildGlobalPayload(player)
	if not refreshLifetimeCache(false) then
		refreshLifetimeCache(true)
	end

	local youName = "You"
	local youValue = 0
	local youRank = nil

	if player then
		youName = player.DisplayName or player.Name or youName
		local snapshot = playerSnapshots[player.UserId]
		if snapshot then
			youValue = snapshot.lifetimeValue or 0
		else
			youValue = select(1, getCachedValue(player.UserId, "lifetime"))
		end
		for _, entry in ipairs(topCacheLifetime) do
			if entry.userId == player.UserId then
				youRank = entry.rank
				break
			end
		end
	end

	return {
		top = copyEntries(topCacheLifetime),
		you = {
			name = youName,
			value = youValue,
			rank = youRank,
		},
	}
end

local function buildFriendPayload(player)
	if not player then
		return buildGlobalPayload(nil)
	end

	local userId = player.UserId
	local cached = friendCacheByUser[userId]
	if cached and (os.clock() - cached.timestamp) < FRIEND_CACHE_TTL then
		return cached.payload
	end

	local friends = collectFriendIds(player)
	table.insert(friends, userId)

	local entries = {}
	local youValue = 0
	for _, friendId in ipairs(friends) do
		local value, name = getCachedValue(friendId, "lifetime")
		if friendId == userId then
			youValue = value
		end
		if value > 0 or friendId == userId then
			table.insert(entries, {
				userId = friendId,
				name = name or resolvePlayerName(friendId),
				value = value,
			})
		end
	end

	table.sort(entries, function(a, b)
		return (a.value or 0) > (b.value or 0)
	end)

	if #entries > LEADERBOARD_DISPLAY_SIZE then
		for index = #entries, LEADERBOARD_DISPLAY_SIZE + 1, -1 do
			table.remove(entries, index)
		end
	end

	local youRank = nil
	for index, entry in ipairs(entries) do
		entry.rank = index
		if entry.userId == userId then
			youRank = index
		end
	end

	local payload = {
		top = entries,
		you = {
			name = player.DisplayName or player.Name or "You",
			value = youValue,
			rank = youRank,
		},
	}

	friendCacheByUser[userId] = {
		timestamp = os.clock(),
		payload = payload,
	}

	return payload
end

local function buildWeeklyPayload(player)
	ensureWeekState()
	if not refreshWeeklyCache(false) then
		refreshWeeklyCache(true)
	end

	local _, resetSeconds = getCurrentWeekInfo()

	local youName = "You"
	local youValue = 0
	local youRank = nil

	if player then
		youName = player.DisplayName or player.Name or youName
		local snapshot = playerSnapshots[player.UserId]
		if snapshot then
			youValue = snapshot.weeklyValue or 0
		else
			youValue = select(1, getCachedValue(player.UserId, "weekly"))
		end
		for _, entry in ipairs(topCacheWeekly) do
			if entry.userId == player.UserId then
				youRank = entry.rank
				break
			end
		end
	end

	return {
		top = copyEntries(topCacheWeekly),
		you = {
			name = youName,
			value = youValue,
			rank = youRank,
		},
		resetSeconds = resetSeconds,
	}
end

local function claimPendingRewards(player)
	if not player then
		return
	end

	local key = tostring(player.UserId)
	local pending
	local ok = pcall(function()
		rewardStore:UpdateAsync(key, function(old)
			pending = old
			return nil
		end)
	end)

	if not ok or not pending then
		return
	end

	local bestTier = nil
	local bestExpires = 0
	local priority = { gold = 3, silver = 2, bronze = 1 }
	for _, reward in ipairs(pending) do
		if typeof(reward) == "table" and typeof(reward.tier) == "string" then
			local tierPriority = priority[reward.tier] or 0
			if tierPriority > (priority[bestTier] or 0) then
				bestTier = reward.tier
				bestExpires = typeof(reward.expiresAt) == "number" and reward.expiresAt or (os.time() + WEEK_SECONDS)
			end
		end
	end

	if bestTier then
		PlayerDataService.Set(player, {
			weeklyReward = {
				tier = bestTier,
				expiresAt = bestExpires,
			},
		})
	end
end

function LeaderboardService.GetLeaderboard(player, mode)
	if mode == "friends" then
		return buildFriendPayload(player)
	elseif mode == "weekly" then
		return buildWeeklyPayload(player)
	else
		return getLifetimePayload(player, false)
	end
end

function LeaderboardService.GetLifetimeLeaderboard(player, force)
	return getLifetimePayload(player, force == true)
end

function LeaderboardService.GetWeeklyResetInfo(player)
	ensureWeekState()
	local _, resetSeconds = getCurrentWeekInfo()
	local clampedSeconds = math.max(resetSeconds or 0, 0)
	local resetTimestamp = os.time() + clampedSeconds

	if not refreshWeeklyCache(false) then
		refreshWeeklyCache(true)
	end

	local tier
	local rank
	if player then
		local userId = player.UserId
		rank = weeklyRankMap[userId]
		if rank and rank > 0 then
			tier = getTierForRank(rank)
		end
	end

	return {
		resetSeconds = resetSeconds,
		resetTimestamp = resetTimestamp,
		qualifyingTier = tier,
		rank = rank,
	}
end

function LeaderboardService.GetLatestWeeklyWinner()
	if latestWeeklyWinnerInfo then
		return table.clone(latestWeeklyWinnerInfo)
	end
	return nil
end

function LeaderboardService.OnWeeklyWinnerAnnounced(callback)
	if typeof(callback) ~= "function" then
		return function() end
	end

	table.insert(weeklyWinnerListeners, callback)
	return function()
		for index, stored in ipairs(weeklyWinnerListeners) do
			if stored == callback then
				table.remove(weeklyWinnerListeners, index)
				break
			end
		end
	end
end

function LeaderboardService.ForceSync(player)
	if not player then
		return
	end

	local userId = player.UserId
	local snapshot = getSnapshot(userId)
	local state = PlayerDataService.Get(player)
	if typeof(state) == "table" then
		if typeof(state.lifetimeData) == "number" then
			snapshot.lifetimeValue = math.floor(math.max(state.lifetimeData, 0) * STORE_SCALE) / STORE_SCALE
		end
		if typeof(state.weeklyData) == "number" then
			snapshot.weeklyValue = math.floor(math.max(state.weeklyData, 0) * STORE_SCALE) / STORE_SCALE
		end
	end

	uploadValue(userId, snapshot, true)
	cleanupFriendCache(userId)

	lifetimeValueCache[userId] = nil
	weeklyValueCache[userId] = nil
end

function LeaderboardService.Init()
	if initialized then
		return
	end
	initialized = true

	ensureWeekState()
	loadLatestWeeklyWinner()
	startCacheRefreshLoop()

	PlayerDataService.OnAfterSet(function(player, _, newState)
		ensureWeekState()
		trackPlayerValue(player, newState)
		ensureUploadLoop()
		updatePlayerTitleFor(player and player.UserId or nil)
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("ActiveTitle", player:GetAttribute("ActiveTitle") or "")
		local state = PlayerDataService.Get(player)
		if typeof(state) == "table" then
			trackPlayerValue(player, state)
		end
		claimPendingRewards(player)
		ensureUploadLoop()
		updatePlayerTitleFor(player.UserId)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("ActiveTitle", player:GetAttribute("ActiveTitle") or "")
		local state = PlayerDataService.Get(player)
		if typeof(state) == "table" then
			trackPlayerValue(player, state)
		end
		claimPendingRewards(player)
		ensureUploadLoop()
		updatePlayerTitleFor(player.UserId)
	end

	Players.PlayerRemoving:Connect(function(player)
		if player then
			player:SetAttribute("ActiveTitle", "")
		end
		LeaderboardService.ForceSync(player)
	end)

	-- Bind RemoteFunction handlers (retry if Remotes not yet present)
	local function doBind(remotes)
		if not remotes then
			return
		end

		local function bindFunction(name, fn)
			local inst = remotes:FindFirstChild(name)
			if inst and inst.ClassName == "RemoteFunction" then
				inst.OnServerInvoke = function(player, ...)
					local ok, result = pcall(fn, player, ...)
					if ok then
						return result
					end
					return nil
				end
			end
		end

		bindFunction("GetLeaderboard", function(player, mode)
			return LeaderboardService.GetLeaderboard(player, mode)
		end)

		bindFunction("GetLifetimeLeaderboard", function(player, force)
			return LeaderboardService.GetLifetimeLeaderboard(player, force)
		end)

		bindFunction("GetWeeklyResetTime", function(player)
			return LeaderboardService.GetWeeklyResetInfo(player)
		end)

		bindFunction("RequestSync", function(player)
			LeaderboardService.ForceSync(player)
			return true
		end)
	end

	local ok, remotes = pcall(function()
		return ReplicatedStorage:FindFirstChild("Remotes")
	end)
	if ok and remotes then
		doBind(remotes)
	else
		-- retry once shortly after startup in case EnsureRemotes runs later
		task.spawn(function()
			local success, folder = pcall(function()
				return ReplicatedStorage:WaitForChild("Remotes", 5)
			end)
			if success and folder then
				doBind(folder)
			end
		end)
	end
end

return LeaderboardService

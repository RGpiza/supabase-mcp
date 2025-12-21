local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataService = require(script.Parent.PlayerDataService)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)
local PrestigePointsService = require(script.Parent.PrestigePointsService)
local SocialGoalsConfig = require(ReplicatedStorage.Shared.SocialGoalsConfig)

local SocialGoalsService = {}

local cachedLikes = 0
local lastRefresh = 0
local backoffSeconds = SocialGoalsConfig.REFRESH_INTERVAL_SEC
local claimCooldown = {}

local function isAdmin(player)
	if not player then
		return false
	end
	for _, userId in ipairs(SocialGoalsConfig.ADMIN_USER_IDS or {}) do
		if player.UserId == userId then
			return true
		end
	end
	return false
end

local function fetchUniverseStats()
	local universeId = tostring(game.GameId)
	local url = ("https://games.roblox.com/v1/games?universeIds=%s"):format(universeId)
	local response = HttpService:GetAsync(url)
	local decoded = HttpService:JSONDecode(response)
	local data = decoded and decoded.data and decoded.data[1]
	if not data then
		return nil
	end
	local likes = tonumber(data.totalUpVotes) or 0
	return likes
end

local function safeRefresh()
	local ok, likesOrErr = pcall(fetchUniverseStats)
	if ok and typeof(likesOrErr) == "number" then
		cachedLikes = math.max(likesOrErr, 0)
		lastRefresh = os.time()
		backoffSeconds = SocialGoalsConfig.REFRESH_INTERVAL_SEC
		return true
	end
	backoffSeconds = math.min(backoffSeconds * 2, SocialGoalsConfig.MAX_BACKOFF_SEC)
	return false
end

local function grantReward(player, data, rewardType, rewardValue)
	if rewardType == "PrestigePoints" then
		data.prestigePoints = (tonumber(data.prestigePoints) or 0) + math.floor(tonumber(rewardValue) or 0)
	end
	PlayerDataService.Set(player, data)
end

local function rewardTextFor(typeName, value)
	local formatter = SocialGoalsConfig.REWARD_TEXT and SocialGoalsConfig.REWARD_TEXT[typeName]
	if formatter then
		return formatter(value)
	end
	return typeName
end

local function getStepFor(value)
	for _, step in ipairs(SocialGoalsConfig.LIKE_STEPS) do
		if value < step.stop then
			return step
		end
	end
	return SocialGoalsConfig.LIKE_STEPS[#SocialGoalsConfig.LIKE_STEPS]
end

local function getNextMilestone(after)
	if after < 1 then
		return 1
	end
	local stepDef = getStepFor(after)
	local step = stepDef.step
	local base = stepDef.start
	if after < base then
		return base
	end
	local idx = math.floor((after - base) / step) + 1
	return base + (idx * step)
end

local function getRewardForMilestone(milestone)
	if milestone <= SocialGoalsConfig.REWARD_RULES.early.max then
		return SocialGoalsConfig.REWARD_RULES.early.type, SocialGoalsConfig.REWARD_RULES.early.value
	elseif milestone <= SocialGoalsConfig.REWARD_RULES.mid.max then
		return SocialGoalsConfig.REWARD_RULES.mid.type, SocialGoalsConfig.REWARD_RULES.mid.value
	elseif milestone <= SocialGoalsConfig.REWARD_RULES.late.max then
		return SocialGoalsConfig.REWARD_RULES.late.type, SocialGoalsConfig.REWARD_RULES.late.value
	end
	local base = SocialGoalsConfig.REWARD_RULES.endgame.value
	local scaleEvery = SocialGoalsConfig.REWARD_RULES.endgame.scaleEvery or 10000
	local extra = math.floor(milestone / scaleEvery)
	return SocialGoalsConfig.REWARD_RULES.endgame.type, base + extra
end

local function countPending(likes, highestClaimed, cap)
	local count = 0
	local current = highestClaimed
	while count < cap do
		local nextMilestone = getNextMilestone(current)
		if likes < nextMilestone then
			break
		end
		count += 1
		current = nextMilestone
	end
	return count
end

function SocialGoalsService.Refresh()
	return safeRefresh()
end

function SocialGoalsService.GetState(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	if typeof(data.highestLikeMilestoneClaimed) ~= "number" then
		data.highestLikeMilestoneClaimed = 0
		PlayerDataService.Set(player, data)
	end
	if typeof(data.claimedLikes) == "table" and next(data.claimedLikes) ~= nil and data.highestLikeMilestoneClaimed == 0 then
		local maxMilestone = 0
		for key, claimed in pairs(data.claimedLikes) do
			if claimed == true and typeof(key) == "string" then
				local num = tonumber(key:match("%d+"))
				if num and num > maxMilestone then
					maxMilestone = num
				end
			end
		end
		if maxMilestone > 0 then
			data.highestLikeMilestoneClaimed = maxMilestone
			PlayerDataService.Set(player, data)
		end
	end
	local highestClaimed = math.max(data.highestLikeMilestoneClaimed or 0, 0)
	local nextMilestone = getNextMilestone(highestClaimed)
	local progress = 0
	if nextMilestone > highestClaimed then
		progress = math.clamp((cachedLikes - highestClaimed) / (nextMilestone - highestClaimed), 0, 1)
	end
	local pendingCount = countPending(cachedLikes, highestClaimed, SocialGoalsConfig.MAX_CLAIMS_PER_REQUEST)
	local rewardType, rewardValue = getRewardForMilestone(nextMilestone)
	local ampLevel = PrestigePointsService.GetUpgradeLevel(data, "pp_milestone_amp_1")
	local ampMult = 1 + (ampLevel * 0.1)
	rewardValue = (tonumber(rewardValue) or 0) * ampMult
	return {
		currentLikes = cachedLikes,
		nextMilestone = nextMilestone,
		progressToNext = progress,
		canClaim = pendingCount > 0,
		pendingCount = pendingCount,
		rewardPreview = rewardTextFor(rewardType, rewardValue),
	}
end

function SocialGoalsService.Claim(player, mode)
	if not player or typeof(mode) ~= "string" then
		return false
	end
	local now = os.clock()
	local last = claimCooldown[player] or 0
	if (now - last) < SocialGoalsConfig.CLAIM_COOLDOWN_SEC then
		return false
	end
	claimCooldown[player] = now

	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false
	end
	local highestClaimed = math.max(tonumber(data.highestLikeMilestoneClaimed) or 0, 0)
	local totalLikes = cachedLikes
	if totalLikes <= highestClaimed then
		return false
	end

	local maxClaims = SocialGoalsConfig.MAX_CLAIMS_PER_REQUEST
	local claimsToProcess = mode == "all" and maxClaims or 1
	local claimedCount = 0
	local current = highestClaimed
	local rewards = {
		PrestigePoints = 0,
	}
	local ampLevel = PrestigePointsService.GetUpgradeLevel(data, "pp_milestone_amp_1")
	local ampMult = 1 + (ampLevel * 0.1)

	while claimedCount < claimsToProcess do
		local nextMilestone = getNextMilestone(current)
		if totalLikes < nextMilestone then
			break
		end
		local rewardType, rewardValue = getRewardForMilestone(nextMilestone)
		local adjusted = (tonumber(rewardValue) or 0) * ampMult
		rewards[rewardType] = (rewards[rewardType] or 0) + adjusted
		current = nextMilestone
		claimedCount += 1
	end

	if claimedCount <= 0 then
		return false
	end

	data.highestLikeMilestoneClaimed = current
	if rewards.PrestigePoints > 0 then
		data.prestigePoints = (tonumber(data.prestigePoints) or 0) + math.floor(rewards.PrestigePoints)
	end
	PlayerDataService.Set(player, data)
	AnalyticsTrackerService.LogCustomCounter(player, "GlobalLikeRewardClaimed", {
		claims = claimedCount,
	})
	return true
end

function SocialGoalsService.ForceRefresh(player)
	if not isAdmin(player) then
		return false
	end
	return safeRefresh()
end

function SocialGoalsService.Start()
	task.spawn(function()
		while true do
			local now = os.time()
			if (now - lastRefresh) >= backoffSeconds then
				safeRefresh()
			end
			task.wait(5)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	claimCooldown[player] = nil
end)

return SocialGoalsService

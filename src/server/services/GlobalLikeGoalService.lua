local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)
local CommunityRewardsConfig = require(ReplicatedStorage.Shared.CommunityRewardsConfig)

local GlobalLikeGoalService = {}

local function getMilestones()
	return CommunityRewardsConfig.LIKE_MILESTONES or {}
end

local function getGlobalLikes()
	return tonumber(CommunityRewardsConfig.GLOBAL_LIKE_COUNT) or 0
end

local function getClaimTable(data)
	if typeof(data.globalLikeClaims) ~= "table" then
		data.globalLikeClaims = {}
	end
	return data.globalLikeClaims
end

local function grantReward(player, data, milestone)
	local rewardType = milestone.rewardType
	local rewardValue = milestone.rewardValue
	if rewardType == "PrestigePoints" then
		data.prestigePoints = (tonumber(data.prestigePoints) or 0) + math.floor(tonumber(rewardValue) or 0)
	elseif rewardType == "ProductionBonus" then
		local current = tonumber(data.productionBonus) or 0
		data.productionBonus = current + (tonumber(rewardValue) or 0)
	elseif rewardType == "AutomationMultiplier" then
		local current = tonumber(data.automationMultiplier) or 0
		data.automationMultiplier = current + (tonumber(rewardValue) or 0)
	end
	PlayerDataService.Set(player, data)
	AnalyticsTrackerService.LogCustomCounter(player, "GlobalLikeRewardClaimed", {
		milestoneId = milestone.id,
		rewardType = rewardType,
	})
end

function GlobalLikeGoalService.GetState(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	local likes = getGlobalLikes()
	local claims = getClaimTable(data)
	local entries = {}
	for _, milestone in ipairs(getMilestones()) do
		entries[#entries + 1] = {
			id = milestone.id,
			goalLikes = milestone.goalLikes,
			rewardType = milestone.rewardType,
			rewardValue = milestone.rewardValue,
			unlocked = likes >= (milestone.goalLikes or 0),
			claimed = claims[milestone.id] == true,
		}
	end
	return {
		globalLikes = likes,
		milestones = entries,
	}
end

function GlobalLikeGoalService.Claim(player, milestoneId)
	if not player or typeof(milestoneId) ~= "string" then
		return false
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false
	end
	local likes = getGlobalLikes()
	local claims = getClaimTable(data)
	for _, milestone in ipairs(getMilestones()) do
		if milestone.id == milestoneId then
			if likes < (milestone.goalLikes or 0) then
				return false
			end
			if claims[milestoneId] == true then
				return false
			end
			claims[milestoneId] = true
			grantReward(player, data, milestone)
			return true
		end
	end
	return false
end

return GlobalLikeGoalService

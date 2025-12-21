local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)
local CommunityRewardsConfig = require(ReplicatedStorage.Shared.CommunityRewardsConfig)

local FavoriteRewardService = {}

local function formatRewardText(rewardType, rewardValue)
	if rewardType == "PrestigePoints" then
		return string.format("+%d Prestige Points", math.floor(tonumber(rewardValue) or 0))
	elseif rewardType == "ProductionBonus" then
		return string.format("+%d%% Production", math.floor((tonumber(rewardValue) or 0) * 100))
	elseif rewardType == "AutomationMultiplier" then
		return string.format("-%d%% Auto Tick", math.floor((tonumber(rewardValue) or 0) * 100))
	end
	return "Reward"
end

local function grantReward(player, data)
	local reward = CommunityRewardsConfig.FAVORITE_REWARD or {}
	local rewardType = reward.rewardType
	local rewardValue = reward.rewardValue
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
	AnalyticsTrackerService.LogCustomCounter(player, "FavoriteRewardClaimed", {
		rewardType = rewardType,
	})
end

function FavoriteRewardService.GetState(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	local reward = CommunityRewardsConfig.FAVORITE_REWARD or {}
	local rewardType = reward.rewardType
	local rewardValue = reward.rewardValue
	return {
		claimed = data.hasClaimedFavoriteReward == true,
		rewardType = rewardType,
		rewardValue = rewardValue,
		rewardText = formatRewardText(rewardType, rewardValue),
	}
end

function FavoriteRewardService.Claim(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false
	end
	if data.hasClaimedFavoriteReward == true then
		return false
	end
	data.hasClaimedFavoriteReward = true
	grantReward(player, data)
	return true
end

return FavoriteRewardService

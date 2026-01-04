local CommunityRewardsConfig = {}

CommunityRewardsConfig.GLOBAL_LIKE_COUNT = 0

CommunityRewardsConfig.LIKE_MILESTONES = {
	{
		id = "likes_100",
		goalLikes = 100,
		rewardType = "PrestigePoints",
		rewardValue = 1,
	},
	{
		id = "likes_500",
		goalLikes = 500,
		rewardType = "PrestigePoints",
		rewardValue = 5,
	},
	{
		id = "likes_1000",
		goalLikes = 1000,
		rewardType = "ProductionBonus",
		rewardValue = 0.05,
	},
	{
		id = "likes_5000",
		goalLikes = 5000,
		rewardType = "AutomationMultiplier",
		rewardValue = 0.1,
	},
}

CommunityRewardsConfig.FAVORITE_REWARD = {
	rewardType = "PrestigePoints",
	rewardValue = 2,
}

return CommunityRewardsConfig

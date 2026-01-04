local SocialGoalsConfig = {}

SocialGoalsConfig.ADMIN_USER_IDS = {}
SocialGoalsConfig.REFRESH_INTERVAL_SEC = 600
SocialGoalsConfig.MAX_BACKOFF_SEC = 3600
SocialGoalsConfig.DEBUG = false
SocialGoalsConfig.CLAIM_COOLDOWN_SEC = 1
SocialGoalsConfig.MAX_CLAIMS_PER_REQUEST = 200

SocialGoalsConfig.LIKE_STEPS = {
	{ start = 1, stop = 100, step = 1 },
	{ start = 100, stop = 500, step = 5 },
	{ start = 500, stop = 2000, step = 25 },
	{ start = 2000, stop = 10000, step = 100 },
	{ start = 10000, stop = math.huge, step = 500 },
}

SocialGoalsConfig.REWARD_RULES = {
	early = { max = 500, type = "PrestigePoints", value = 1 },
	mid = { max = 2000, type = "PrestigePoints", value = 1 },
	late = { max = 10000, type = "PrestigePoints", value = 2 },
	endgame = { max = math.huge, type = "PrestigePoints", value = 3, scaleEvery = 10000 },
}

SocialGoalsConfig.REWARD_TEXT = {
	PrestigePoints = function(value)
		return string.format("+%d Prestige Points", value)
	end,
}

return SocialGoalsConfig

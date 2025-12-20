local RemoteNames = {}

RemoteNames.Required = {
	requestSync = "RequestSync",
	purchaseUpgrade = "PurchaseUpgrade",
	prestige = "RequestPrestige",
	prestigePreview = "PrestigePreviewUpdate",
	requestPrestigePreview = "RequestPrestigePreview",
	sessionBonus = "SessionBonusUpdate",
	globalAnnouncement = "GlobalAnnouncement",
	globalStats = "GlobalStatsUpdate",
	getGlobalStats = "GetGlobalStats",
	serverPower = "ServerPowerUpdate",
	systemNotification = "SystemNotification",
	leaderboard = "GetLeaderboard",
	lifetimeLeaderboard = "GetLifetimeLeaderboard",
	weeklyReset = "GetWeeklyResetTime",
	setAutoBuy = "SetAutoBuy",
	autoBuyState = "AutoBuyState",
}

RemoteNames.Optional = {
	loadingProgress = "LoadingProgress",
	storeAnalytics = "StoreAnalyticsEvent",
	boostsUpdated = "BoostsUpdated",
	offlinePreview = "OfflineEarningsPreview",
	autoBuyPresetApply = "AutoBuyPresetApply",
	autoBuyPresetSave = "AutoBuyPresetSave",
	autoBuyPresetState = "AutoBuyPresetState",
	requestAutoBuyPresets = "RequestAutoBuyPresets",
	autoBuyPresetUnlockPrompt = "AutoBuyPresetUnlockPrompt",
	autoBuyAutoSwitchSettings = "AutoBuyAutoSwitchSettings",
}

return RemoteNames

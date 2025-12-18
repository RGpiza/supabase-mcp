local Config = {}

Config.PresetIconDefinitions = {
	{ id = "auto_cpu", label = "CPU" },
	{ id = "auto_ram", label = "RAM" },
	{ id = "auto_storage", label = "STO" },
}

Config.Purchase = {
	debounce = 0.2,
	longPressDuration = 0.5,
	activationSuppress = 0.1,
}

Config.AutoBuyBranches = {
	{ id = "CPU", label = "AUTO CPU" },
	{ id = "RAM", label = "AUTO RAM" },
	{ id = "STORAGE", label = "AUTO STORAGE" },
}

Config.HapticCooldown = 0.2

Config.WeeklyRewardDefinitions = {
	{ tier = "gold", label = "Rank 1", detail = "Gold Name Color (7 days)" },
	{ tier = "silver", label = "Top 10", detail = "Silver Name Color (7 days)" },
	{ tier = "bronze", label = "Top 50", detail = "Bronze Badge (7 days)" },
}

Config.WeeklyRewardHighlight = {
	gold = Color3.fromRGB(80, 60, 30),
	silver = Color3.fromRGB(60, 70, 90),
	bronze = Color3.fromRGB(65, 50, 35),
}

Config.WeeklyRewardAccent = {
	gold = Color3.fromRGB(255, 225, 160),
	silver = Color3.fromRGB(200, 225, 255),
	bronze = Color3.fromRGB(255, 210, 170),
}

return Config

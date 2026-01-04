local UpgradeConfig = {}

local function buildEffect(flatPerLevel, multiplierPerLevel, storageTierValue)
	return function(level)
		local flat = 0
		local mult = 1
		local tier = 0

		if flatPerLevel then
			flat = flatPerLevel * math.max(level, 0)
		end

		if multiplierPerLevel then
			mult = 1 + (multiplierPerLevel * math.max(level, 0))
		end

		if storageTierValue then
			tier = level >= 1 and storageTierValue or 0
		end

		return {
			flatDps = flat,
			multiplier = mult,
			storageTier = tier,
		}
	end
end

UpgradeConfig.Definitions = {
	{
		id = "cpu_1",
		branch = "CPU",
		name = "CPU Mk.I",
		description = "Entry-level processors that add +1 Data/sec per level.",
		baseCost = 10,
		costScale = 1.35,
		maxLevel = 25,
		effectType = "add",
		target = "dps",
		value = 1,
		effect = buildEffect(1, nil, nil),
	},
	{
		id = "cpu_2",
		branch = "CPU",
		name = "CPU Mk.II",
		description = "Improved cores adding +5 Data/sec per level.",
		baseCost = 250,
		costScale = 1.45,
		maxLevel = 20,
		effectType = "add",
		target = "dps",
		value = 5,
		effect = buildEffect(5, nil, nil),
	},
	{
		id = "cpu_3",
		branch = "CPU",
		name = "CPU Mk.III",
		description = "Optimized silicon delivering +20 Data/sec per level.",
		baseCost = 2_500,
		costScale = 1.6,
		maxLevel = 15,
		effectType = "add",
		target = "dps",
		value = 20,
		effect = buildEffect(20, nil, nil),
	},
	{
		id = "ram_1",
		branch = "RAM",
		name = "RAM Matrix Mk.I",
		description = "Adds +5% global multiplier per level.",
		baseCost = 100,
		costScale = 1.4,
		maxLevel = 20,
		effectType = "mul",
		target = "dps",
		value = 0.05,
		effect = buildEffect(nil, 0.05, nil),
	},
	{
		id = "ram_2",
		branch = "RAM",
		name = "RAM Matrix Mk.II",
		description = "Adds +15% global multiplier per level.",
		baseCost = 1_000,
		costScale = 1.55,
		maxLevel = 15,
		effectType = "mul",
		target = "dps",
		value = 0.15,
		effect = buildEffect(nil, 0.15, nil),
	},
	{
		id = "sto_1",
		branch = "STORAGE",
		name = "Storage Tier I",
		description = "Unlocks Storage Tier 1 progression and boosts Data/sec by 1.5x.",
		baseCost = 5_000,
		costScale = 1.0,
		maxLevel = 1,
		effectType = "mul",
		target = "dps",
		value = 0.5,
		effect = buildEffect(nil, 0.5, 1),
	},
	{
		id = "sto_2",
		branch = "STORAGE",
		name = "Storage Tier II",
		description = "Unlocks Storage Tier 2 progression and boosts Data/sec by 2x.",
		baseCost = 50_000,
		costScale = 1.0,
		maxLevel = 1,
		effectType = "mul",
		target = "dps",
		value = 1.0,
		effect = buildEffect(nil, 1.0, 2),
	},
	{
		id = "sto_3",
		branch = "STORAGE",
		name = "Storage Tier III",
		description = "Unlocks Storage Tier 3 progression and boosts Data/sec by 3x.",
		baseCost = 500_000,
		costScale = 1.0,
		maxLevel = 1,
		effectType = "mul",
		target = "dps",
		value = 2.0,
		effect = buildEffect(nil, 2.0, 3),
	},
}

UpgradeConfig.ById = {}
UpgradeConfig.ByBranch = {}

for _, upgrade in ipairs(UpgradeConfig.Definitions) do
	UpgradeConfig.ById[upgrade.id] = upgrade

	if not UpgradeConfig.ByBranch[upgrade.branch] then
		UpgradeConfig.ByBranch[upgrade.branch] = {}
	end

	table.insert(UpgradeConfig.ByBranch[upgrade.branch], upgrade)
end

function UpgradeConfig.getUpgradeById(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end

	return UpgradeConfig.ById[upgradeId]
end

function UpgradeConfig.getUpgradeCost(upgradeId, currentLevel)
	local upgrade = UpgradeConfig.getUpgradeById(upgradeId)
	if not upgrade then
		return nil
	end

	local nextLevel = math.max((currentLevel or 0) + 1, 1)
	local exponent = nextLevel - 1
	return upgrade.baseCost * (upgrade.costScale ^ exponent)
end

function UpgradeConfig.GetUpgradesByBranch(branch)
	if typeof(branch) ~= "string" then
		return {}
	end

	return UpgradeConfig.ByBranch[branch] or {}
end

function UpgradeConfig.GetStorageTier(upgradesTable)
	if typeof(upgradesTable) ~= "table" then
		return 0
	end

	local highestTier = 0

	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("STORAGE")) do
		local level = upgradesTable[upgrade.id]
		if typeof(level) == "number" and level >= 1 then
			local effect = upgrade.effect(level)
			if effect and typeof(effect.storageTier) == "number" then
				highestTier = math.max(highestTier, effect.storageTier)
			end
		end
	end

	return highestTier
end

return UpgradeConfig

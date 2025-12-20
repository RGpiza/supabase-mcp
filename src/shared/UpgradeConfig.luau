local UpgradeConfig = {}

type UpgradeDefinition = {
	id: string,
	branch: string,
	name: string,
	description: string,
	baseCost: number,
	costScale: number,
	maxLevel: number,
	requires: {
		storageTier: number?,
		requiresUpgradeId: string?,
	}?,
	effect: (level: number) -> {
		flatDps: number,
		multiplier: number,
		storageTier: number,
	},
}

local function buildEffect(flatPerLevel, multiplierPerLevel, storageTierValue)
	return function(level: number)
		local clampedLevel = math.max(level, 0)

		local flat = flatPerLevel and (flatPerLevel * clampedLevel) or 0
		local multiplier = multiplierPerLevel and (multiplierPerLevel * clampedLevel) or 0
		local storageTier = (storageTierValue and clampedLevel >= 1) and storageTierValue or 0

		return {
			flatDps = flat,
			multiplier = multiplier,
			storageTier = storageTier,
		}
	end
end

local allUpgrades: { UpgradeDefinition } = {
	-- CPU Branch
	{
		id = "cpu_1",
		branch = "CPU",
		name = "Clock Boost",
		description = "+1 Data/sec per level.",
		baseCost = 5,
		costScale = 1.25,
		maxLevel = 50,
		effect = buildEffect(1, nil, nil),
	},
	{
		id = "cpu_2",
		branch = "CPU",
		name = "Core Threads",
		description = "+5 Data/sec per level.",
		baseCost = 150,
		costScale = 1.35,
		maxLevel = 35,
		requires = {
			storageTier = 2,
		},
		effect = buildEffect(5, nil, nil),
	},
	{
		id = "cpu_3",
		branch = "CPU",
		name = "Overclock Mode",
		description = "+20 Data/sec per level.",
		baseCost = 2_000,
		costScale = 1.45,
		maxLevel = 25,
		requires = {
			storageTier = 3,
		},
		effect = buildEffect(20, nil, nil),
	},

	-- RAM Branch
	{
		id = "ram_1",
		branch = "RAM",
		name = "Cache Boost",
		description = "+10% global per level.",
		baseCost = 50,
		costScale = 1.3,
		maxLevel = 30,
		effect = buildEffect(nil, 0.10, nil),
	},
	{
		id = "ram_2",
		branch = "RAM",
		name = "Memory Optimization",
		description = "+25% global per level.",
		baseCost = 800,
		costScale = 1.4,
		maxLevel = 20,
		requires = {
			storageTier = 2,
		},
		effect = buildEffect(nil, 0.25, nil),
	},

	-- STORAGE Branch
	{
		id = "sto_1",
		branch = "STORAGE",
		name = "Disk Partition",
		description = "Unlock Storage Tier 1.",
		baseCost = 2_500,
		costScale = 1.0,
		maxLevel = 1,
		effect = buildEffect(nil, nil, 1),
	},
	{
		id = "sto_2",
		branch = "STORAGE",
		name = "SSD Upgrade",
		description = "Unlock Storage Tier 2.",
		baseCost = 25_000,
		costScale = 1.0,
		maxLevel = 1,
		requires = {
			requiresUpgradeId = "sto_1",
		},
		effect = buildEffect(nil, nil, 2),
	},
	{
		id = "sto_3",
		branch = "STORAGE",
		name = "NVMe Array",
		description = "Unlock Storage Tier 3 (Prestige).",
		baseCost = 250_000,
		costScale = 1.0,
		maxLevel = 1,
		requires = {
			requiresUpgradeId = "sto_2",
		},
		effect = buildEffect(nil, nil, 3),
	},
}

local upgradesById = {}
local upgradesByBranch = {}

for _, upgrade in ipairs(allUpgrades) do
	upgradesById[upgrade.id] = upgrade
	upgradesByBranch[upgrade.branch] = upgradesByBranch[upgrade.branch] or {}
	table.insert(upgradesByBranch[upgrade.branch], upgrade)
end

local function sanitizeUpgradesTable(upgradesTable)
	if typeof(upgradesTable) ~= "table" then
		return {}
	end

	return upgradesTable
end

function UpgradeConfig.GetAllUpgrades()
	return allUpgrades
end

function UpgradeConfig.GetUpgradesByBranch(branch)
	if typeof(branch) ~= "string" then
		return {}
	end

	return upgradesByBranch[branch] or {}
end

function UpgradeConfig.GetUpgradeById(id)
	if typeof(id) ~= "string" then
		return nil
	end

	return upgradesById[id]
end

function UpgradeConfig.GetCost(upgradeId, currentLevel)
	local def = UpgradeConfig.GetUpgradeById(upgradeId)
	if not def then
		return nil
	end

	local nextLevel = math.max((currentLevel or 0) + 1, 1)
	return def.baseCost * (def.costScale ^ (nextLevel - 1))
end

function UpgradeConfig.GetLevel(upgradesTable, upgradeId)
	local sanitized = sanitizeUpgradesTable(upgradesTable)
	local level = sanitized[upgradeId]
	if typeof(level) ~= "number" then
		return 0
	end

	return math.max(level, 0)
end

function UpgradeConfig.IsMaxed(upgradesTable, upgradeId)
	local def = UpgradeConfig.GetUpgradeById(upgradeId)
	if not def then
		return false
	end

	local level = UpgradeConfig.GetLevel(upgradesTable, upgradeId)
	return level >= def.maxLevel
end

function UpgradeConfig.GetStorageTier(upgradesTable)
	local sanitized = sanitizeUpgradesTable(upgradesTable)
	local highest = 0

	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("STORAGE")) do
		local level = sanitized[upgrade.id]
		if typeof(level) == "number" and level >= 1 then
			local effect = upgrade.effect(level)
			if effect.storageTier then
				highest = math.max(highest, effect.storageTier)
			end
		end
	end

	return highest
end

function UpgradeConfig.MeetsRequirements(upgradesTable, upgradeId)
	local def = UpgradeConfig.GetUpgradeById(upgradeId)
	if not def then
		return false
	end

	local requirements = def.requires
	if not requirements then
		return true
	end

	local sanitized = sanitizeUpgradesTable(upgradesTable)

	if requirements.storageTier then
		local tier = UpgradeConfig.GetStorageTier(sanitized)
		if tier < requirements.storageTier then
			return false
		end
	end

	if requirements.requiresUpgradeId then
		local requiredLevel = UpgradeConfig.GetLevel(sanitized, requirements.requiresUpgradeId)
		if requiredLevel < 1 then
			return false
		end
	end

	return true
end

return UpgradeConfig

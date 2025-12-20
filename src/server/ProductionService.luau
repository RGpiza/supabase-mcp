local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
<<<<<<< HEAD
local GroupBonusService = require(script.Parent.GroupBonusService)
local PremiumBonusService = require(script.Parent.PremiumBonusService)
local BoostManager = require(script.Parent.BoostManager)
=======
>>>>>>> parent of 0324c3d (Add automation, group bonus, and milestone services)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

local ProductionService = {}

local cpuUpgrades = UpgradeConfig.GetUpgradesByBranch("CPU")
local ramUpgrades = UpgradeConfig.GetUpgradesByBranch("RAM")

local BASE_DPS = 1
local PRESTIGE_BONUS = 0.1

local function getPlayerUpgrades(playerData)
	if typeof(playerData) ~= "table" then
		return nil
	end

	if typeof(playerData.upgrades) == "table" then
		return playerData.upgrades
	end

	return nil
end

local function getLevel(upgrades, upgradeId)
	if not upgrades then
		return 0
	end

	local level = upgrades[upgradeId]
	if typeof(level) ~= "number" then
		return 0
	end

	return math.max(level, 0)
end

local function accumulateCpuBonus(upgrades)
	local total = 0

	for _, upgrade in ipairs(cpuUpgrades) do
		local level = getLevel(upgrades, upgrade.id)
		if level > 0 then
			local effect = upgrade.effect(level)
			if effect and typeof(effect.flatDps) == "number" then
				total += effect.flatDps
			end
		end
	end

	return total
end

local function normalizeMultiplier(value)
	if typeof(value) ~= "number" then
		return 0
	end

	if value >= 1 then
		return value - 1
	end

	return value
end

local function accumulateRamMultiplier(upgrades)
	local totalMultiplier = 1

	for _, upgrade in ipairs(ramUpgrades) do
		local level = getLevel(upgrades, upgrade.id)
		if level > 0 then
			local effect = upgrade.effect(level)
			local bonus = normalizeMultiplier(effect and effect.multiplier)
			totalMultiplier *= (1 + bonus)
		end
	end

	return totalMultiplier
end

local function getPrestigeMultiplier(playerData)
	local corePower = typeof(playerData.corePower) == "number" and playerData.corePower or 0
	if corePower <= 0 then
		return 1
	end

	return 1 + (corePower * PRESTIGE_BONUS)
end

function ProductionService.GetBaseDataPerSecond(player)
	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return BASE_DPS
	end

	local upgrades = getPlayerUpgrades(playerData)

	local totalFlat = accumulateCpuBonus(upgrades)
	local totalMultiplier = accumulateRamMultiplier(upgrades)
	local prestigeMultiplier = getPrestigeMultiplier(playerData)

	return (BASE_DPS + totalFlat) * totalMultiplier * prestigeMultiplier
end

function ProductionService.GetDataPerSecond(player)
	local baseProduction = ProductionService.GetBaseDataPerSecond(player)
	local boostMultiplier = BoostManager.GetMultiplier(player)
	return baseProduction * boostMultiplier
end

return ProductionService

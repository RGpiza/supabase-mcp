local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local MonetizationService = require(script.Parent.MonetizationService)

local ProductionService = {}

local BASE_DPS = 1
local PRESTIGE_BONUS = 0.1

local function getLevel(upgrades, upgradeId)
	if typeof(upgrades) ~= "table" then
		return 0
	end
	local level = upgrades[upgradeId]
	if typeof(level) ~= "number" then
		return 0
	end
	return math.max(level, 0)
end

local function applyUpgradeEffects(upgrades)
	local add = 0
	local mul = 1

	for _, upgrade in ipairs(UpgradeConfig.Definitions) do
		local level = getLevel(upgrades, upgrade.id)
		if level > 0 then
			if upgrade.effectType == "add" and upgrade.target == "dps" then
				add += (upgrade.value or 0) * level
			elseif upgrade.effectType == "mul" and upgrade.target == "dps" then
				mul *= (1 + (upgrade.value or 0) * level)
			end
		end
	end

	return add, mul
end

local function getPrestigeMultiplier(playerData)
	local corePower = typeof(playerData.corePower) == "number" and playerData.corePower or 0
	if corePower <= 0 then
		return 1
	end
	return 1 + (corePower * PRESTIGE_BONUS)
end

function ProductionService.GetSystemStats(upgrades)
	local cpuTotal = 0
	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("CPU")) do
		cpuTotal += getLevel(upgrades, upgrade.id)
	end

	local ramTotal = 0
	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("RAM")) do
		ramTotal += getLevel(upgrades, upgrade.id)
	end

	local storageTier = UpgradeConfig.GetStorageTier(upgrades)

	return {
		cpu = cpuTotal,
		ram = ramTotal,
		storage = storageTier,
	}
end

function ProductionService.ComputeFinalProduction(playerData)
	if typeof(playerData) ~= "table" then
		return {
			baseDps = BASE_DPS,
			finalDps = BASE_DPS,
			breakdown = {
				additive = 0,
				upgradeMul = 1,
				prestigeMul = 1,
				passMul = 1,
				boostMul = 1,
			},
		}
	end

	local upgrades = typeof(playerData.upgrades) == "table" and playerData.upgrades or {}
	local add, upgradeMul = applyUpgradeEffects(upgrades)
	local prestigeMul = getPrestigeMultiplier(playerData)
	local passMul = playerData.owns2xData and 2 or 1
	local boostMul = MonetizationService.IsBoostActive(playerData) and 2 or 1

	local base = BASE_DPS + add
	local final = base * upgradeMul * prestigeMul * passMul * boostMul

	local breakdown = {
		additive = add,
		upgradeMul = upgradeMul,
		prestigeMul = prestigeMul,
		passMul = passMul,
		boostMul = boostMul,
	}

	print(string.format("[Production] base=%0.3f add=%0.3f mulU=%0.3f mulP=%0.3f pass=%0.3f boost=%0.3f final=%0.3f", base, add, upgradeMul, prestigeMul, passMul, boostMul, final))

	return {
		baseDps = base,
		finalDps = final,
		breakdown = breakdown,
	}
end

function ProductionService.GetDataPerSecond(player)
	local playerData = PlayerDataService.Get(player)
	local result = ProductionService.ComputeFinalProduction(playerData)
	return result.finalDps or BASE_DPS
end

return ProductionService

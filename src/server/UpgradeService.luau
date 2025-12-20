local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

local UpgradeService = {}

local function getUpgradeDefinition(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end

	return UpgradeConfig.ById[upgradeId]
end

local function resolveUpgradeLevel(upgrades, upgradeId)
	if typeof(upgrades) ~= "table" then
		return 0
	end

	local level = upgrades[upgradeId]
	if typeof(level) ~= "number" then
		return 0
	end

	return math.max(level, 0)
end

local function validateUpgradeCost(upgrade, upgradeId, currentLevel)
	if upgrade.maxLevel and currentLevel >= upgrade.maxLevel then
		return false
	end

	local cost = UpgradeConfig.getUpgradeCost(upgradeId, currentLevel)
	if typeof(cost) ~= "number" then
		return false
	end

	return true, cost
end

local function cloneState(playerData)
	if typeof(playerData) ~= "table" then
		return nil
	end

	return table.clone(playerData)
end

local function getCurrency(playerData)
	if typeof(playerData.data) ~= "number" then
		return 0
	end

	return playerData.data
end

local function ensureUpgradeTable(playerData)
	if typeof(playerData.upgrades) ~= "table" then
		playerData.upgrades = {}
	end

	return playerData.upgrades
end

function UpgradeService.CanBuy(player, upgradeId)
	local upgrade = getUpgradeDefinition(upgradeId)
	if not upgrade then
		return false, nil
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return false, nil
	end

	local upgrades = ensureUpgradeTable(playerData)
	local currentLevel = resolveUpgradeLevel(upgrades, upgradeId)

	local storageTier = UpgradeConfig.GetStorageTier(upgrades)
	if upgrade.id == "sto_2" and resolveUpgradeLevel(upgrades, "sto_1") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "sto_3" and resolveUpgradeLevel(upgrades, "sto_2") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_2" and storageTier < 2 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_3" and storageTier < 3 then
		return false, cloneState(playerData)
	elseif upgrade.id == "ram_2" and storageTier < 2 then
		return false, cloneState(playerData)
	end

	local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel)
	if not canLevel then
		return false, cloneState(playerData)
	end

	local currency = getCurrency(playerData)
	if currency < cost then
		return false, cloneState(playerData)
	end

	return true, cloneState(playerData)
end

function UpgradeService.Buy(player, upgradeId)
	local upgrade = getUpgradeDefinition(upgradeId)
	if not upgrade then
		return false, nil
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return false, nil
	end

	local upgrades = ensureUpgradeTable(playerData)
	local currentLevel = resolveUpgradeLevel(upgrades, upgradeId)
	local nextLevel = currentLevel + 1

	local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel)
	if not canLevel then
		return false, cloneState(playerData)
	end

	local storageTier = UpgradeConfig.GetStorageTier(upgrades)
	if upgrade.id == "sto_2" and resolveUpgradeLevel(upgrades, "sto_1") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "sto_3" and resolveUpgradeLevel(upgrades, "sto_2") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_2" and storageTier < 2 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_3" and storageTier < 3 then
		return false, cloneState(playerData)
	elseif upgrade.id == "ram_2" and storageTier < 2 then
		return false, cloneState(playerData)
	end

	local currency = getCurrency(playerData)
	if currency < cost then
		return false, cloneState(playerData)
	end

	playerData.data = currency - cost
	upgrades[upgradeId] = nextLevel

	PlayerDataService.Set(player, playerData)

	return true, cloneState(playerData)
end

return UpgradeService

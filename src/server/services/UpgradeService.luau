local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local PrestigePointsService = require(script.Parent.PrestigePointsService)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)

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

local function validateUpgradeCost(upgrade, upgradeId, currentLevel, playerData)
	if upgrade.maxLevel and currentLevel >= upgrade.maxLevel then
		return false
	end

	local cost = UpgradeConfig.getUpgradeCost(upgradeId, currentLevel)
	if typeof(cost) ~= "number" then
		return false
	end
	if playerData then
		local costLevel = PrestigePointsService.GetUpgradeLevel(playerData, "costReduction")
		if costLevel > 0 then
			local discount = math.clamp(costLevel * 0.02, 0, 0.3)
			cost = cost * (1 - discount)
		end
		local smoothLevel = PrestigePointsService.GetUpgradeLevel(playerData, "pp_endgame_boost_1")
		if smoothLevel > 0 then
			local smoothDiscount = math.clamp(smoothLevel * 0.01, 0, 0.05)
			cost = cost * (1 - smoothDiscount)
		end
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

	local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel, playerData)
	if not canLevel then
		return false, cloneState(playerData)
	end

	local currency = getCurrency(playerData)
	if currency < cost then
		return false, cloneState(playerData)
	end

	return true, cloneState(playerData)
end

function UpgradeService.Buy(player, upgradeId, count)
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
	local purchases = math.clamp(tonumber(count) or 1, 1, 100)
	local bought = 0
	local spend = 0

	while bought < purchases do
		local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel, playerData)
		if not canLevel then
			break
		end

		local storageTier = UpgradeConfig.GetStorageTier(upgrades)
		if upgrade.id == "sto_2" and resolveUpgradeLevel(upgrades, "sto_1") <= 0 then
			break
		elseif upgrade.id == "sto_3" and resolveUpgradeLevel(upgrades, "sto_2") <= 0 then
			break
		elseif upgrade.id == "cpu_2" and storageTier < 2 then
			break
		elseif upgrade.id == "cpu_3" and storageTier < 3 then
			break
		elseif upgrade.id == "ram_2" and storageTier < 2 then
			break
		end

		local currency = getCurrency(playerData)
		if currency < cost then
			break
		end

		playerData.data = currency - cost
		currentLevel += 1
		upgrades[upgradeId] = currentLevel
		bought += 1
		spend += cost
	end

	if bought <= 0 then
		return false, cloneState(playerData)
	end

	PlayerDataService.Set(player, playerData)
	AnalyticsTrackerService.LogEconomySink(
		player,
		"Data",
		spend,
		playerData.data,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		upgradeId,
		{
			category = upgrade.branch,
			upgradeLevel = currentLevel,
		}
	)
	AnalyticsTrackerService.LogCustomValue(player, "UpgradePurchased", spend, {
		upgradeId = upgradeId,
		category = upgrade.branch,
	})
	AnalyticsTrackerService.TrackFirstUpgrade(player)

	return true, cloneState(playerData)
end

function UpgradeService.AutoBuyBest(player, branch)
	if typeof(branch) ~= "string" then
		return false
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return false
	end

	local upgrades = ensureUpgradeTable(playerData)
	local storageTier = UpgradeConfig.GetStorageTier(upgrades)
	local currency = getCurrency(playerData)
	local autoEffLevel = PrestigePointsService.GetUpgradeLevel(playerData, "pp_auto_eff_1")

	local bestUpgradeId = nil
	local bestCost = nil

	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch(branch)) do
		local upgradeId = upgrade.id
		local currentLevel = resolveUpgradeLevel(upgrades, upgradeId)

		if upgrade.maxLevel and currentLevel >= upgrade.maxLevel then
			continue
		end

		if upgrade.id == "sto_2" and resolveUpgradeLevel(upgrades, "sto_1") <= 0 then
			continue
		elseif upgrade.id == "sto_3" and resolveUpgradeLevel(upgrades, "sto_2") <= 0 then
			continue
		elseif upgrade.id == "cpu_2" and storageTier < 2 then
			continue
		elseif upgrade.id == "cpu_3" and storageTier < 3 then
			continue
		elseif upgrade.id == "ram_2" and storageTier < 2 then
			continue
		end

		local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel, playerData)
		if not canLevel then
			continue
		end
		if currency < cost then
			continue
		end

		if autoEffLevel > 0 then
			if not bestCost or cost > bestCost then
				bestCost = cost
				bestUpgradeId = upgradeId
			end
		elseif not bestCost or cost < bestCost then
			bestCost = cost
			bestUpgradeId = upgradeId
		end
	end

	if not bestUpgradeId or not bestCost then
		return false
	end

	playerData.data = currency - bestCost
	upgrades[bestUpgradeId] = resolveUpgradeLevel(upgrades, bestUpgradeId) + 1
	PlayerDataService.Set(player, playerData)
	AnalyticsTrackerService.LogEconomySink(
		player,
		"Data",
		bestCost,
		playerData.data,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		bestUpgradeId,
		{
			category = branch,
			upgradeLevel = upgrades[bestUpgradeId],
			auto = true,
		}
	)
	AnalyticsTrackerService.LogCustomValue(player, "UpgradePurchased", bestCost, {
		upgradeId = bestUpgradeId,
		category = branch,
		auto = true,
	})
	AnalyticsTrackerService.TrackFirstUpgrade(player)

	return true, cloneState(playerData)
end

return UpgradeService

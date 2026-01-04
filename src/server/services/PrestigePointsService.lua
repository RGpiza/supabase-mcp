local PrestigePointsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local PrestigeUpgradesConfig = require(ReplicatedStorage.Shared.PrestigeUpgradesConfig)

local UPGRADES = PrestigeUpgradesConfig.Definitions

local function getUpgradeDef(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end
	return UPGRADES[upgradeId]
end

local function getCost(def, level)
	local base = def.cost or 1
	local scale = def.costScale or 1
	return math.floor(base * (scale ^ level))
end

function PrestigePointsService.Purchase(player, upgradeId)
	local def = getUpgradeDef(upgradeId)
	if not def then
		return false
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false
	end
	if typeof(data.prestigeUpgrades) ~= "table" then
		data.prestigeUpgrades = {}
	end
	local current = tonumber(data.prestigeUpgrades[upgradeId]) or 0
	if def.maxLevel and current >= def.maxLevel then
		return false
	end
	
	-- Check unlock conditions
	if upgradeId == "pp_auto_unlock_2" then
		local bypassLevel = tonumber(data.prestigeUpgrades.pp_auto_bypass_1) or 0
		if bypassLevel < 1 then
			return false
		end
	end
	
	if upgradeId == "pp_auto_speed_2" then
		local speedLevel = tonumber(data.prestigeUpgrades.pp_auto_speed_1) or 0
		if speedLevel < 5 then
			return false
		end
	end
	
	if upgradeId == "pp_auto_eff_2" then
		local effLevel = tonumber(data.prestigeUpgrades.pp_auto_eff_1) or 0
		if effLevel < 3 then
			return false
		end
	end
	
	if upgradeId == "pp_global_mult_2" then
		local globalLevel = tonumber(data.prestigeUpgrades.pp_global_mult_1) or 0
		if globalLevel < 8 then
			return false
		end
	end
	
	if upgradeId == "pp_offline_duration_1" then
		local offlineLevel = tonumber(data.prestigeUpgrades.pp_offline_core_1) or 0
		if offlineLevel < 3 then
			return false
		end
	end
	
	if upgradeId == "pp_softcap_smooth_1" then
		local totalUpgrades = 0
		if typeof(data.upgrades) == "table" then
			for _, level in pairs(data.upgrades) do
				if typeof(level) == "number" then
					totalUpgrades += level
				end
			end
		end
		if totalUpgrades < 1000 then
			return false
		end
	end
	
	local cost = getCost(def, current)
	local points = tonumber(data.prestigePoints) or 0
	if points < cost then
		return false
	end
	data.prestigePoints = points - cost
	data.prestigeUpgrades[upgradeId] = current + 1
	PlayerDataService.Set(player, data)
	return true
end

function PrestigePointsService.GetUpgradeLevel(playerData, upgradeId)
	if typeof(playerData) ~= "table" then
		return 0
	end
	local upgrades = playerData.prestigeUpgrades
	if typeof(upgrades) ~= "table" then
		return 0
	end
	local level = tonumber(upgrades[upgradeId]) or 0
	if upgradeId == "pp_auto_speed_1" then
		level = math.max(level, tonumber(upgrades.autoSpeed) or 0)
	elseif upgradeId == "pp_global_mult_1" then
		level = math.max(level, tonumber(upgrades.globalProduction) or 0)
	elseif upgradeId == "pp_milestone_amp_1" then
		level = math.max(level, tonumber(upgrades.offlineEfficiency) or 0)
	elseif upgradeId == "pp_endgame_boost_1" then
		level = math.max(level, tonumber(upgrades.costReduction) or 0)
	elseif upgradeId == "pp_auto_speed_2" then
		level = math.max(level, tonumber(upgrades.autoSpeed2) or 0)
	elseif upgradeId == "pp_auto_eff_2" then
		level = math.max(level, tonumber(upgrades.autoEfficiency2) or 0)
	elseif upgradeId == "pp_offline_duration_1" then
		level = math.max(level, tonumber(upgrades.offlineDuration) or 0)
	elseif upgradeId == "pp_softcap_smooth_1" then
		level = math.max(level, tonumber(upgrades.costReduction2) or 0)
	elseif upgradeId == "pp_global_mult_2" then
		level = math.max(level, tonumber(upgrades.globalProduction2) or 0)
	elseif upgradeId == "pp_offline_core_1" then
		level = math.max(level, tonumber(upgrades.offlineStrength) or 0)
	end
	return level
end

function PrestigePointsService.GetUpgradeDefs()
	return UPGRADES
end

return PrestigePointsService

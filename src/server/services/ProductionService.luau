local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local DebugConfig = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local PrestigePointsService = require(script.Parent.PrestigePointsService)
local MonetizationService = require(script.Parent.MonetizationService)

local ProductionService = {}

-- Idempotency guard
local initialized = false
local productionLoopRunning = false
local automationLoopRunning = false

local BASE_DPS = 1
local PRESTIGE_BONUS = 0.25
local PRODUCTION_INTERVAL = 1
local AUTOMATION_INTERVAL = 2

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
	local prestigeCount = typeof(playerData.prestige) == "number" and playerData.prestige or 0
	if prestigeCount <= 0 then
		return 1
	end
	return 1 + (prestigeCount * PRESTIGE_BONUS)
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
	
	-- Core Global Multipliers
	local ppGlobalLevel1 = PrestigePointsService.GetUpgradeLevel(playerData, "pp_global_mult_1")
	local ppGlobalMul1 = 1 + (ppGlobalLevel1 * 0.05)
	local ppGlobalLevel2 = PrestigePointsService.GetUpgradeLevel(playerData, "pp_global_mult_2")
	local ppGlobalMul2 = 1 + (ppGlobalLevel2 * 0.08)
	
	-- Individual Branch Multipliers
	local cpuMul = 1 + (PrestigePointsService.GetUpgradeLevel(playerData, "pp_cpu_mult_1") * 0.04)
	local ramMul = 1 + (PrestigePointsService.GetUpgradeLevel(playerData, "pp_ram_mult_1") * 0.04)
	local storageMul = 1 + (PrestigePointsService.GetUpgradeLevel(playerData, "pp_storage_mult_1") * 0.05)
	
	-- Endgame Scaling
	local endgameMul = 1 + (PrestigePointsService.GetUpgradeLevel(playerData, "pp_endgame_boost_1") * 0.2)
	
	-- Quality of Life and Other Effects
	local likeBonus = typeof(playerData.productionBonus) == "number" and playerData.productionBonus or 0
	local likeMul = 1 + math.max(likeBonus, 0)
	local passMul = playerData.owns2xData and 2 or 1
	local boostMul = MonetizationService.IsBoostActive(playerData) and 2 or 1

	local base = BASE_DPS + add
	local final = base * upgradeMul * prestigeMul * passMul * boostMul * ppGlobalMul1 * ppGlobalMul2 * likeMul * cpuMul * ramMul * storageMul * endgameMul

	local breakdown = {
		additive = add,
		upgradeMul = upgradeMul,
		prestigeMul = prestigeMul,
		passMul = passMul,
		boostMul = boostMul,
		ppGlobalMul1 = ppGlobalMul1,
		ppGlobalMul2 = ppGlobalMul2,
		likeMul = likeMul,
		cpuMul = cpuMul,
		ramMul = ramMul,
		storageMul = storageMul,
		endgameMul = endgameMul,
	}

	if DebugConfig then
		DebugConfig.Log(string.format("[Production] base=%0.3f add=%0.3f mulU=%0.3f mulP=%0.3f pass=%0.3f boost=%0.3f final=%0.3f", base, add, upgradeMul, prestigeMul, passMul, boostMul, final))
	end

	return {
		baseDps = base,
		finalDps = final,
		breakdown = breakdown,
	}
end

function ProductionService.GetOfflineDuration(playerData)
	local baseDuration = 3600 -- 1 hour base
	local offlineDurationLevel = PrestigePointsService.GetUpgradeLevel(playerData, "pp_offline_duration_1")
	local additionalDuration = offlineDurationLevel * 900 -- 15 minutes per level
	return baseDuration + additionalDuration
end

function ProductionService.GetOfflineStrength(playerData)
	local baseStrength = 1.0
	local offlineStrengthLevel = PrestigePointsService.GetUpgradeLevel(playerData, "pp_offline_core_1")
	local strengthMultiplier = 1 + (offlineStrengthLevel * 0.10)
	return baseStrength * strengthMultiplier
end

function ProductionService.GetDataPerSecond(player)
	local playerData = PlayerDataService.Get(player)
	local result = ProductionService.ComputeFinalProduction(playerData)
	return result.finalDps or BASE_DPS
end

-- Idempotent initialization
function ProductionService.OnStart()
	if initialized then
		return
	end
	initialized = true
	
	-- Start production loop only once
	if not productionLoopRunning then
		productionLoopRunning = true
		task.spawn(function()
			while true do
				task.wait(PRODUCTION_INTERVAL)
				-- Production loop logic would go here
				-- For now, this is a placeholder for the actual production logic
			end
		end)
	end
	
	-- Start automation loop only once
	if not automationLoopRunning then
		automationLoopRunning = true
		task.spawn(function()
			while true do
				task.wait(AUTOMATION_INTERVAL)
				-- Automation loop logic would go here
				-- For now, this is a placeholder for the actual automation logic
			end
		end)
	end
	
	if DebugConfig then
		DebugConfig.Log("[ProductionService] Initialized")
	end
end

return ProductionService

local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeService = require(script.Parent.UpgradeService)
local UpgradeConfig = require(game:GetService("ReplicatedStorage").Shared.UpgradeConfig)
local AutomationConfig = require(game:GetService("ReplicatedStorage").Shared.AutomationConfig)

local AutomationService = {}

local CHECK_INTERVAL = 2
local automationSettings = {}
local automationById = {}
local automationOrder = {}
local branchByAutomation = {
	auto_cpu = "CPU",
	auto_ram = "RAM",
}

for _, definition in ipairs(AutomationConfig.GetAll()) do
	automationById[definition.id] = definition
	table.insert(automationOrder, definition.id)
end

local function getPlayerSettings(player)
	local settings = automationSettings[player]
	if not settings then
		settings = {}
		automationSettings[player] = settings
	end
	return settings
end

local function isAutomationEnabled(player, automation)
	local settings = getPlayerSettings(player)
	local value = settings[automation.id]
	if value == nil then
		return automation.enabledByDefault
	end
	return value
end

local function isAutomationUnlocked(playerData, automation)
	local requirements = automation.unlockRequirement
	if not requirements then
		return true
	end

	if requirements.storageTier then
		local tier = UpgradeConfig.GetStorageTier(playerData.upgrades or {})
		if tier < requirements.storageTier then
			return false
		end
	end

	return true
end

local function selectCheapestUpgrade(branch, playerData)
	local definitions = UpgradeConfig.GetUpgradesByBranch(branch)
	local owned = playerData.upgrades or {}
	local currency = typeof(playerData.data) == "number" and playerData.data or 0

	local choiceId
	local choiceCost

	for _, upgrade in ipairs(definitions) do
		if not UpgradeConfig.IsMaxed(owned, upgrade.id) and UpgradeConfig.MeetsRequirements(owned, upgrade.id) then
			local level = UpgradeConfig.GetLevel(owned, upgrade.id)
			local cost = UpgradeConfig.GetCost(upgrade.id, level)
			if typeof(cost) == "number" and currency >= cost then
				if not choiceCost or cost < choiceCost then
					choiceCost = cost
					choiceId = upgrade.id
				end
			end
		end
	end

	return choiceId
end

local function tryAutomationPurchase(player, automationId, playerData)
	local automation = automationById[automationId]
	if not automation or not isAutomationEnabled(player, automation) then
		return playerData
	end

	if not isAutomationUnlocked(playerData, automation) then
		return playerData
	end

	local branch = branchByAutomation[automationId]
	if not branch then
		return playerData
	end

	local upgradeId = selectCheapestUpgrade(branch, playerData)
	if not upgradeId then
		return playerData
	end

	local success = UpgradeService.Buy(player, upgradeId)
	if success then
		return PlayerDataService.Get(player)
	end

	return playerData
end

local function processPlayerAutomation(player)
	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return
	end

	for _, automationId in ipairs(automationOrder) do
		playerData = tryAutomationPurchase(player, automationId, playerData)
	end
end

local function automationLoop()
	while true do
		task.wait(CHECK_INTERVAL)
		for player in pairs(automationSettings) do
			if player and player.Parent then
				processPlayerAutomation(player)
			else
				automationSettings[player] = nil
			end
		end
	end
end

function AutomationService.SetEnabled(player, automationId, enabled)
	local automation = automationById[automationId]
	if not automation then
		return
	end

	local settings = getPlayerSettings(player)
	settings[automationId] = enabled and true or false
end

function AutomationService.Init()
	if AutomationService._initialized then
		return
	end
	AutomationService._initialized = true

	Players.PlayerAdded:Connect(function(player)
		getPlayerSettings(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		automationSettings[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		getPlayerSettings(player)
	end

	task.spawn(automationLoop)
end

return AutomationService

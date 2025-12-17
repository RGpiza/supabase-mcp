local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeService = require(script.Parent.UpgradeService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local AutomationConfig = require(ReplicatedStorage.Shared.AutomationConfig)

local AutomationService = {}

local PROCESS_INTERVAL = 0.35
local MAX_BRANCH_ITERATIONS = 4

local automationSettings = {}
local feedbackRemote

local definitions = AutomationConfig.GetAll()
local definitionsByBranch = {}
local branchUpgradeMap = {}

for _, definition in ipairs(definitions) do
	if definition.branch then
		definitionsByBranch[definition.branch] = definition
		branchUpgradeMap[definition.branch] = UpgradeConfig.GetUpgradesByBranch(definition.branch)
	end
end

local function ensurePlayerDefaults(player)
	local state = automationSettings[player]
	if not state then
		state = {}
		automationSettings[player] = state
	end

	for branch, definition in pairs(definitionsByBranch) do
		if state[branch] == nil then
			state[branch] = definition.enabledByDefault == true
		end

		if definition.attribute and player:GetAttribute(definition.attribute) == nil then
			player:SetAttribute(definition.attribute, state[branch])
		end
	end

	if player:GetAttribute("PrestigeInProgress") == nil then
		player:SetAttribute("PrestigeInProgress", false)
	end

	return state
end

local function selectAffordableUpgrade(branch, playerData)
	local upgrades = branchUpgradeMap[branch]
	if not upgrades then
		return nil
	end

	local owned = typeof(playerData.upgrades) == "table" and playerData.upgrades or {}
	local currency = typeof(playerData.data) == "number" and playerData.data or 0

	local choiceId
	local lowestCost

	for _, upgrade in ipairs(upgrades) do
		if not UpgradeConfig.IsMaxed(owned, upgrade.id) and UpgradeConfig.MeetsRequirements(owned, upgrade.id) then
			local level = UpgradeConfig.GetLevel(owned, upgrade.id)
			local cost = UpgradeConfig.GetCost(upgrade.id, level)
			if typeof(cost) == "number" and currency >= cost then
				if not lowestCost or cost < lowestCost then
					lowestCost = cost
					choiceId = upgrade.id
				end
			end
		end
	end

	return choiceId
end

local function sendFeedback(player, branch, amount)
	if feedbackRemote and player and player.Parent then
		feedbackRemote:FireClient(player, branch, amount)
	end
end

function AutomationService.SetEnabled(player, branchName, enabled)
	if not player or typeof(branchName) ~= "string" then
		return
	end

	local normalizedBranch = string.upper(branchName)
	local definition = definitionsByBranch[normalizedBranch]
	if not definition then
		return
	end

	local state = ensurePlayerDefaults(player)
	state[normalizedBranch] = enabled == true

	if definition.attribute then
		player:SetAttribute(definition.attribute, state[normalizedBranch])
	end
end

function AutomationService._processBranch(player, branchName, playerData)
	local definition = definitionsByBranch[branchName]
	if not definition then
		return playerData
	end

	if definition.unlockRequirement and definition.unlockRequirement.storageTier and definition.unlockRequirement.storageTier > 0 then
		local tier = UpgradeConfig.GetStorageTier(playerData.upgrades or {})
		if tier < definition.unlockRequirement.storageTier then
			return playerData
		end
	end

	local totalPurchased = 0
	local iterations = 0

	while iterations < MAX_BRANCH_ITERATIONS do
		iterations += 1

		if player:GetAttribute("PrestigeInProgress") then
			break
		end

		local upgradeId = selectAffordableUpgrade(branchName, playerData)
		if not upgradeId then
			break
		end

		local success, purchased = UpgradeService.BuyMax(player, upgradeId)
		if not success or not purchased or purchased <= 0 then
			break
		end

		totalPurchased += purchased

		playerData = PlayerDataService.Get(player)
		if typeof(playerData) ~= "table" then
			break
		end
	end

	if totalPurchased > 0 then
		sendFeedback(player, branchName, totalPurchased)
	end

	return playerData
end

function AutomationService._processPlayer(player, state)
	if not player or not state then
		return
	end

	if player:GetAttribute("PrestigeInProgress") then
		return
	end

	local anyEnabled = false
	for branch, enabled in pairs(state) do
		if enabled == true and definitionsByBranch[branch] then
			anyEnabled = true
			break
		end
	end

	if not anyEnabled then
		return
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return
	end

	for branch, enabled in pairs(state) do
		if enabled == true and definitionsByBranch[branch] then
			playerData = AutomationService._processBranch(player, branch, playerData)
			if typeof(playerData) ~= "table" then
				playerData = PlayerDataService.Get(player)
				if typeof(playerData) ~= "table" then
					break
				end
			end
		end
	end
end

local function processPlayers()
	for player, state in pairs(automationSettings) do
		if player and player.Parent then
			AutomationService._processPlayer(player, state)
		else
			automationSettings[player] = nil
		end
	end
end

function AutomationService.Init(remote)
	if AutomationService._initialized then
		if remote then
			feedbackRemote = remote
		end
		return
	end

	AutomationService._initialized = true
	feedbackRemote = remote

	Players.PlayerAdded:Connect(function(player)
		ensurePlayerDefaults(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		automationSettings[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		ensurePlayerDefaults(player)
	end

	task.spawn(function()
		while true do
			task.wait(PROCESS_INTERVAL)
			processPlayers()
		end
	end)
end

return AutomationService

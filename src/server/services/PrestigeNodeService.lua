local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local PrestigeConfig = require(ReplicatedStorage.Shared.PrestigeConfig)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)

local PrestigeNodeService = {}

local function ensureTables(data)
	if typeof(data.unlocks) ~= "table" then
		data.unlocks = {}
	end
	if typeof(data.automation) ~= "table" then
		data.automation = {
			cpuAuto = false,
			ramAuto = false,
			stoAuto = false,
			tickMs = PrestigeConfig.AUTOMATION_TICK_MS_DEFAULT,
			enabled = true,
		}
	end
	return data
end

local function getNodeDef(nodeId)
	if typeof(nodeId) ~= "string" then
		return nil
	end
	return PrestigeConfig.NODES[nodeId]
end

local function hasPrereq(unlocks, prereq)
	if not prereq then
		return true
	end
	return unlocks and unlocks[prereq] == true
end

function PrestigeNodeService.GetState(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	ensureTables(data)
	return {
		prestige = data.prestige or 0,
		prestigePoints = data.prestigePoints or 0,
		ppSpent = data.ppSpent or 0,
		unlocks = table.clone(data.unlocks),
		automation = table.clone(data.automation),
		prestigeUpgrades = table.clone(data.prestigeUpgrades or {}),
		nodes = PrestigeConfig.NODES,
	}
end

function PrestigeNodeService.Purchase(player, nodeId)
	local def = getNodeDef(nodeId)
	if not def then
		return false
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false
	end
	ensureTables(data)

	if data.unlocks[nodeId] == true then
		return false
	end
	if not hasPrereq(data.unlocks, def.prereq) then
		return false
	end

	local cost = tonumber(def.cost) or 0
	local points = tonumber(data.prestigePoints) or 0
	if points < cost then
		return false
	end

	data.prestigePoints = math.max(points - cost, 0)
	data.ppSpent = (tonumber(data.ppSpent) or 0) + cost
	data.unlocks[nodeId] = true

	if def.automationKey then
		data.automation[def.automationKey] = true
	end
	if typeof(data.automation.tickMs) ~= "number" then
		data.automation.tickMs = PrestigeConfig.AUTOMATION_TICK_MS_DEFAULT
	end

	PlayerDataService.Set(player, data)
	AnalyticsTrackerService.LogEconomySink(
		player,
		"PrestigePoints",
		cost,
		data.prestigePoints,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		nodeId,
		{
			nodeCategory = "Automation",
		}
	)
	AnalyticsTrackerService.LogCustomCounter(player, "AutomationEnabled", {
		nodeId = nodeId,
	})
	local sessionId = AnalyticsTrackerService.GetOrStartFunnel(player, "PrestigeTreePurchase")
	if sessionId then
		AnalyticsTrackerService.LogFunnelStep(player, "PrestigeTreePurchase", sessionId, 3, "Purchase Node Success", {
			itemSKU = nodeId,
		})
	end
	return true
end

return PrestigeNodeService

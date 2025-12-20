local ReplicatedStorage = game:GetService("ReplicatedStorage")
local clientRoot = ReplicatedStorage:FindFirstChild("Client")
if clientRoot and clientRoot:FindFirstChild("Framework") then
	return {
		ProcessPayload = function()
			return false
		end,
	}
end

local UIPipelineController = require(script.Parent:WaitForChild("UIPipelineController"))

local RequestSyncClient = {
	_lastHash = nil,
}
local loggedPayload = false

local function stringifyUpgradeEntry(id, entry)
	if type(entry) == "table" then
		local level = entry.level
		local cost = entry.cost
		local owned = entry.owned
		local locked = entry.locked
		return table.concat({
			tostring(id),
			tostring(level),
			tostring(cost),
			tostring(owned),
			tostring(locked),
		}, ":")
	end
	return tostring(id) .. ":" .. tostring(entry)
end

local function computePayloadHash(payload)
	if type(payload) ~= "table" then
		return ""
	end
	local upgrades = payload.upgrades or payload.Upgrades
	if type(upgrades) ~= "table" then
		return ""
	end

	local parts = {}
	if #upgrades > 0 then
		for _, entry in ipairs(upgrades) do
			local id = type(entry) == "table" and (entry.id or entry.upgradeId) or nil
			if id then
				table.insert(parts, stringifyUpgradeEntry(id, entry))
			end
		end
	else
		local keys = {}
		for key in pairs(upgrades) do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			table.insert(parts, stringifyUpgradeEntry(key, upgrades[key]))
		end
	end

	return table.concat(parts, "|")
end

function RequestSyncClient.ProcessPayload(payload)
	if type(payload) ~= "table" then
		return false
	end
	if not loggedPayload then
		loggedPayload = true
		print("[RequestSyncClient] Payload:", payload)
	end
	local playerData = payload.playerData or payload.PlayerData
	local upgrades = payload.upgrades or payload.Upgrades
	if type(playerData) ~= "table" then
		error("[RequestSyncClient] Missing playerData in payload")
	end
	if type(upgrades) ~= "table" or next(upgrades) == nil then
		error("[RequestSyncClient] Missing upgrades in payload")
	end
	local hash = computePayloadHash(payload)
	if hash ~= "" and hash == RequestSyncClient._lastHash then
		return false
	end
	RequestSyncClient._lastHash = hash

	return UIPipelineController.RenderFromPayload(payload) == true
end

return RequestSyncClient

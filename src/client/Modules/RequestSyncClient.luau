local UpgradeRenderer = require(script.Parent:WaitForChild("UpgradeRenderer"))
local UpgradeBinder = require(script.Parent:WaitForChild("UpgradeBinder"))

local RequestSyncClient = {
	_lastHash = nil,
}

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
	local hash = computePayloadHash(payload)
	if hash ~= "" and hash == RequestSyncClient._lastHash then
		return false
	end
	RequestSyncClient._lastHash = hash

	UpgradeRenderer.Render(payload)
	if type(UpgradeBinder.RebindAll) == "function" then
		UpgradeBinder.RebindAll()
	end
	return true
end

return RequestSyncClient

-- src/client/RequestSyncClient.client.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local modulesFolder = script.Parent and script.Parent:FindFirstChild("Modules")
local upgradeRendererModule = modulesFolder and modulesFolder:FindFirstChild("UpgradeRenderer")
local UpgradeRenderer = upgradeRendererModule and require(upgradeRendererModule)

local WARN_COOLDOWN = 5
local lastWarnAt = 0
local lastPayloadHash = nil

local function warnThrottled(message)
	local now = os.clock()
	if now - lastWarnAt < WARN_COOLDOWN then
		return
	end
	lastWarnAt = now
	warn(message)
end

local function computeUpgradesSignature(payload)
	if type(payload) ~= "table" then
		return ""
	end
	local upgrades = payload.upgrades
	if type(upgrades) ~= "table" then
		return ""
	end
	local keys = {}
	for key in pairs(upgrades) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		local value = upgrades[key]
		table.insert(parts, tostring(key) .. ":" .. tostring(value))
	end
	return table.concat(parts, "|")
end

local function pollLoop()
    while true do
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local requestSync = remotes and remotes:FindFirstChild("RequestSync")
		if not (requestSync and requestSync:IsA("RemoteFunction")) then
			warnThrottled("[RequestSyncClient] RequestSync is missing. Retrying in 1 second...")
			wait(1)
			continue
		end

		local ok, payload = pcall(function()
			return requestSync:InvokeServer()
		end)
		if ok and type(payload) == "table" then
			print("[RequestSyncClient] Valid payload received")
			if UpgradeRenderer and type(UpgradeRenderer.Render) == "function" then
				local signature = computeUpgradesSignature(payload)
				if signature ~= lastPayloadHash then
					lastPayloadHash = signature
					UpgradeRenderer.Render(payload)
				end
			end
		else
			warnThrottled("[RequestSyncClient] Invalid payload received. Retrying in 1 second...")
		end

		wait(1)
	end
end

-- Start the poll loop on a separate thread to avoid blocking the main game loop
spawn(pollLoop)

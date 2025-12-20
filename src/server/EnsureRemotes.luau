-- EnsureRemotes.luau
-- Server script: ensures required remotes exist under ReplicatedStorage.Remotes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local expected = {
	-- RemoteEvents
	LoadingProgress = "RemoteEvent",
	StoreAnalyticsEvent = "RemoteEvent",
	BoostsUpdated = "RemoteEvent",
	OfflineEarningsPreview = "RemoteEvent",
	SaveStatus = "RemoteEvent",
	PurchaseUpgrade = "RemoteEvent",
	RequestPrestige = "RemoteEvent",
	PrestigePreviewUpdate = "RemoteEvent",
	SessionBonusUpdate = "RemoteEvent",
	GlobalAnnouncement = "RemoteEvent",
	GlobalStatsUpdate = "RemoteEvent",
	ServerPowerUpdate = "RemoteEvent",
	SystemNotification = "RemoteEvent",
	AutoBuyPresetApply = "RemoteEvent",
	AutoBuyPresetSave = "RemoteEvent",
	AutoBuyPresetState = "RemoteEvent",
	AutoBuyPresetUnlockPrompt = "RemoteEvent",
	AutoBuyAutoSwitchSettings = "RemoteEvent",
	SetAutoBuy = "RemoteEvent",
	AutoBuyState = "RemoteEvent",

	-- RemoteFunctions
	RequestPrestigePreview = "RemoteFunction",
	RequestAutoBuyPresets = "RemoteFunction",
	GetLeaderboard = "RemoteFunction",
	GetLifetimeLeaderboard = "RemoteFunction",
	GetWeeklyResetTime = "RemoteFunction",
	GetGlobalStats = "RemoteFunction",
	RequestSync = "RemoteFunction",
}

local function ensureRemotes()
	local results = {
		created = {},
		recreated = {},
		unchanged = {},
		errors = {},
	}

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		local ok, folder = pcall(function()
			local f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
			return f
		end)
		if ok and folder then
			remotesFolder = folder
			table.insert(results.created, "Remotes folder")
		else
			table.insert(results.errors, "Failed to create Remotes folder")
			return results
		end
	end

	for name, className in pairs(expected) do
		local existing = remotesFolder:FindFirstChild(name)
		if existing then
			if existing.ClassName ~= className then
				-- wrong type: replace
				local ok, err = pcall(function()
					existing:Destroy()
					local inst = Instance.new(className)
					inst.Name = name
					inst.Parent = remotesFolder
				end)
				if ok then
					table.insert(results.recreated, name .. " (was: " .. tostring(existing.ClassName) .. ")")
				else
					table.insert(results.errors, "Failed to recreate " .. name .. ": " .. tostring(err))
				end
			else
				table.insert(results.unchanged, name)
			end
		else
			-- missing: create
			local ok, err = pcall(function()
				local inst = Instance.new(className)
				inst.Name = name
				inst.Parent = remotesFolder
			end)
			if ok then
				table.insert(results.created, name)
			else
				table.insert(results.errors, "Failed to create " .. name .. ": " .. tostring(err))
			end
		end
	end

	-- Summary print
	print("[EnsureRemotes] Summary:")
	print(" Created:", #results.created)
	for _, v in ipairs(results.created) do print("  - " .. v) end
	print(" Recreated (wrong type):", #results.recreated)
	for _, v in ipairs(results.recreated) do print("  - " .. v) end
	print(" Unchanged:", #results.unchanged)
	for _, v in ipairs(results.unchanged) do print("  - " .. v) end
	if #results.errors > 0 then
		print(" Errors:")
		for _, v in ipairs(results.errors) do print("  - " .. v) end
	end

	return results
end

-- Run at startup
local ok, res = pcall(function() return ensureRemotes() end)
if not ok then
	warn("[EnsureRemotes] Failed to ensure remotes:", res)
end

return nil

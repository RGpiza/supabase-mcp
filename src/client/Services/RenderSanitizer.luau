local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")
local ran = false
if ran then
	return {}
end
ran = true

local function findAllowed(clientRoot)
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local services = clientRoot and clientRoot:FindFirstChild("Services")
	local initFolder = clientRoot and clientRoot:FindFirstChild("Init")
	local allowed = {
		controllers and controllers:FindFirstChild("UpgradePipeline"),
		controllers and controllers:FindFirstChild("WeeklyLeaderboardController"),
		controllers and controllers:FindFirstChild("AutoBuyController"),
		services and services:FindFirstChild("UILoader"),
		services and services:FindFirstChild("RenderSanitizer"),
	}
	if initFolder then
		for _, child in ipairs(initFolder:GetChildren()) do
			if child.Name == "ClientInit" then
				table.insert(allowed, child)
			end
		end
	end
	return allowed
end

local function buildAllowedSet(...)
	local allowedSet = {}
	for _, list in ipairs({ ... }) do
		for _, inst in ipairs(list) do
			if inst then
				allowedSet[inst] = true
			end
		end
	end
	allowedSet[script] = true
	return allowedSet
end

local function disableNonWhitelisted(root, allowedSet, log)
	if not root then
		return
	end
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("LocalScript") and not allowedSet[inst] then
			inst.Disabled = true
			table.insert(log, inst:GetFullName())
		end
	end
end

local moduleRoot = script.Parent and script.Parent.Parent
local allowed = buildAllowedSet(findAllowed(moduleRoot))
local disabled = {}

local playerScripts = player and player:FindFirstChild("PlayerScripts")
local clientFolder = playerScripts and playerScripts:FindFirstChild("Client")
disableNonWhitelisted(clientFolder, allowed, disabled)

if #disabled > 0 then
	print("[RenderSanitizer] Disabled modules:", table.concat(disabled, ", "))
else
	print("[RenderSanitizer] No modules disabled")
end

return {}

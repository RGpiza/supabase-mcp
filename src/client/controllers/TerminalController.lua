local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then
	warn("[TerminalController] Player not found")
	return
end

local playerGui = player:WaitForChild("PlayerGui", 5)
if not playerGui then
	warn("[TerminalController] PlayerGui not found")
	return
end

-- Check if UI already exists
local existingTerminalUI = playerGui:FindFirstChild("TerminalUI")
if existingTerminalUI then
	print("[TerminalController] Reusing existing TerminalUI")
	local root = existingTerminalUI:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	if root and safeArea then
		-- UI is complete, proceed to initialize controllers
		print("[TerminalController] Bootstrap complete")
		-- Initialize child controllers
		local controllers = {
			"TopBarController",
			"UpgradeController", 
			"PrestigeController",
			"LeaderboardController",
			"CommunityController",
			"NotificationController"
		}
		
		for _, controllerName in ipairs(controllers) do
			local controllerModule = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("controllers"):FindFirstChild(controllerName)
			if controllerModule then
				local success, result = pcall(function()
					return require(controllerModule)
				end)
				if success then
					print("[TerminalController] Initialized " .. controllerName)
				else
					warn("[TerminalController] Failed to initialize " .. controllerName .. ": " .. tostring(result))
				end
			else
				-- Controllers may not exist yet - this is expected during development
				print("[TerminalController] Controller not found (expected): " .. controllerName)
			end
		end
		return
	end
end

-- Create TerminalUI ScreenGui
local terminalUI = Instance.new("ScreenGui")
terminalUI.Name = "TerminalUI"
terminalUI.ResetOnSpawn = false
terminalUI.Parent = playerGui
print("[TerminalController] Created ScreenGui")

-- Create Root Frame
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(1, 0, 1, 0)
root.Position = UDim2.new(0, 0, 0, 0)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.ClipsDescendants = false
root.Parent = terminalUI
print("[TerminalController] Created Root")

-- Create SafeArea Frame
local safeArea = Instance.new("Frame")
safeArea.Name = "SafeArea"
safeArea.Size = UDim2.new(1, 0, 1, 0)
safeArea.Position = UDim2.new(0, 0, 0, 0)
safeArea.BackgroundTransparency = 1
safeArea.BorderSizePixel = 0
safeArea.ClipsDescendants = true
safeArea.Parent = root

-- Add UI padding for mobile insets
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 10)
uiPadding.PaddingBottom = UDim.new(0, 10)
uiPadding.PaddingLeft = UDim.new(0, 10)
uiPadding.PaddingRight = UDim.new(0, 10)
uiPadding.Parent = safeArea

print("[TerminalController] Bootstrap complete")

-- Note: Child controllers are not loaded here as they don't exist in the current architecture
-- The SystemIncrementalUI is a single-file implementation that handles all UI functionality
-- Controllers are maintained for backward compatibility but are not used by the new UI system
print("[TerminalController] Controllers not loaded - using single-file UI architecture")

-- Return nil to indicate this is a script, not a module
return nil

-- UILoader.client.luau
-- Optimized LocalScript for loading the high-performance UI system
-- Ensures proper client-side execution and initialization

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for local player
local player = Players.LocalPlayer
if not player then
	return
end

-- Wait for PlayerGui
local playerGui = player:WaitForChild("PlayerGui")

-- Check if UI already exists
if playerGui:FindFirstChild("SystemIncrementalUI") then
	return
end

-- Load the performance UI manager
local PerformanceUIManager
local success, result = pcall(function()
	return require(script.Parent.PerformanceUIManager)
end)

if not success then
	warn("Failed to load PerformanceUIManager:", result)
	return
end

PerformanceUIManager = result

-- Initialize the UI system
spawn(function()
	repeat
		task.wait()
	until playerGui and playerGui.Parent
	
	-- The PerformanceUIManager handles its own initialization
	-- This ensures proper timing and prevents duplicate creation
end)

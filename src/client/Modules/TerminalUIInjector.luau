local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local TerminalUIInjector = {}

local function fail(message)
	error("[TerminalUIInjector] " .. message)
end

function TerminalUIInjector.Ensure(player)
	local targetPlayer = player or Players.LocalPlayer
	if not targetPlayer then
		fail("Player missing")
	end

	local playerGui = targetPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		fail("PlayerGui missing")
	end

	local template = StarterGui:FindFirstChild("TerminalUI")
	if not template then
		fail("StarterGui.TerminalUI missing")
	end
	if not template:IsA("ScreenGui") then
		fail("StarterGui.TerminalUI is not a ScreenGui")
	end

	local existing = playerGui:FindFirstChild("TerminalUI")
	if existing then
		if not existing:IsA("ScreenGui") then
			fail("PlayerGui.TerminalUI is not a ScreenGui")
		end
		return existing
	end

	local clone = template:Clone()
	clone.Parent = playerGui
	return clone
end

return TerminalUIInjector

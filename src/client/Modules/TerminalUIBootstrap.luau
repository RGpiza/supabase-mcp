local StarterGui = game:GetService("StarterGui")

local TerminalUIBootstrap = {}

local logged = false

local function fail(message)
	error("[TerminalUIBootstrap] " .. message)
end

function TerminalUIBootstrap.Ensure(playerGui)
	if not playerGui then
		fail("PlayerGui missing")
	end

	local existing = playerGui:FindFirstChild("TerminalUI")
	if existing then
		if not existing:IsA("ScreenGui") then
			fail("PlayerGui.TerminalUI is not a ScreenGui")
		end
		return existing
	end

	local template = StarterGui:FindFirstChild("TerminalUI")
	if not template then
		fail("StarterGui.TerminalUI missing")
	end
	if not template:IsA("ScreenGui") then
		fail("StarterGui.TerminalUI is not a ScreenGui")
	end

	local clone = template:Clone()
	clone.Name = "TerminalUI"
	clone.Parent = playerGui

	if not logged then
		logged = true
		print("[TerminalUIBootstrap] TerminalUI injected into PlayerGui")
	end

	return clone
end

return TerminalUIBootstrap

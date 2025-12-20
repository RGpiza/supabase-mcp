local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local TerminalUIBootstrap = {}

local logged = false

local function getReadyEvent()
	local existing = ReplicatedStorage:FindFirstChild("TerminalUIReady")
	if existing then
		if not existing:IsA("BindableEvent") then
			error("[TerminalUIBootstrap] ReplicatedStorage.TerminalUIReady must be a BindableEvent")
		end
		return existing
	end
	local event = Instance.new("BindableEvent")
	event.Name = "TerminalUIReady"
	event.Parent = ReplicatedStorage
	return event
end

function TerminalUIBootstrap.Ensure(player)
	if not player then
		warn("[TerminalUIBootstrap] Player missing")
		return nil
	end

	print("[TerminalUIBootstrap] Ensure start")
	local starterTemplate = StarterGui:FindFirstChild("TerminalUI")
	if not starterTemplate or not starterTemplate:IsA("ScreenGui") then
		error("[TerminalUIBootstrap] StarterGui.TerminalUI missing or not a ScreenGui")
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		error("[TerminalUIBootstrap] PlayerGui missing")
	end

	local existing = playerGui:FindFirstChild("TerminalUI")
	if existing and existing:IsA("ScreenGui") then
		print("[TerminalUIBootstrap] TerminalUI already in PlayerGui")
		print("[TerminalUIBootstrap] Firing TerminalUIReady")
		getReadyEvent():Fire(existing)
		print("[TerminalUIBootstrap] Fired TerminalUIReady")
		return existing
	end

	print("[TerminalUIBootstrap] Cloning TerminalUI")
	local clone = starterTemplate:Clone()
	clone.Name = "TerminalUI"
	clone.Enabled = true
	clone.Parent = playerGui
	print("[TerminalUIBootstrap] Cloned TerminalUI")

	if not logged then
		logged = true
		print("[TerminalUIBootstrap] TerminalUI injected into PlayerGui")
	end

	print("[TerminalUIBootstrap] Firing TerminalUIReady")
	getReadyEvent():Fire(clone)
	print("[TerminalUIBootstrap] Fired TerminalUIReady")

	return clone
end

return TerminalUIBootstrap

local Players = game:GetService("Players")

local modules = script.Parent.Parent and script.Parent.Parent:FindFirstChild("Modules")
local UIPaths = modules and modules:FindFirstChild("UIPaths")
UIPaths = UIPaths and require(UIPaths) or nil

local UILoader = {}

local function waitForChildEvent(parent, childName, className)
	if not parent then
		return nil
	end
	local existing = parent:FindFirstChild(childName)
	if existing and (not className or existing:IsA(className)) then
		return existing
	end
	local thread = coroutine.running()
	local connection
	connection = parent.ChildAdded:Connect(function(child)
		if child.Name == childName and (not className or child:IsA(className)) then
			connection:Disconnect()
			coroutine.resume(thread, child)
		end
	end)
	return coroutine.yield()
end

function UILoader.WaitForTerminalUI()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		playerGui = waitForChildEvent(player, "PlayerGui", "PlayerGui")
	end
	if not playerGui then
		return nil
	end
	if UIPaths then
		local terminalUi = UIPaths.GetTerminalUI(playerGui)
		if terminalUi then
			return terminalUi
		end
	end
	return waitForChildEvent(playerGui, "TerminalUI", "ScreenGui")
end

return UILoader

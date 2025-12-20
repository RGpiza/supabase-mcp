local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local clientRoot = ReplicatedStorage:FindFirstChild("Client")
if clientRoot and clientRoot:FindFirstChild("Framework") then
	return {
		BindCard = function() end,
		RebindAll = function() end,
		EnsureBindings = function() end,
		Init = function() end,
		ReportStatus = function() end,
	}
end

local UpgradeBinder = {}

function UpgradeBinder.Init(_terminalUi)
	return true
end

local function findBuyButton(card)
	return card:FindFirstChild("BuyButton", true) or card:FindFirstChild("CardBuyButton", true)
end

local function bindButton(button, upgradeId)
	if button:GetAttribute("UpgradeBound") == true then
		return false
	end
	if button:GetAttribute("Bound") == true then
		return false
	end
	button:SetAttribute("UpgradeBound", true)
	button:SetAttribute("Bound", true)
	button.Activated:Connect(function()
		print(('[UpgradeBinder] Activated upgradeId=%s'):format(tostring(upgradeId)))
	end)
	return true
end

function UpgradeBinder.RebindAll(containers)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if playerGui and playerGui:GetAttribute("UIPipelineAuthoritative") == true then
		return
	end
	if type(containers) ~= "table" then
		return
	end

	local totalButtons = 0
	local boundButtons = 0

	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("GuiObject") then
					if child:GetAttribute("Bound") == true then
						continue
					end
					local button = findBuyButton(child)
					if button and button:IsA("GuiButton") then
						child:SetAttribute("Bound", true)
						totalButtons += 1
						local upgradeId = child:GetAttribute("UpgradeId") or child.Name
						if bindButton(button, upgradeId) then
							boundButtons += 1
						end
					end
				end
			end
		end
	end

	print(('[UpgradeBinder] Bound %d/%d buttons'):format(boundButtons, totalButtons))
end

function UpgradeBinder.BindRenderedCards(rendered, containers)
	if rendered ~= true then
		warn("[UpgradeBinder] Render not confirmed; skipping bind")
		return false
	end
	UpgradeBinder.RebindAll(containers)
	return true
end

return UpgradeBinder

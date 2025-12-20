local UpgradeBinder = {}

local function findBuyButton(card)
	return card:FindFirstChild("BuyButton", true) or card:FindFirstChild("CardBuyButton", true)
end

local function bindButton(button, upgradeId)
	if button:GetAttribute("UpgradeBound") == true then
		return false
	end
	button:SetAttribute("UpgradeBound", true)
	button.Activated:Connect(function()
		print(('[UpgradeBinder] Activated upgradeId=%s'):format(tostring(upgradeId)))
	end)
	return true
end

function UpgradeBinder.RebindAll(containers)
	if type(containers) ~= "table" then
		return
	end

	local totalButtons = 0
	local boundButtons = 0

	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("GuiObject") then
					local button = findBuyButton(child)
					if button and button:IsA("GuiButton") then
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

return UpgradeBinder

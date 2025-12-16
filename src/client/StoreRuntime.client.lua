local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ICONS = {
	x2Data = "rbxassetid://72115771900859",
	fasterAuto = "rbxassetid://90107863643546",
	boost5m = "rbxassetid://137979744663076",
	boost1h = "rbxassetid://94963878483638",
}

local TIMEOUT = 5
local OVERLAY_VISIBLE_TRANSPARENCY = 0.45
local OVERLAY_HIDDEN_TRANSPARENCY = 1
local CLOSED_SIZE = UDim2.new(0.62, 0, 0.7, 0)
local OPEN_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function waitForChild(parent, childName)
	if not parent then
		return nil
	end

	return parent:WaitForChild(childName, TIMEOUT)
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
if not localPlayer then
	return
end

local playerGui = waitForChild(localPlayer, "PlayerGui")
if not playerGui then
	return
end

local terminalUi = waitForChild(playerGui, "TerminalUI")
local root = terminalUi and waitForChild(terminalUi, "Root")
local safeArea = root and waitForChild(root, "SafeArea")
if not safeArea then
	return
end

local storeOverlay = waitForChild(safeArea, "StoreOverlay")
local storeUi = waitForChild(safeArea, "StoreUI")
local topBar = waitForChild(safeArea, "TopBar")
if not (storeOverlay and storeUi and topBar) then
	return
end

local STORE_UI_ZINDEX = math.max(storeUi.ZIndex, 50)
storeUi.ZIndex = STORE_UI_ZINDEX
storeOverlay.ZIndex = math.max(storeOverlay.ZIndex, STORE_UI_ZINDEX - 1)
if storeOverlay:IsA("GuiBase2d") then
	storeOverlay.Active = true
	if storeOverlay:IsA("GuiButton") then
		storeOverlay.AutoButtonColor = false
	end
end

local storeButton = waitForChild(topBar, "StoreButton")
local header = waitForChild(storeUi, "Header")
local closeButton = header and waitForChild(header, "Close")
if not (storeButton and closeButton) then
	return
end

local openPosition = storeUi.Position
local openSize = storeUi.Size
local closedPosition = UDim2.new(openPosition.X.Scale, openPosition.X.Offset, openPosition.Y.Scale + 0.03, openPosition.Y.Offset)

storeOverlay.Visible = false
storeOverlay.BackgroundTransparency = OVERLAY_HIDDEN_TRANSPARENCY
storeUi.Visible = false
storeUi.BackgroundTransparency = 0
storeUi.Size = openSize
storeUi.Position = openPosition

local isStoreOpen = false
local currentOverlayTween = nil
local currentStoreTween = nil

local function cancelTween(tween)
	if tween then
		tween:Cancel()
	end
end

local function applyIconToCard(card, imageId)
	if not (card and imageId) then
		return
	end

	local icon = card:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		icon.Image = imageId
	end
end

local function findCard(name, keyword)
	if not storeUi then
		return nil
	end

	local found = storeUi:FindFirstChild(name, true)
	if found and found:IsA("GuiButton") then
		return found
	end

	if keyword then
		for _, descendant in ipairs(storeUi:GetDescendants()) do
			if descendant:IsA("TextButton") then
				local textValue = descendant.Text or ""
				if string.find(textValue, keyword, 1, true) then
					return descendant
				end
			end
		end
	end

	return nil
end

local cardConfigs = {
	{ name = "x2DataCard", keyword = "x2 Data", icon = ICONS.x2Data },
	{ name = "FasterAutoCard", keyword = "Faster Auto", icon = ICONS.fasterAuto },
	{ name = "+5MinBoostCard", keyword = "+5 Min Boost", icon = ICONS.boost5m },
	{ name = "+1HourBoostCard", keyword = "+1 Hour Boost", icon = ICONS.boost1h },
}

for _, config in ipairs(cardConfigs) do
	local card = findCard(config.name, config.keyword)
	applyIconToCard(card, config.icon)
end

local function openStore()
	if isStoreOpen then
		return
	end

	isStoreOpen = true
	cancelTween(currentOverlayTween)
	cancelTween(currentStoreTween)

	storeOverlay.Visible = true
	storeOverlay.BackgroundTransparency = OVERLAY_HIDDEN_TRANSPARENCY
	storeUi.Visible = true
	storeUi.Size = CLOSED_SIZE
	storeUi.Position = closedPosition
	storeUi.BackgroundTransparency = 1

	local overlayTween = TweenService:Create(storeOverlay, OPEN_TWEEN_INFO, {
		BackgroundTransparency = OVERLAY_VISIBLE_TRANSPARENCY,
	})
	currentOverlayTween = overlayTween
	overlayTween.Completed:Connect(function()
		if currentOverlayTween == overlayTween then
			currentOverlayTween = nil
		end
	end)
	overlayTween:Play()

	local storeTween = TweenService:Create(storeUi, OPEN_TWEEN_INFO, {
		Size = openSize,
		Position = openPosition,
		BackgroundTransparency = 0,
	})
	currentStoreTween = storeTween
	storeTween.Completed:Connect(function()
		if currentStoreTween == storeTween then
			currentStoreTween = nil
		end
	end)
	storeTween:Play()
end

local function closeStore()
	if not storeUi.Visible then
		storeOverlay.Visible = false
		storeOverlay.BackgroundTransparency = OVERLAY_HIDDEN_TRANSPARENCY
		isStoreOpen = false
		return
	end

	isStoreOpen = false
	cancelTween(currentOverlayTween)
	cancelTween(currentStoreTween)

	local overlayTween = TweenService:Create(storeOverlay, CLOSE_TWEEN_INFO, {
		BackgroundTransparency = OVERLAY_HIDDEN_TRANSPARENCY,
	})
	currentOverlayTween = overlayTween
	overlayTween.Completed:Connect(function()
		if currentOverlayTween == overlayTween and not isStoreOpen then
			currentOverlayTween = nil
			storeOverlay.Visible = false
		end
	end)
	overlayTween:Play()

	local storeTween = TweenService:Create(storeUi, CLOSE_TWEEN_INFO, {
		Size = CLOSED_SIZE,
		Position = closedPosition,
		BackgroundTransparency = 1,
	})
	currentStoreTween = storeTween
	storeTween.Completed:Connect(function()
		if currentStoreTween == storeTween and not isStoreOpen then
			currentStoreTween = nil
			storeUi.Visible = false
		end
	end)
	storeTween:Play()
end

local function toggleStore()
	if isStoreOpen then
		closeStore()
	else
		openStore()
	end
end

storeButton.Activated:Connect(toggleStore)
closeButton.Activated:Connect(closeStore)

storeOverlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closeStore()
	end
end)

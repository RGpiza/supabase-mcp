local StoreUIController = {}
local initialized = false
local moduleApi

function StoreUIController.Init(context)
	if initialized then
		return moduleApi
	end

	local ui = context.ui or {}
	local safeArea = ui.safeArea
	local topBar = ui.topBar
	local main = ui.main
	local toastArea = ui.toastArea
	local TweenService = context.TweenService
	local waitForChildWithTimeout = context.waitForChildWithTimeout
	local storeAnalyticsEvent = context.remotes and context.remotes.storeAnalyticsEvent
	local MarketplaceService = context.MarketplaceService
	local UserInputService = context.UserInputService
	local player = context.player

	if not (safeArea and topBar and player and TweenService and waitForChildWithTimeout and MarketplaceService and UserInputService) then
		return nil
	end

	local storeOverlay = waitForChildWithTimeout(safeArea, "StoreOverlay")
	local storeUi = waitForChildWithTimeout(safeArea, "StoreUI")
	local storeButton = waitForChildWithTimeout(topBar, "StoreButton")
	local storeHeader = storeUi and waitForChildWithTimeout(storeUi, "Header")
	local storeCloseButton = storeHeader and waitForChildWithTimeout(storeHeader, "Close")
	local storeBody = storeUi and waitForChildWithTimeout(storeUi, "Body")
	local gamepassesSection = storeBody and waitForChildWithTimeout(storeBody, "Gamepasses")
	local devProductsSection = storeBody and waitForChildWithTimeout(storeBody, "DevProducts")
	local gamepassList = gamepassesSection and waitForChildWithTimeout(gamepassesSection, "List")
	local devProductList = devProductsSection and waitForChildWithTimeout(devProductsSection, "List")
	local storeCards = {}

	if toastArea and toastArea:IsA("GuiObject") then
		if storeUi and storeUi:IsA("GuiObject") and storeUi.ZIndex <= toastArea.ZIndex then
			storeUi.ZIndex = toastArea.ZIndex + 5
		end

		if main and main:IsA("GuiObject") and main.ZIndex >= toastArea.ZIndex then
			main.ZIndex = math.max(0, toastArea.ZIndex - 5)
		end
	end

	local function determinePlatform()
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Mobile"
		end
		return "Desktop"
	end

	local analyticsPlatform = determinePlatform()
	local storeStateReported = nil

	local function sendStoreAnalytics(eventName, extra)
		if not storeAnalyticsEvent or typeof(eventName) ~= "string" then
			return
		end

		local payload = table.clone(extra or {})
		payload.Event = eventName
		payload.Platform = analyticsPlatform
		storeAnalyticsEvent:FireServer(payload)
	end

	local function trackStoreState(isOpen)
		if storeStateReported == isOpen then
			return
		end
		storeStateReported = isOpen

		local basePayload = {
			ItemName = "",
			ProductType = "",
			ProductId = 0,
		}

		if isOpen then
			sendStoreAnalytics("StoreOpened", basePayload)
		else
			sendStoreAnalytics("StoreClosed", basePayload)
		end
	end

	if not (storeOverlay and storeUi and storeButton and storeCloseButton) then
		return nil
	end

	local overlayVisibleTransparency = 0.45
	local overlayHiddenTransparency = 1
	local storeOpenSize = UDim2.fromScale(0.7, 0.78)
	local storeClosedSize = UDim2.fromScale(0.62, 0.7)
	local storeOpenPosition = storeUi.Position
	local storeClosedPosition = UDim2.new(storeOpenPosition.X.Scale, storeOpenPosition.X.Offset, storeOpenPosition.Y.Scale + 0.03, storeOpenPosition.Y.Offset)
	local openTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local closeTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	storeOverlay.Visible = false
	storeOverlay.BackgroundTransparency = overlayHiddenTransparency
	storeUi.Visible = false
	storeUi.Size = storeOpenSize
	storeUi.Position = storeOpenPosition
	storeUi.BackgroundTransparency = 0

	local isStoreOpen = false
	local currentOverlayTween = nil
	local currentStoreTween = nil

	local function cancelTween(tween)
		if tween then
			tween:Cancel()
		end
	end

	local BEST_VALUE_KEYWORD = "+1 Hour Boost"

	local function createBestValueRibbon(button)
		if not button or not button:IsA("GuiObject") then
			return nil
		end

		local existing = button:FindFirstChild("BestValueRibbon")
		if existing then
			return existing
		end

		local ribbon = Instance.new("TextLabel")
		ribbon.Name = "BestValueRibbon"
		ribbon.Text = "BEST VALUE"
		ribbon.Font = Enum.Font.GothamBold
		ribbon.TextSize = 14
		ribbon.TextWrapped = true
		ribbon.TextColor3 = Color3.new(0, 0, 0)
		ribbon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		ribbon.BorderSizePixel = 0
		ribbon.Size = UDim2.new(0, 100, 0, 24)
		ribbon.Position = UDim2.new(0, 8, 0, 8)
		ribbon.Rotation = -15
		ribbon.Active = false
		ribbon.Selectable = false
		ribbon.ZIndex = button.ZIndex + 5

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 2)
		padding.PaddingBottom = UDim.new(0, 2)
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 4)
		padding.Parent = ribbon

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = ribbon

		ribbon.Parent = button
		return ribbon
	end

	local function updateBestValueRibbon(cardInfo)
		if not cardInfo.isBestValue then
			return
		end

		local ribbon = cardInfo.bestValueRibbon
		if not ribbon then
			ribbon = createBestValueRibbon(cardInfo.button)
			cardInfo.bestValueRibbon = ribbon
		end

		if ribbon then
			ribbon.Visible = not cardInfo.owned
		end
	end

	local function setOwnedState(cardInfo, owned)
		if not cardInfo.button then
			return
		end

		cardInfo.owned = owned
		if owned then
			cardInfo.button.Text = "Owned"
			cardInfo.button.Active = false
			cardInfo.button.AutoButtonColor = false
			if cardInfo.dimColor then
				cardInfo.button.BackgroundColor3 = cardInfo.dimColor
			end
		else
			cardInfo.button.Text = cardInfo.defaultText
			cardInfo.button.Active = cardInfo.defaultActive
			cardInfo.button.AutoButtonColor = cardInfo.defaultAutoButtonColor
			cardInfo.button.BackgroundColor3 = cardInfo.defaultColor
		end

		updateBestValueRibbon(cardInfo)
	end

	local function buildItemPayload(cardInfo)
		return {
			ItemName = tostring(cardInfo.button and cardInfo.button.Text or ""),
			ProductType = tostring(cardInfo.productType or ""),
			ProductId = typeof(cardInfo.productId) == "number" and cardInfo.productId or 0,
		}
	end

	local function registerCard(button)
		if not button or not button:IsA("TextButton") then
			return
		end

		local productType = button:GetAttribute("ProductType")
		local productIdAttribute = button:GetAttribute("ProductId")
		local productId = nil

		if typeof(productIdAttribute) == "number" then
			productId = productIdAttribute
		elseif typeof(productIdAttribute) == "string" then
			productId = tonumber(productIdAttribute)
		end

		local cardInfo = {
			button = button,
			productType = typeof(productType) == "string" and productType or nil,
			productId = productId,
			defaultText = button.Text,
			defaultColor = button.BackgroundColor3,
			defaultAutoButtonColor = button.AutoButtonColor,
			defaultActive = button.Active,
			dimColor = Color3.new(
				math.clamp(button.BackgroundColor3.R * 0.6, 0, 1),
				math.clamp(button.BackgroundColor3.G * 0.6, 0, 1),
				math.clamp(button.BackgroundColor3.B * 0.6, 0, 1)
			),
		}

		local buttonText = button.Text or ""
		cardInfo.isBestValue = string.find(buttonText, BEST_VALUE_KEYWORD, 1, true) ~= nil
		if cardInfo.isBestValue then
			cardInfo.bestValueRibbon = createBestValueRibbon(button)
			updateBestValueRibbon(cardInfo)
		end

		button.Activated:Connect(function()
			sendStoreAnalytics("ItemClicked", buildItemPayload(cardInfo))

			local productTypeLower = typeof(cardInfo.productType) == "string" and string.lower(cardInfo.productType) or ""
			if productTypeLower == "gamepass" and cardInfo.owned then
				return
			end

			if typeof(cardInfo.productId) ~= "number" then
				return
			end

			sendStoreAnalytics("PurchasePromptShown", buildItemPayload(cardInfo))

			if productTypeLower == "gamepass" then
				MarketplaceService:PromptGamePassPurchase(player, cardInfo.productId)
			elseif productTypeLower == "devproduct" then
				MarketplaceService:PromptProductPurchase(player, cardInfo.productId)
			end
		end)

		table.insert(storeCards, cardInfo)
	end

	local function registerCardsUnder(parent)
		if not parent then
			return
		end

		for _, descendant in ipairs(parent:GetDescendants()) do
			if descendant:IsA("TextButton") then
				registerCard(descendant)
			end
		end
	end

	registerCardsUnder(gamepassList)
	registerCardsUnder(devProductList)

	local function refreshGamepassOwnership()
		for _, cardInfo in ipairs(storeCards) do
			local productTypeLower = typeof(cardInfo.productType) == "string" and string.lower(cardInfo.productType) or ""
			if productTypeLower == "gamepass" and typeof(cardInfo.productId) == "number" then
				task.spawn(function(info)
					local ok, owned = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.productId)
					end)

					if ok then
						setOwnedState(info, owned == true)
					end
				end, cardInfo)
			end
		end
	end

	local function openStore()
		if isStoreOpen then
			return
		end

		isStoreOpen = true
		cancelTween(currentOverlayTween)
		currentOverlayTween = nil
		cancelTween(currentStoreTween)
		currentStoreTween = nil

		storeOverlay.Visible = true
		storeOverlay.BackgroundTransparency = overlayHiddenTransparency
		storeUi.Visible = true
		storeUi.Size = storeClosedSize
		storeUi.Position = storeClosedPosition
		storeUi.BackgroundTransparency = 1

		local overlayTween = TweenService:Create(storeOverlay, openTweenInfo, {
			BackgroundTransparency = overlayVisibleTransparency,
		})
		currentOverlayTween = overlayTween
		overlayTween.Completed:Connect(function()
			if currentOverlayTween == overlayTween then
				currentOverlayTween = nil
			end
		end)
		overlayTween:Play()

		local uiTween = TweenService:Create(storeUi, openTweenInfo, {
			Size = storeOpenSize,
			Position = storeOpenPosition,
			BackgroundTransparency = 0,
		})
		currentStoreTween = uiTween
		uiTween.Completed:Connect(function()
			if currentStoreTween == uiTween then
				currentStoreTween = nil
			end
		end)
		uiTween:Play()

		refreshGamepassOwnership()
		trackStoreState(true)
	end

	local function closeStore()
		if not storeUi.Visible then
			storeOverlay.Visible = false
			storeOverlay.BackgroundTransparency = overlayHiddenTransparency
			isStoreOpen = false
			trackStoreState(false)
			storeUi.Size = storeOpenSize
			storeUi.Position = storeOpenPosition
			storeUi.BackgroundTransparency = 0
			return
		end

		isStoreOpen = false
		trackStoreState(false)
		cancelTween(currentOverlayTween)
		currentOverlayTween = nil
		cancelTween(currentStoreTween)
		currentStoreTween = nil

		local overlayTween = TweenService:Create(storeOverlay, closeTweenInfo, {
			BackgroundTransparency = overlayHiddenTransparency,
		})
		currentOverlayTween = overlayTween
		overlayTween.Completed:Connect(function()
			if currentOverlayTween == overlayTween then
				currentOverlayTween = nil
			end
			if not isStoreOpen then
				storeOverlay.Visible = false
			end
		end)
		overlayTween:Play()

		local uiTween = TweenService:Create(storeUi, closeTweenInfo, {
			Size = storeClosedSize,
			Position = storeClosedPosition,
			BackgroundTransparency = 1,
		})
		currentStoreTween = uiTween
		uiTween.Completed:Connect(function()
			if currentStoreTween == uiTween then
				currentStoreTween = nil
			end
			if not isStoreOpen then
				storeUi.Visible = false
				storeUi.Size = storeOpenSize
				storeUi.Position = storeOpenPosition
				storeUi.BackgroundTransparency = 0
			end
		end)
		uiTween:Play()
	end

	local function toggleStore()
		if isStoreOpen then
			closeStore()
		else
			openStore()
		end
	end

	if storeButton and storeButton:IsA("GuiButton") then
		storeButton.Activated:Connect(toggleStore)
	end

	if storeCloseButton and storeCloseButton:IsA("GuiButton") then
		storeCloseButton.Activated:Connect(closeStore)
	end

	if storeOverlay and storeOverlay:IsA("GuiButton") then
		storeOverlay.Activated:Connect(closeStore)
	end

	if storeOverlay and storeOverlay:IsA("GuiObject") then
		storeOverlay.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				closeStore()
			end
		end)
	end

	moduleApi = {
		RefreshGamepassOwnership = refreshGamepassOwnership,
	}
	initialized = true

	return moduleApi
end

return StoreUIController

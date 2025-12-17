local ToastController = {}
local initialized = false
local moduleApi

function ToastController.Init(context)
	if initialized then
		return moduleApi
	end

	local ui = context.ui or {}
	local toastArea = ui.toastArea
	local safeArea = ui.safeArea
	local root = ui.root
	local TweenService = context.TweenService
	local NumberFormatter = context.NumberFormatter
	local offlinePreviewEvent = context.remotes and context.remotes.offlinePreviewEvent

	if not (toastArea and safeArea and root and TweenService and NumberFormatter) then
		return nil
	end

	local clientReady = context.IsClientReady and context.IsClientReady() == true
	local onClientReady = context.OnClientReady

	local pendingOfflinePreviewPayloads = {}
	local offlineUiReady = false
	local processOfflinePreviewPayload
	local pendingClientReadyPayload = nil

	local function queueOfflinePreview(payload)
		table.insert(pendingOfflinePreviewPayloads, payload)
	end

	local function flushOfflinePreviewQueue()
		if not offlineUiReady or not clientReady or #pendingOfflinePreviewPayloads == 0 then
			return
		end

		local queued = table.clone(pendingOfflinePreviewPayloads)
		table.clear(pendingOfflinePreviewPayloads)

		for _, payload in ipairs(queued) do
			processOfflinePreviewPayload(payload)
		end
	end

	local toastLayout = toastArea and toastArea:FindFirstChildWhichIsA("UIListLayout")
	if toastLayout then
		toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
		toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	end

	if toastArea and toastArea:IsA("GuiObject") then
		toastArea.Visible = true
		toastArea.ZIndex = math.max(toastArea.ZIndex, 40)
		toastArea.Active = false
	end

	local offlineToastTemplate
	local offlineToastTargetSize
	local offlineToastSequence = 0
	local activeOfflineToasts = {}
	local MAX_OFFLINE_TOASTS = 3
	local OFFLINE_TOAST_LIFETIME = 4.5

	local function findDescriptionLabel(toast)
		if not toast then
			return nil
		end

		local description = toast:FindFirstChild("Description")
		if description and description:IsA("TextLabel") then
			return description
		end

		for _, descendant in ipairs(toast:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				return descendant
			end
		end

		return nil
	end

	local function ensureBoostBadge(frame)
		if not frame then
			return nil
		end

		local badge = frame:FindFirstChild("BoostBadge")
		if badge and badge:IsA("TextLabel") then
			return badge
		end

		badge = Instance.new("TextLabel")
		badge.Name = "BoostBadge"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -8, 0, 8)
		badge.Size = UDim2.new(0, 130, 0, 24)
		badge.BackgroundColor3 = Color3.fromRGB(255, 214, 102)
		badge.BackgroundTransparency = 0.05
		badge.TextColor3 = Color3.fromRGB(40, 30, 10)
		badge.Font = Enum.Font.GothamBold
		badge.TextSize = 12
		badge.Text = "BOOST APPLIED"
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.TextYAlignment = Enum.TextYAlignment.Center
		badge.Visible = false
		if frame:IsA("GuiObject") then
			badge.ZIndex = frame.ZIndex + 1
		else
			badge.ZIndex = 2
		end
		badge.Parent = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = badge

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.2
		stroke.Parent = badge

		return badge
	end

	local function resolveOfflineToastTemplate()
		if offlineToastTemplate and offlineToastTemplate.Parent then
			return offlineToastTemplate
		end

		local containers = { toastArea, safeArea, root }
		for _, container in ipairs(containers) do
			if container then
				local candidate = container:FindFirstChild("OfflineToast", true)
				if candidate then
					offlineToastTemplate = candidate
					if offlineToastTemplate:IsA("GuiObject") then
						offlineToastTargetSize = offlineToastTemplate.Size
						offlineToastTemplate.Visible = false
					end
					ensureBoostBadge(offlineToastTemplate)
					return offlineToastTemplate
				end
			end
		end

		return nil
	end

	local function playToastIntro(toast, descriptionLabel)
		if not toast then
			return
		end

		local finalSize = offlineToastTargetSize
		if toast:IsA("GuiObject") then
			if not finalSize then
				finalSize = toast.Size
				offlineToastTargetSize = finalSize
			end
			toast.Size = UDim2.new(finalSize.X.Scale, finalSize.X.Offset, 0, 0)
			TweenService:Create(
				toast,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = finalSize }
			):Play()
		end

		if descriptionLabel then
			descriptionLabel.TextTransparency = 1
			TweenService:Create(
				descriptionLabel,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ TextTransparency = 0 }
			):Play()
		end
	end

	local function removeToastInstance(toast, immediate)
		if not toast or toast:GetAttribute("OfflineToastRemoving") then
			return
		end

		toast:SetAttribute("OfflineToastRemoving", true)

		for i = #activeOfflineToasts, 1, -1 do
			if activeOfflineToasts[i] == toast then
				table.remove(activeOfflineToasts, i)
				break
			end
		end

		local function destroyToast()
			if toast then
				toast:Destroy()
			end
		end

		if immediate or not toast:IsA("GuiObject") then
			destroyToast()
			return
		end

		local targetSize = offlineToastTargetSize or toast.Size
		local collapseSize = UDim2.new(targetSize.X.Scale, targetSize.X.Offset, 0, 0)

		local shrinkTween = TweenService:Create(
			toast,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = collapseSize }
		)
		shrinkTween.Completed:Connect(destroyToast)
		shrinkTween:Play()

		local descriptionLabel = findDescriptionLabel(toast)
		if descriptionLabel then
			TweenService:Create(
				descriptionLabel,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			):Play()
		end

		local badge = toast:FindFirstChild("BoostBadge")
		if badge and badge:IsA("GuiObject") then
			TweenService:Create(
				badge,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					TextTransparency = 1,
					BackgroundTransparency = 1,
				}
			):Play()
		end
	end

	local function enforceToastLimit()
		while #activeOfflineToasts > MAX_OFFLINE_TOASTS do
			local oldest = activeOfflineToasts[#activeOfflineToasts]
			removeToastInstance(oldest, true)
		end
	end

	local function spawnOfflineToast()
		if not toastArea then
			return nil, nil
		end

		local template = resolveOfflineToastTemplate()
		if not template then
			return nil, nil
		end

		local toast = template:Clone()
		toast.Name = "OfflineToast"
		toast.Visible = true
		toast.Active = false
		if toastArea:IsA("GuiObject") then
			toast.ZIndex = math.max(toast.ZIndex, toastArea.ZIndex + 1)
			toastArea.Visible = true
		end
		offlineToastSequence += 1
		toast.LayoutOrder = -offlineToastSequence
		toast.Parent = toastArea

		local descriptionLabel = findDescriptionLabel(toast)
		return toast, descriptionLabel
	end

	processOfflinePreviewPayload = function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local totalAmount = tonumber(payload.totalAmount or payload.amount or payload.Amount)
		if not totalAmount or totalAmount <= 0 then
			return
		end

		local toastFrame, descriptionLabel = spawnOfflineToast()
		if not toastFrame or not descriptionLabel then
			return
		end

		local baseAmount = tonumber(payload.baseAmount) or 0
		local boostedAmount = tonumber(payload.boostedAmount) or math.max(0, totalAmount - baseAmount)
		local prestigeMultiplier = tonumber(payload.prestigeMultiplier)

		local lines = {}
		table.insert(lines, string.format("+%s Data while away", NumberFormatter.format(totalAmount)))
		if boostedAmount > 0 then
			table.insert(
				lines,
				string.format(
					"Base: +%s   Boosted: +%s",
					NumberFormatter.format(math.max(baseAmount, 0)),
					NumberFormatter.format(boostedAmount)
				)
			)
		end
		if prestigeMultiplier and prestigeMultiplier > 1 then
			table.insert(lines, string.format("Prestige Bonus: x%.2f", prestigeMultiplier))
		end
		descriptionLabel.Text = table.concat(lines, "\n")

		local hadBoostsValue = payload.hadBoosts
		if typeof(hadBoostsValue) ~= "boolean" then
			hadBoostsValue = payload.HadBoosts == true
		end
		local boostApplied = hadBoostsValue == true
		toastFrame:SetAttribute("HadOfflineBoosts", boostApplied)

		local badge = ensureBoostBadge(toastFrame)
		if badge then
			badge.Visible = boostApplied
			if not boostApplied then
				badge.TextTransparency = 0
				badge.BackgroundTransparency = 0.05
			end
		end

		playToastIntro(toastFrame, descriptionLabel)

		table.insert(activeOfflineToasts, 1, toastFrame)
		enforceToastLimit()

		task.delay(OFFLINE_TOAST_LIFETIME, function()
			removeToastInstance(toastFrame)
		end)
	end

	local function handleOfflinePreview(payload)
		if not clientReady then
			pendingClientReadyPayload = payload
			return
		end

		if not offlineUiReady then
			queueOfflinePreview(payload)
			return
		end

		processOfflinePreviewPayload(payload)
	end

	if toastArea and toastArea:IsA("GuiObject") then
		task.spawn(function()
			while true do
				local template = resolveOfflineToastTemplate()
				if template then
					offlineUiReady = true
					flushOfflinePreviewQueue()
					return
				end

				task.wait(0.1)
			end
		end)
	end

	if offlinePreviewEvent then
		offlinePreviewEvent.OnClientEvent:Connect(handleOfflinePreview)
	end

	if onClientReady then
		onClientReady(function()
			clientReady = true

			if pendingClientReadyPayload then
				local payload = pendingClientReadyPayload
				pendingClientReadyPayload = nil
				handleOfflinePreview(payload)
			end

			flushOfflinePreviewQueue()
		end)
	else
		clientReady = true
	end

	if clientReady then
		if pendingClientReadyPayload then
			local payload = pendingClientReadyPayload
			pendingClientReadyPayload = nil
			handleOfflinePreview(payload)
		end
		flushOfflinePreviewQueue()
	end

	local toastCooldown = false

	local function showToast(message, textColor)
		if not toastArea then
			return
		end

		if toastCooldown then
			return
		end

		local toast = Instance.new("TextLabel")
		toast.Name = "Toast"
		toast.BackgroundTransparency = 1
		toast.TextColor3 = textColor or Color3.new(1, 1, 1)
		toast.TextStrokeTransparency = 0.5
		toast.Font = Enum.Font.GothamBold
		toast.TextSize = 20
		toast.Text = message
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, 0)
		toast.Parent = toastArea

		toast.TextTransparency = 1
		toast.Visible = true
		toastCooldown = true

		local fadeIn = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
		local fadeOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })

		fadeIn.Completed:Connect(function()
			task.delay(1.2, function()
				fadeOut:Play()
			end)
		end)

		fadeOut.Completed:Connect(function()
			toastCooldown = false
			toast:Destroy()
		end)

		fadeIn:Play()
	end

	moduleApi = {
		ShowToast = showToast,
	}
	initialized = true

	return moduleApi
end

return ToastController

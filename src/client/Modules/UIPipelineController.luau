local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPipelineController = {}

local currentToken = 0
local purchaseBinder = nil
local purchaseBinderReady = false

local function newToken()
	currentToken += 1
	return currentToken
end

local function getPlayerGui()
	local player = Players.LocalPlayer
	return player and player:FindFirstChild("PlayerGui")
end

local UIPaths = require(script.Parent:FindFirstChild("UIPaths"))

local function getTerminalUi(playerGui)
	return UIPaths.GetTerminalUI(playerGui)
end

local function getContainers(terminalUi)
	return {
		CPU = UIPaths.GetCardsCPU(terminalUi),
		RAM = UIPaths.GetCardsRAM(terminalUi),
		STORAGE = UIPaths.GetCardsSTO(terminalUi),
	}
end

local function getTemplate(playerGui)
	return playerGui and playerGui:FindFirstChild("UpgradeCardTemplate")
end

local function ensureLayout(container)
	if not container or not container:IsA("ScrollingFrame") then
		return
	end
	local layout = container:FindFirstChildWhichIsA("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = container
	end
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
end

local function purgeNonToken(container, token)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame")
			and not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UIGridLayout")
			and child.Name ~= "AutoBuyButton"
		then
			if child:GetAttribute("UIPipelineToken") ~= token then
				child:Destroy()
			end
		end
	end
end

local function resolvePurchaseBinder()
	if purchaseBinderReady then
		return purchaseBinder
	end
	purchaseBinderReady = true
	local modulesFolder = script.Parent
	local binderScript = modulesFolder and modulesFolder:FindFirstChild("PurchaseHandlerBinder")
	if binderScript then
		local ok, mod = pcall(function()
			return require(binderScript)
		end)
		if ok and type(mod) == "table" then
			purchaseBinder = mod
		end
	end
	if purchaseBinder and type(purchaseBinder.Init) == "function" then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local purchaseRemote = remotes and remotes:FindFirstChild("PurchaseUpgrade")
		purchaseBinder.Init({
			purchaseUpgradeEvent = purchaseRemote,
			PURCHASE_SETTINGS = {
				debounce = 0.2,
				longPressDuration = 0.5,
				activationSuppress = 0.1,
			},
		})
	end
	return purchaseBinder
end

local function bindButton(card, upgradeId)
	local button = card:FindFirstChild("CardBuyButton", true) or card:FindFirstChild("BuyButton", true)
	if not (button and button:IsA("GuiButton")) then
		return false
	end
	if button:GetAttribute("Bound") == true then
		return false
	end
	button:SetAttribute("Bound", true)
	local binder = resolvePurchaseBinder()
	if binder and type(binder.Bind) == "function" then
		binder.Bind(button, upgradeId)
		return true
	end
	button.Activated:Connect(function()
		warn("Purchase not wired", upgradeId)
	end)
	return true
end

local function applyCardText(card, def)
	local title = card:FindFirstChild("CardTitle") or card:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = def.title or def.name or def.id or ""
	end
	local desc = card:FindFirstChild("CardDesc") or card:FindFirstChild("Description")
	if desc and desc:IsA("TextLabel") then
		desc.Text = def.desc or def.description or ""
	end
	local cost = card:FindFirstChild("CardCostLabel") or card:FindFirstChild("Cost")
	if cost and cost:IsA("TextLabel") then
		cost.Text = def.cost and tostring(def.cost) or ""
	end
end

local function renderCategory(list, container, template, token, prefix)
	if not container or not template then
		return 0
	end
	local count = 0
	for i, def in ipairs(list) do
		local id = def.id or (prefix .. tostring(i))
		local card = template:Clone()
		card.Name = id
		card.Parent = container
		card.Visible = true
		card.LayoutOrder = i
		card:SetAttribute("UIPipelineToken", token)
		card:SetAttribute("UpgradeId", id)
		applyCardText(card, def)
		if not card:GetAttribute("Bound") then
			card:SetAttribute("Bound", true)
			bindButton(card, id)
		end
		count += 1
	end
	return count
end

local function countBoundButtons(containers)
	local count = 0
	for _, container in pairs(containers) do
		if container then
			for _, desc in ipairs(container:GetDescendants()) do
				if desc:IsA("GuiButton") and desc:GetAttribute("Bound") == true then
					count += 1
				end
			end
		end
	end
	return count
end

function UIPipelineController.RenderFromPayload(payload)
	local playerGui = getPlayerGui()
	if not playerGui then
		return false
	end
	playerGui:SetAttribute("UIPipelineAuthoritative", true)
	local terminalUi = getTerminalUi(playerGui)
	if not terminalUi then
		return false
	end

	local template = getTemplate(playerGui)
	if not template then
		return false
	end

	local containers = getContainers(terminalUi)
	if not (containers.CPU and containers.RAM and containers.STORAGE) then
		return false
	end

	ensureLayout(containers.CPU)
	ensureLayout(containers.RAM)
	ensureLayout(containers.STORAGE)

	local token = newToken()

	purgeNonToken(containers.CPU, token)
	purgeNonToken(containers.RAM, token)
	purgeNonToken(containers.STORAGE, token)

	local cpuList = (payload and payload.CPU) or {}
	local ramList = (payload and payload.RAM) or {}
	local stoList = (payload and payload.STORAGE) or {}

	local cpuCount = renderCategory(cpuList, containers.CPU, template, token, "cpu_")
	local ramCount = renderCategory(ramList, containers.RAM, template, token, "ram_")
	local stoCount = renderCategory(stoList, containers.STORAGE, template, token, "sto_")

	purgeNonToken(containers.CPU, token)
	purgeNonToken(containers.RAM, token)
	purgeNonToken(containers.STORAGE, token)

	local boundButtons = countBoundButtons(containers)
	print(("[UIPipeline] token=%d CPU=%d RAM=%d STO=%d boundButtons=%d"):format(
		token,
		cpuCount,
		ramCount,
		stoCount,
		boundButtons
	))

	return true
end

return UIPipelineController

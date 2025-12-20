local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeController = {}

local signals
local uiState
local lastPayloadHash = nil
local pendingPayload = nil
local purchaseBinder = nil
local purchaseBinderReady = false

local function ensurePurchaseBinder()
	if purchaseBinderReady then
		return purchaseBinder
	end
	purchaseBinderReady = true
	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("Client")
	local clientModules = clientRoot and clientRoot:FindFirstChild("Modules")
	local binderScript = clientModules and clientModules:FindFirstChild("PurchaseHandlerBinder")
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

local function getContainers(terminalUi)
	local root = terminalUi and terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	local cpu = columns and columns:FindFirstChild("CPUColumn")
	local ram = columns and columns:FindFirstChild("RAMColumn")
	local sto = columns and columns:FindFirstChild("STOColumn")
	return {
		CPU = cpu and cpu:FindFirstChild("Cards_CPU"),
		RAM = ram and ram:FindFirstChild("Cards_RAM"),
		STORAGE = sto and sto:FindFirstChild("Cards_STORAGE"),
	}
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

local function purgeContainer(container, token)
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
			if child:GetAttribute("AuthoritativeToken") ~= token then
				child:Destroy()
			end
		end
	end
end

local function bindButton(card, upgradeId)
	local button = card:FindFirstChild("CardBuyButton", true) or card:FindFirstChild("BuyButton", true)
	if not (button and button:IsA("GuiButton")) then
		return false
	end
	if button:GetAttribute("Bound") == true or card:GetAttribute("Bound") == true then
		return false
	end
	button:SetAttribute("Bound", true)
	card:SetAttribute("Bound", true)
	local binder = ensurePurchaseBinder()
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
		card:SetAttribute("AuthoritativeToken", token)
		card:SetAttribute("UpgradeId", id)
		applyCardText(card, def)
		bindButton(card, id)
		count += 1
	end
	return count
end

local function computePayloadHash(payload)
	if type(payload) ~= "table" then
		return ""
	end
	local function hashList(list)
		if type(list) ~= "table" then
			return ""
		end
		local parts = table.create(#list)
		for _, entry in ipairs(list) do
			local id = entry.id or ""
			local cost = entry.cost or ""
			local rank = entry.rank or ""
			parts[#parts + 1] = tostring(id) .. ":" .. tostring(cost) .. ":" .. tostring(rank)
		end
		return table.concat(parts, "|")
	end
	return table.concat({
		hashList(payload.CPU),
		hashList(payload.RAM),
		hashList(payload.STORAGE),
	}, "||")
end

local function render(payload)
	if not uiState or not uiState.TerminalUI or not uiState.Template then
		return
	end

	local playerGui = uiState.PlayerGui
	if playerGui then
		playerGui:SetAttribute("AuthoritativeUpgrades", true)
		playerGui:SetAttribute(
			"AuthoritativeUpgradesToken",
			(playerGui:GetAttribute("AuthoritativeUpgradesToken") or 0) + 1
		)
	end
	local token = playerGui and playerGui:GetAttribute("AuthoritativeUpgradesToken")

	local containers = getContainers(uiState.TerminalUI)
	if not (containers.CPU and containers.RAM and containers.STORAGE) then
		return
	end

	ensureLayout(containers.CPU)
	ensureLayout(containers.RAM)
	ensureLayout(containers.STORAGE)

	purgeContainer(containers.CPU, token)
	purgeContainer(containers.RAM, token)
	purgeContainer(containers.STORAGE, token)

	local cpuList = payload and payload.CPU or {}
	local ramList = payload and payload.RAM or {}
	local stoList = payload and payload.STORAGE or {}

	local cpuCount = renderCategory(cpuList, containers.CPU, uiState.Template, token, "cpu_")
	local ramCount = renderCategory(ramList, containers.RAM, uiState.Template, token, "ram_")
	local stoCount = renderCategory(stoList, containers.STORAGE, uiState.Template, token, "sto_")

	purgeContainer(containers.CPU, token)
	purgeContainer(containers.RAM, token)
	purgeContainer(containers.STORAGE, token)

	print(("[UpgradeController] Rendered CPU=%d RAM=%d STORAGE=%d"):format(cpuCount, ramCount, stoCount))
	signals.UpgradesRendered:Fire({
		CPU = cpuCount,
		RAM = ramCount,
		STORAGE = stoCount,
	})
end

function UpgradeController.Init(context)
	signals = context.Signals
	signals.UIReady:Connect(function(ui)
		uiState = ui
		if pendingPayload then
			local payload = pendingPayload
			pendingPayload = nil
			render(payload)
		end
	end)
	signals.PayloadReceived:Connect(function(payload)
		local hash = computePayloadHash(payload)
		if hash ~= "" and hash == lastPayloadHash then
			return
		end
		lastPayloadHash = hash
		if uiState then
			render(payload)
		else
			pendingPayload = payload
		end
	end)
end

function UpgradeController.Start()
	local ui = uiState
	if ui and ui.Payload then
		render(ui.Payload)
	end
end

return UpgradeController

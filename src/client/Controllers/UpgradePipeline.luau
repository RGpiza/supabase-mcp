local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local services = script.Parent.Parent:FindFirstChild("Services")
local modules = script.Parent.Parent:FindFirstChild("Modules")
local UILoader = services and services:FindFirstChild("UILoader")
local PurchaseHandlerBinder = modules and modules:FindFirstChild("PurchaseHandlerBinder")
local UIPaths = modules and modules:FindFirstChild("UIPaths")
if not (UILoader and PurchaseHandlerBinder) then
	return {
		Init = function() end,
	}
end

UILoader = require(UILoader)
PurchaseHandlerBinder = require(PurchaseHandlerBinder)
UIPaths = UIPaths and require(UIPaths) or nil

local UpgradePipeline = {}

local started = false
local rendered = false
local tokenCounter = 0
local requestSyncConnected = false

local function nextToken()
	tokenCounter += 1
	return tokenCounter
end

local function getContainers(terminalUi)
	if not (UIPaths and terminalUi) then
		return nil
	end
	return {
		CPU = UIPaths.GetCardsCPU(terminalUi),
		RAM = UIPaths.GetCardsRAM(terminalUi),
		STORAGE = UIPaths.GetCardsSTO(terminalUi),
	}
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
			if child:GetAttribute("UpgradePipelineToken") ~= token then
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
	PurchaseHandlerBinder.Bind(button, upgradeId)
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
	if not container then
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
		card:SetAttribute("UpgradePipelineToken", token)
		card:SetAttribute("UpgradeId", id)
		applyCardText(card, def)
		bindButton(card, id)
		count += 1
	end
	return count
end

local function normalizePayload(payload)
	if type(payload) ~= "table" then
		return {}, {}, {}
	end
	if type(payload.CPU) == "table" or type(payload.RAM) == "table" or type(payload.STORAGE) == "table" then
		return payload.CPU or {}, payload.RAM or {}, payload.STORAGE or {}
	end
	local cpu, ram, sto = {}, {}, {}
	local upgrades = payload.upgrades
	if type(upgrades) == "table" then
		for _, def in ipairs(upgrades) do
			local branch = def.branch or def.category or "CPU"
			if branch == "CPU" then
				table.insert(cpu, def)
			elseif branch == "RAM" then
				table.insert(ram, def)
			elseif branch == "STORAGE" then
				table.insert(sto, def)
			end
		end
	end
	return cpu, ram, sto
end

local function handlePayload(terminalUi, template, payload)
	if rendered then
		return
	end
	local containers = getContainers(terminalUi)
	if not (containers.CPU and containers.RAM and containers.STORAGE) then
		warn("[UpgradePipeline] Missing cards containers; aborting render")
		return
	end
	local token = nextToken()
	purgeContainer(containers.CPU, token)
	purgeContainer(containers.RAM, token)
	purgeContainer(containers.STORAGE, token)

	local cpuList, ramList, stoList = normalizePayload(payload)
	renderCategory(cpuList, containers.CPU, template, token, "cpu_")
	renderCategory(ramList, containers.RAM, template, token, "ram_")
	renderCategory(stoList, containers.STORAGE, template, token, "sto_")

	purgeContainer(containers.CPU, token)
	purgeContainer(containers.RAM, token)
	purgeContainer(containers.STORAGE, token)

	rendered = true
	terminalUi:SetAttribute("UI_READY", true)
	print("[UpgradePipeline] UI_READY")
end

local function connectRequestSync(terminalUi, template)
	if requestSyncConnected then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local requestSync = remotes and remotes:FindFirstChild("RequestSync")
	if not requestSync then
		return
	end
	requestSyncConnected = true
	if requestSync:IsA("RemoteEvent") then
		requestSync.OnClientEvent:Connect(function(payload)
			handlePayload(terminalUi, template, payload)
		end)
	elseif requestSync:IsA("RemoteFunction") then
		local ok, payload = pcall(function()
			return requestSync:InvokeServer()
		end)
		if ok then
			handlePayload(terminalUi, template, payload)
		end
	end
end

function UpgradePipeline.Init()
	if started then
		return
	end
	started = true

	local terminalUi = UILoader.WaitForTerminalUI()
	if not terminalUi then
		return
	end
	local playerGui = terminalUi.Parent
	local template = playerGui and playerGui:FindFirstChild("UpgradeCardTemplate")
	if not template then
		return
	end

	PurchaseHandlerBinder.Init({
		purchaseUpgradeEvent = (ReplicatedStorage:FindFirstChild("Remotes") or {}):FindFirstChild("PurchaseUpgrade"),
		PURCHASE_SETTINGS = {
			debounce = 0.2,
			longPressDuration = 0.5,
			activationSuppress = 0.1,
		},
	})

	connectRequestSync(terminalUi, template)
	ReplicatedStorage.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "RequestSync" then
			connectRequestSync(terminalUi, template)
		end
	end)
end

return UpgradePipeline

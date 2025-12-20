local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPaths = require(script.Parent:FindFirstChild("UIPaths"))

local clientRoot = ReplicatedStorage:FindFirstChild("Client")
if clientRoot and clientRoot:FindFirstChild("Framework") then
	return {
		Render = function() end,
	}
end

local UpgradeRenderer = {}

function UpgradeRenderer.Init(_terminalUi)
	return true
end

local function getContainers()
	local terminalUi = UIPaths.get()
	local root = terminalUi and terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	local cpuCards = UIPaths.GetCardsCPU(terminalUi)
	local ramCards = UIPaths.GetCardsRAM(terminalUi)
	local stoCards = UIPaths.GetCardsSTO(terminalUi)
	return terminalUi, main, columns, cpuCards, ramCards, stoCards
end

local function resolveTemplate()
	return UIPaths.GetTemplate()
end

local function clearContainer(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") and child:GetAttribute("__UpgradeCard") == true then
			child:Destroy()
		end
	end
end

local function hasUpgradeId(container, upgradeId)
	if not container or upgradeId == nil then
		return false
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") and child:GetAttribute("UpgradeId") == upgradeId then
			return true
		end
	end
	return false
end

local function applyCanvasSize(container)
	if not container:IsA("ScrollingFrame") then
		return
	end
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = container:FindFirstChildWhichIsA("UIListLayout")
		or container:FindFirstChildWhichIsA("UIGridLayout")
	if not layout then
		return
	end
	local size = layout.AbsoluteContentSize
	container.CanvasSize = UDim2.fromOffset(size.X, size.Y)
end

local function forceVisibilityAndZIndex(terminalUi, main, columns, containers)
	if terminalUi and terminalUi:IsA("ScreenGui") then
		terminalUi.ZIndexBehavior = Enum.ZIndexBehavior.Global
		terminalUi.DisplayOrder = math.max(terminalUi.DisplayOrder, 1000)
	end
	if main and main:IsA("GuiObject") then
		main.ClipsDescendants = false
		main.Visible = true
	end
	if columns and columns:IsA("GuiObject") then
		columns.ClipsDescendants = false
		columns.Visible = true
	end

	for _, container in ipairs(containers) do
		if container and container:IsA("GuiObject") then
			container.Visible = true
			container.ZIndex = math.max(container.ZIndex, 40)
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("GuiObject") then
					child.Visible = true
					if child.Size.Y.Scale == 0 and child.Size.Y.Offset == 0 then
						child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, 110)
					end
					child.ZIndex = math.max(child.ZIndex, 50)
					for _, desc in ipairs(child:GetDescendants()) do
						if desc:IsA("GuiObject") then
							desc.Visible = true
							desc.ZIndex = math.max(desc.ZIndex, 51)
						end
					end
				end
			end
		end
	end
end

local function getUpgradeDefinitions(payload)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local upgradeConfig = shared and shared:FindFirstChild("UpgradeConfig")
	if upgradeConfig then
		local ok, module = pcall(function()
			return require(upgradeConfig)
		end)
		if ok and module and type(module.GetAllUpgrades) == "function" then
			return module.GetAllUpgrades()
		end
	end
	if payload and type(payload.definitions) == "table" then
		return payload.definitions
	end
	return nil
end

local function applyCard(card, def, state)
	card.Name = def.id
	card.Visible = true
	if card.Size.Y.Scale == 0 and card.Size.Y.Offset <= 1 then
		card.Size = UDim2.new(1, 0, 0, 110)
	end
	card:SetAttribute("UpgradeId", def.id)
	if typeof(def.baseCost) == "number" then
		card:SetAttribute("Cost", def.baseCost)
	end
	if def.requires and typeof(def.requires.storageTier) == "number" then
		card:SetAttribute("Tier", def.requires.storageTier)
	end
	if type(state) == "table" then
		if typeof(state.cost) == "number" then
			card:SetAttribute("Cost", state.cost)
		end
		if typeof(state.tier) == "number" then
			card:SetAttribute("Tier", state.tier)
		end
		if typeof(state.owned) == "boolean" then
			card:SetAttribute("Owned", state.owned)
		end
		if typeof(state.locked) == "boolean" then
			card:SetAttribute("Locked", state.locked)
		end
	end

	local title = card:FindFirstChild("Title") or card:FindFirstChild("CardTitle")
	if title and title:IsA("TextLabel") then
		title.Text = def.name or def.id
	end
	local description = card:FindFirstChild("Description") or card:FindFirstChild("CardDesc")
	if description and description:IsA("TextLabel") then
		description.Text = def.description or ""
	end
	local costLabel = card:FindFirstChild("Cost") or card:FindFirstChild("CardCostLabel")
	if costLabel and costLabel:IsA("TextLabel") then
		local costValue = card:GetAttribute("Cost")
		if typeof(costValue) == "number" then
			costLabel.Text = tostring(costValue)
		end
	end
	local ownedOverlay = card:FindFirstChild("OwnedOverlay") or card:FindFirstChild("Owned")
	if ownedOverlay and ownedOverlay:IsA("GuiObject") then
		ownedOverlay.Visible = card:GetAttribute("Owned") == true
	end
	local lockedOverlay = card:FindFirstChild("LockedOverlay") or card:FindFirstChild("Locked")
	if lockedOverlay and lockedOverlay:IsA("GuiObject") then
		lockedOverlay.Visible = card:GetAttribute("Locked") == true
	end
	local buyButton = card:FindFirstChild("BuyButton") or card:FindFirstChild("CardBuyButton")
	if buyButton and buyButton:IsA("GuiObject") then
		buyButton.Visible = not (card:GetAttribute("Owned") == true)
	end
end

local function resolveState(payload)
	if payload and type(payload.upgrades) == "table" then
		return payload.upgrades
	end
	return {}
end

local function getStateForUpgrade(state, upgradeId)
	local entry = state[upgradeId]
	if type(entry) == "table" then
		return entry
	end
	return nil
end

local function enforceStarterState(def, state)
	if not (def and def.id == "cpu_1") then
		return state
	end
	if type(state) ~= "table" then
		state = {}
	end
	state.locked = false
	state.owned = false
	state.cost = 0
	return state
end

local function renderStarterUpgrade(container, template, token)
	if not (container and template) then
		return false
	end
	if hasUpgradeId(container, "cpu_1") then
		return true
	end
	local def = {
		id = "cpu_1",
		name = "CPU Upgrade 1",
		description = "Starter upgrade",
		baseCost = 0,
		branch = "CPU",
	}
	local card = template:Clone()
	card.Parent = container
	card:SetAttribute("__UpgradeCard", true)
	card:SetAttribute("UpgradeId", def.id)
	card:SetAttribute("UpgradeCategory", "CPU")
	card:SetAttribute("AuthoritativeToken", token)
	applyCard(card, def, enforceStarterState(def, {}))
	return true
end

function UpgradeRenderer.Render(payload)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if playerGui and playerGui:GetAttribute("UIPipelineAuthoritative") == true then
		return false
	end
	if not playerGui then
		if not UpgradeRenderer._guardLogged then
			UpgradeRenderer._guardLogged = true
			warn("[UpgradeRenderer] PlayerGui missing; cannot render upgrades")
		end
		return false
	end
	if playerGui then
		playerGui:SetAttribute("AuthoritativeUpgrades", true)
		playerGui:SetAttribute(
			"AuthoritativeUpgradesToken",
			(playerGui:GetAttribute("AuthoritativeUpgradesToken") or 0) + 1
		)
	end
	local token = playerGui and playerGui:GetAttribute("AuthoritativeUpgradesToken")
	local terminalUi, main, columns, cpuCards, ramCards, stoCards = getContainers()
	if not terminalUi then
		if not UpgradeRenderer._guardLogged then
			UpgradeRenderer._guardLogged = true
			warn("[UpgradeRenderer] TerminalUI missing; cannot render upgrades")
		end
		return false
	end
	if not UIPaths.IsReady(terminalUi) or not (cpuCards and ramCards and stoCards) then
		if not UpgradeRenderer._guardLogged then
			UpgradeRenderer._guardLogged = true
			warn("[UpgradeRenderer] Cards containers missing; cannot render upgrades")
		end
		return false
	end

	local template = resolveTemplate()
	if not template then
		warn("[UpgradeRenderer] Missing UpgradeCardTemplate")
		return false
	end

	local defs = getUpgradeDefinitions(payload)
	if not defs then
		warn("[UpgradeRenderer] Missing upgrade definitions; rendering starter upgrade")
		clearContainer(cpuCards)
		clearContainer(ramCards)
		clearContainer(stoCards)
		renderStarterUpgrade(cpuCards, template, token)
		applyCanvasSize(cpuCards)
		applyCanvasSize(ramCards)
		applyCanvasSize(stoCards)
		forceVisibilityAndZIndex(terminalUi, main, columns, { cpuCards, ramCards, stoCards })
		return true
	end

	clearContainer(cpuCards)
	clearContainer(ramCards)
	clearContainer(stoCards)

	clearContainer(cpuCards)
	clearContainer(ramCards)
	clearContainer(stoCards)

	local state = resolveState(payload)
	local renderedCpu = 0
	local renderedRam = 0
	local renderedSto = 0

	for _, def in ipairs(defs) do
		local branch = def.branch == "CPU" and "CPU"
			or def.branch == "RAM" and "RAM"
			or def.branch == "STORAGE" and "STO"
			or "CPU"
		local target = branch == "CPU" and cpuCards
			or branch == "RAM" and ramCards
			or branch == "STO" and stoCards
			or cpuCards
		local card = template:Clone()
		card.Parent = target
		card:SetAttribute("__UpgradeCard", true)
		card:SetAttribute("UpgradeId", def.id)
		card:SetAttribute("UpgradeCategory", branch)
		card:SetAttribute("AuthoritativeToken", token)
		local upgradeState = getStateForUpgrade(state, def.id)
		upgradeState = enforceStarterState(def, upgradeState)
		applyCard(card, def, upgradeState)

		if def.branch == "CPU" then
			renderedCpu += 1
		elseif def.branch == "RAM" then
			renderedRam += 1
		elseif def.branch == "STORAGE" then
			renderedSto += 1
		end
	end

	local totalRendered = renderedCpu + renderedRam + renderedSto
	if totalRendered == 0 then
		warn("[UpgradeRenderer] No upgrades rendered (locked/missing data). Rendering starter upgrade.")
		renderStarterUpgrade(cpuCards, template, token)
		renderedCpu = math.max(renderedCpu, 1)
	end

	if totalRendered == 0 then
		local debugCard = template:Clone()
		debugCard.Parent = cpuCards
		debugCard.Visible = true
		debugCard.Size = UDim2.new(1, -12, 0, 110)
		debugCard.LayoutOrder = 1
		local title = debugCard:FindFirstChild("Title") or debugCard:FindFirstChild("CardTitle")
		if title and title:IsA("TextLabel") then
			title.Text = "DEBUG CARD"
		end
	end

	applyCanvasSize(cpuCards)
	applyCanvasSize(ramCards)
	applyCanvasSize(stoCards)
	forceVisibilityAndZIndex(terminalUi, main, columns, { cpuCards, ramCards, stoCards })

	if #cpuCards:GetChildren() == 0 then
		error("NO UPGRADE CARDS RENDERED — PIPELINE BROKEN")
	end

	print(('[UpgradeRenderer] Rendered CPU=%d RAM=%d STORAGE=%d'):format(renderedCpu, renderedRam, renderedSto))

	local binderModule = script.Parent and script.Parent:FindFirstChild("UpgradeBinder")
	local binder = binderModule and require(binderModule)
	if binder and type(binder.BindRenderedCards) == "function" then
		binder.BindRenderedCards(true, { cpuCards, ramCards, stoCards })
	end
	return true
end

return UpgradeRenderer

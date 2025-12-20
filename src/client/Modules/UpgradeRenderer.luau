local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeRenderer = {}

local function getContainers()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	local terminalUi = playerGui and playerGui:FindFirstChild("TerminalUI")
	local root = terminalUi and terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	local cpuColumn = columns and columns:FindFirstChild("CPUColumn")
	local ramColumn = columns and columns:FindFirstChild("RAMColumn")
	local stoColumn = columns and columns:FindFirstChild("STOColumn")
	local cpuCards = cpuColumn and cpuColumn:FindFirstChild("Cards_CPU")
	local ramCards = ramColumn and ramColumn:FindFirstChild("Cards_RAM")
	local stoCards = stoColumn and stoColumn:FindFirstChild("Cards_STORAGE")
	return cpuCards, ramCards, stoCards
end

local function resolveTemplate()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	return playerGui and playerGui:FindFirstChild("UpgradeCardTemplate")
end

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function applyCanvasSize(container)
	if not container:IsA("ScrollingFrame") then
		return
	end
	local layout = container:FindFirstChildWhichIsA("UIListLayout")
		or container:FindFirstChildWhichIsA("UIGridLayout")
	if not layout then
		return
	end
	local size = layout.AbsoluteContentSize
	container.CanvasSize = UDim2.fromOffset(size.X, size.Y)
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

function UpgradeRenderer.Render(payload)
	local cpuCards, ramCards, stoCards = getContainers()
	if not (cpuCards and ramCards and stoCards) then
		warn("[UpgradeRenderer] Missing upgrade containers")
		return
	end

	local template = resolveTemplate()
	if not template then
		warn("[UpgradeRenderer] Missing UpgradeCardTemplate")
		return
	end

	local defs = getUpgradeDefinitions(payload)
	if not defs then
		warn("[UpgradeRenderer] Missing upgrade definitions")
		return
	end

	clearContainer(cpuCards)
	clearContainer(ramCards)
	clearContainer(stoCards)

	local state = resolveState(payload)
	local renderedCpu = 0
	local renderedRam = 0
	local renderedSto = 0

	for _, def in ipairs(defs) do
		local target = def.branch == "CPU" and cpuCards
			or def.branch == "RAM" and ramCards
			or def.branch == "STORAGE" and stoCards
			or cpuCards
		local card = template:Clone()
		card.Parent = target
		applyCard(card, def, getStateForUpgrade(state, def.id))

		if def.branch == "CPU" then
			renderedCpu += 1
		elseif def.branch == "RAM" then
			renderedRam += 1
		elseif def.branch == "STORAGE" then
			renderedSto += 1
		end
	end

	applyCanvasSize(cpuCards)
	applyCanvasSize(ramCards)
	applyCanvasSize(stoCards)

	print(('[UpgradeRenderer] Rendered CPU=%d RAM=%d STORAGE=%d'):format(renderedCpu, renderedRam, renderedSto))

	local binderModule = script.Parent and script.Parent:FindFirstChild("UpgradeBinder")
	local binder = binderModule and require(binderModule)
	if binder and type(binder.RebindAll) == "function" then
		binder.RebindAll({ cpuCards, ramCards, stoCards })
	end
end

return UpgradeRenderer

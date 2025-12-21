local PrestigeUpgradesController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local state = {
	prestigePoints = 0,
	prestigeUpgrades = {},
}

local template
local container
local requestPrestigeState
local requestPrestigePurchase
local toastLabel
local numberFormatter
local defsSorted = nil

local cards = {}
local boundButtons = {}

local function formatNumber(value)
	if numberFormatter and type(numberFormatter.format) == "function" then
		return numberFormatter.format(value)
	end
	return tostring(value)
end

local function getDefsSorted(defs)
	if defsSorted then
		return defsSorted
	end
	local list = {}
	for _, def in pairs(defs) do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		local ac = tonumber(a.cost) or 0
		local bc = tonumber(b.cost) or 0
		if ac == bc then
			return tostring(a.name) < tostring(b.name)
		end
		return ac < bc
	end)
	defsSorted = list
	return list
end

local function getCost(def, level)
	local base = tonumber(def.cost) or 1
	local scale = tonumber(def.costScale) or 1
	return math.floor(base * (scale ^ level))
end

local function getLabel(card, nameA, nameB)
	local label = card:FindFirstChild(nameA)
	if not label and nameB then
		label = card:FindFirstChild(nameB)
	end
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function updateCard(def, card, points, level)
	local maxLevel = tonumber(def.maxLevel) or 0
	local titleLabel = getLabel(card, "CardTitle", "Title")
	if titleLabel then
		titleLabel.Text = def.name or def.id
	end

	local descLabel = getLabel(card, "CardDesc", "Description")
	if descLabel then
		descLabel.Text = def.description or ""
	end

	local costLabel = getLabel(card, "CardCostLabel", "CostLabel")
	if costLabel then
		if maxLevel > 0 and level >= maxLevel then
			costLabel.Text = "Max Level"
		else
			local cost = getCost(def, level)
			costLabel.Text = string.format("Cost: %s PP", formatNumber(cost))
		end
	end

	local levelLabel = getLabel(card, "LevelLabel")
	if levelLabel then
		if maxLevel > 0 then
			levelLabel.Text = string.format("Lv %d/%d", level, maxLevel)
		else
			levelLabel.Text = string.format("Lv %d", level)
		end
	end

	local buyButton = card:FindFirstChild("CardBuyButton") or card:FindFirstChild("BuyButton")
	if buyButton and buyButton:IsA("GuiButton") then
		local canBuy = true
		if maxLevel > 0 and level >= maxLevel then
			canBuy = false
			buyButton.Text = "MAX"
		else
			local cost = getCost(def, level)
			if points < cost then
				canBuy = false
			end
			buyButton.Text = "Buy"
		end
		buyButton.Active = canBuy
		buyButton.AutoButtonColor = canBuy
	end
end

local function buildCards(defs)
	if not template or not container then
		return
	end
	for index, def in ipairs(getDefsSorted(defs)) do
		if not cards[def.id] then
			local card = template:Clone()
			card.Name = def.id
			card.Visible = true
			card.Parent = container
			card.LayoutOrder = index
			cards[def.id] = card

			local buyButton = card:FindFirstChild("CardBuyButton") or card:FindFirstChild("BuyButton")
			if buyButton and buyButton:IsA("GuiButton") and not boundButtons[def.id] then
				boundButtons[def.id] = true
				buyButton.MouseButton1Click:Connect(function()
					if not requestPrestigePurchase then
						return
					end
					local ok, result = pcall(function()
						return requestPrestigePurchase:InvokeServer(def.id)
					end)
					if ok and typeof(result) == "table" then
						state.prestigePoints = tonumber(result.prestigePoints) or state.prestigePoints
						state.prestigeUpgrades = typeof(result.prestigeUpgrades) == "table" and result.prestigeUpgrades or state.prestigeUpgrades
						PrestigeUpgradesController.UpdateState(state)
						return
					end
					if requestPrestigeState then
						local okState, fullState = pcall(function()
							return requestPrestigeState:InvokeServer()
						end)
						if okState and typeof(fullState) == "table" then
							PrestigeUpgradesController.UpdateState(fullState)
						end
					end
				end)
			end
		end
	end
end

function PrestigeUpgradesController.Init(options)
	options = options or {}
	template = options.template
	container = options.container
	requestPrestigeState = options.requestPrestigeState
	toastLabel = options.toastLabel
	numberFormatter = options.NumberFormatter

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local remote = remotes:FindFirstChild("RequestPrestigePurchase")
		if remote and remote:IsA("RemoteFunction") then
			requestPrestigePurchase = remote
		end
	end

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared and shared:FindFirstChild("PrestigeUpgradesConfig")
	if configModule and configModule:IsA("ModuleScript") then
		local config = require(configModule)
		if typeof(config) == "table" and typeof(config.Definitions) == "table" then
			buildCards(config.Definitions)
		end
	end

	if requestPrestigeState then
		local okState, fullState = pcall(function()
			return requestPrestigeState:InvokeServer()
		end)
		if okState and typeof(fullState) == "table" then
			PrestigeUpgradesController.UpdateState(fullState)
		end
	end
end

function PrestigeUpgradesController.UpdateState(newState)
	if typeof(newState) ~= "table" then
		return
	end
	state.prestigePoints = tonumber(newState.prestigePoints) or state.prestigePoints
	if typeof(newState.prestigeUpgrades) == "table" then
		state.prestigeUpgrades = newState.prestigeUpgrades
	end

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared and shared:FindFirstChild("PrestigeUpgradesConfig")
	if not (configModule and configModule:IsA("ModuleScript")) then
		return
	end
	local config = require(configModule)
	if typeof(config) ~= "table" or typeof(config.Definitions) ~= "table" then
		return
	end

	buildCards(config.Definitions)

	for _, def in ipairs(getDefsSorted(config.Definitions)) do
		local card = cards[def.id]
		if card then
			local level = tonumber(state.prestigeUpgrades[def.id]) or 0
			updateCard(def, card, state.prestigePoints or 0, level)
		end
	end
end

return PrestigeUpgradesController

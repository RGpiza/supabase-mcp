local Players = game:GetService("Players")

local TitleDisplayService = {}
local initialized = false

local BILLBOARD_NAME = "ActiveTitleBillboard"
local LABEL_NAME = "TitleLabel"
local ADORNEE_PART = "HumanoidRootPart"

local TITLE_STYLES = {
	["WEEKLY DOMINATOR"] = {
		color = Color3.fromRGB(255, 208, 112),
		stroke = Color3.fromRGB(80, 20, 20),
	},
	["SYSTEM OVERLORD"] = {
		color = Color3.fromRGB(255, 243, 160),
		stroke = Color3.fromRGB(50, 30, 0),
	},
	["CORE ARCHITECT"] = {
		color = Color3.fromRGB(175, 225, 255),
		stroke = Color3.fromRGB(15, 35, 60),
	},
	["DATA ENGINEER"] = {
		color = Color3.fromRGB(190, 210, 255),
		stroke = Color3.fromRGB(20, 30, 55),
	},
	default = {
		color = Color3.fromRGB(235, 240, 255),
		stroke = Color3.fromRGB(10, 10, 10),
	},
}

local playerConnections = {}

local function getStyleForTitle(title)
	return TITLE_STYLES[title] or TITLE_STYLES.default
end

local function getAdornee(character)
	if not character then
		return nil
	end

	local root = character:FindFirstChild(ADORNEE_PART)
	if root then
		return root
	end

	local ok, found = pcall(function()
		return character:WaitForChild(ADORNEE_PART, 2)
	end)
	if ok and found then
		return found
	end

	return character:FindFirstChildWhichIsA("BasePart")
end

local function ensureBillboard(character)
	local adornee = getAdornee(character)
	if not adornee then
		return nil
	end

	local billboard = adornee:FindFirstChild(BILLBOARD_NAME)
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = BILLBOARD_NAME
		billboard.AlwaysOnTop = true
		billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		billboard.Size = UDim2.fromOffset(200, 40)
		billboard.MaxDistance = 0
		billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		billboard.Adornee = adornee
		billboard.Parent = adornee

		local label = Instance.new("TextLabel")
		label.Name = LABEL_NAME
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = ""
		label.TextColor3 = TITLE_STYLES.default.color
		label.TextStrokeColor3 = TITLE_STYLES.default.stroke
		label.TextStrokeTransparency = 0.2
		label.Parent = billboard

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = label

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 28
		constraint.MinTextSize = 12
		constraint.Parent = label
	end

	return billboard
end

local function applyTitleToCharacter(player, character)
	local billboard = ensureBillboard(character)
	if not billboard then
		return
	end

	local label = billboard:FindFirstChild(LABEL_NAME)
	if not (label and label:IsA("TextLabel")) then
		return
	end

	local titleValue = player:GetAttribute("ActiveTitle")
	if typeof(titleValue) ~= "string" or titleValue == "" then
		billboard.Enabled = false
		return
	end

	billboard.Enabled = true
	label.Text = titleValue
	local style = getStyleForTitle(titleValue)
	label.TextColor3 = style.color
	label.TextStrokeColor3 = style.stroke
end

local function onCharacterAdded(player, character)
	if not (player and character) then
		return
	end

	task.spawn(function()
		applyTitleToCharacter(player, character)
	end)
end

local function connectPlayer(player)
	if not player then
		return
	end

	if playerConnections[player] then
		for _, connection in ipairs(playerConnections[player]) do
			connection:Disconnect()
		end
	end
	playerConnections[player] = {}

	local attributeConnection = player:GetAttributeChangedSignal("ActiveTitle"):Connect(function()
		if player.Character then
			applyTitleToCharacter(player, player.Character)
		end
	end)
	table.insert(playerConnections[player], attributeConnection)

	local characterConnection = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	table.insert(playerConnections[player], characterConnection)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function disconnectPlayer(player)
	local connections = playerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end
end

function TitleDisplayService.Init()
	if initialized then
		return
	end
	initialized = true

	for _, player in ipairs(Players:GetPlayers()) do
		connectPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player)
		connectPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		disconnectPlayer(player)
	end)
end

return TitleDisplayService

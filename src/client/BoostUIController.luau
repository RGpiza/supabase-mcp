local BoostUIController = {}
local initialized = false
local moduleApi

function BoostUIController.Init(context)
	if initialized then
		return moduleApi
	end

	local ui = context.ui or {}
	local topBar = ui.topBar
	local safeFind = context.safeFind
	local boostsUpdatedEvent = context.remotes and context.remotes.boostsUpdatedEvent

	if not topBar then
		return nil
	end

	local function createBoostLabel(parent)
		local label = Instance.new("TextLabel")
		label.Name = "BoostLabel"
		label.AnchorPoint = Vector2.new(1, 0)
		label.Position = UDim2.new(1, -16, 0, 8)
		label.Size = UDim2.new(0, 140, 0, 24)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Font = Enum.Font.GothamBold
		label.TextSize = 18
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Visible = false
		label.Parent = parent
		return label
	end

	local function formatBoostMultiplier(multiplier)
		if math.abs(multiplier - math.floor(multiplier + 0.001)) <= 0.01 then
			return string.format("BOOST x%d", math.floor(multiplier + 0.5))
		end
		return string.format("BOOST x%.2f", multiplier)
	end

	local boostLabel = safeFind(topBar, "BoostLabel")
	if not boostLabel then
		boostLabel = createBoostLabel(topBar)
	end

	local function updateBoostLabel(multiplier)
		if not boostLabel then
			return
		end

		if typeof(multiplier) ~= "number" or multiplier <= 1 then
			boostLabel.Visible = false
			return
		end

		boostLabel.Text = formatBoostMultiplier(multiplier)
		boostLabel.Visible = true
	end

	updateBoostLabel(1)

	if boostsUpdatedEvent then
		boostsUpdatedEvent.OnClientEvent:Connect(function(_, multiplier)
			updateBoostLabel(typeof(multiplier) == "number" and multiplier or 1)
		end)
	else
		updateBoostLabel(1)
	end

	moduleApi = {
		UpdateBoostLabel = updateBoostLabel,
	}
	initialized = true

	return moduleApi
end

return BoostUIController

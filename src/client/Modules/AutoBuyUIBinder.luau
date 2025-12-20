local AutoBuyUIBinder = {}

local UIPaths = require(script.Parent:FindFirstChild("UIPaths"))
local AutoBuyController = require(script.Parent.Parent.Controllers:FindFirstChild("AutoBuyController"))

local connected = {}
local lastClick = {}
local DEBOUNCE = 0.2

local function updateButton(button, enabled)
	button:SetAttribute("Enabled", enabled)
	button.Text = enabled and "AUTO-BUY: ON" or "AUTO-BUY: OFF"
end

local function bindButton(button, category)
	if not button or connected[button] then
		return
	end
	connected[button] = true
	updateButton(button, AutoBuyController.GetEnabled(category))
	button.Activated:Connect(function()
		local now = os.clock()
		local last = lastClick[button] or 0
		if now - last < DEBOUNCE then
			return
		end
		lastClick[button] = now
		local nextState = not AutoBuyController.GetEnabled(category)
		AutoBuyController.SetEnabled(category, nextState)
		updateButton(button, nextState)
	end)
end

function AutoBuyUIBinder.Init(terminalUi)
	if not terminalUi then
		return
	end
	local buttons = UIPaths.GetAutoBuyButtons(terminalUi)
	if not buttons then
		warn("[AutoBuyUIBinder] AutoBuy buttons missing; aborting")
		return
	end
	bindButton(buttons.CPU, "CPU")
	bindButton(buttons.RAM, "RAM")
	bindButton(buttons.STO, "STO")
end

return AutoBuyUIBinder

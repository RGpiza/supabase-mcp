local AutoBuyController = {}

local signals
local uiState
local connected = {}

local function updateButton(button, enabled)
	button:SetAttribute("Enabled", enabled)
	button.Text = enabled and "AUTO-BUY: ON" or "AUTO-BUY: OFF"
	local base = button:GetAttribute("BaseColor") or button.BackgroundColor3
	local onColor = button:GetAttribute("OnColor") or base:Lerp(Color3.fromRGB(80, 200, 120), 0.4)
	button.BackgroundColor3 = enabled and onColor or base
end

local function connectButton(button)
	if not button or connected[button] then
		return
	end
	connected[button] = true
	updateButton(button, button:GetAttribute("Enabled") == true)
	button.Activated:Connect(function()
		local nextState = not (button:GetAttribute("Enabled") == true)
		updateButton(button, nextState)
		print("[AutoBuyController] Auto-Buy toggled", button.Parent and button.Parent.Name or "Unknown", nextState)
	end)
end

local function resolveButtons()
	if not uiState or not uiState.TerminalUI then
		return
	end
	local root = uiState.TerminalUI:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	local cpu = columns and columns:FindFirstChild("CPUColumn")
	local ram = columns and columns:FindFirstChild("RAMColumn")
	local sto = columns and columns:FindFirstChild("STOColumn")
	connectButton(cpu and cpu:FindFirstChild("AutoBuyButton"))
	connectButton(ram and ram:FindFirstChild("AutoBuyButton"))
	connectButton(sto and sto:FindFirstChild("AutoBuyButton"))
end

function AutoBuyController.Init(context)
	signals = context.Signals
	signals.UIReady:Connect(function(ui)
		uiState = ui
		resolveButtons()
	end)
end

function AutoBuyController.Start()
	resolveButtons()
end

return AutoBuyController

local Players = game:GetService("Players")

local UIController = {}

local state = {
	playerGui = nil,
	terminalUi = nil,
	loadingUi = nil,
	rightPanel = nil,
	pages = nil,
	template = nil,
	uiReadyFired = false,
	tabLinks = {},
}

local signals

local function resolveUi()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if playerGui then
		state.playerGui = playerGui
		state.terminalUi = playerGui:FindFirstChild("TerminalUI")
		state.loadingUi = playerGui:FindFirstChild("LoadingUI")
		state.template = playerGui:FindFirstChild("UpgradeCardTemplate")
	end

	local root = state.terminalUi and state.terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	state.rightPanel = main and main:FindFirstChild("RightPanel")
	state.pages = state.rightPanel and state.rightPanel:FindFirstChild("Pages")
end

local function tryFireReady()
	if state.uiReadyFired then
		return
	end
	if state.terminalUi and state.template then
		state.uiReadyFired = true
		signals.UIReady:Fire(state)
	end
end

local function hideAllPages()
	if not state.pages then
		return
	end
	for _, child in ipairs(state.pages:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end
end

function UIController.Init(context)
	signals = context.Signals
	resolveUi()

	if state.playerGui then
		state.playerGui.ChildAdded:Connect(function(child)
			if child.Name == "TerminalUI" or child.Name == "LoadingUI" or child.Name == "UpgradeCardTemplate" then
				resolveUi()
				tryFireReady()
			end
		end)
	end
end

function UIController.Start()
	resolveUi()
	tryFireReady()

	signals.UpgradesRendered:Connect(function()
		if state.loadingUi and state.loadingUi:IsA("ScreenGui") then
			state.loadingUi.Enabled = false
		end
		if state.terminalUi and state.terminalUi:IsA("ScreenGui") then
			state.terminalUi.Enabled = true
		end
		print("[UIController] Ready — upgrades rendered and bound")
	end)
end

function UIController.GetUI()
	return {
		PlayerGui = state.playerGui,
		TerminalUI = state.terminalUi,
		LoadingUI = state.loadingUi,
		RightPanel = state.rightPanel,
		Pages = state.pages,
		Template = state.template,
	}
end

function UIController.RegisterTab(tabButton, pageFrame, highlightColors)
	if not (tabButton and pageFrame) then
		return
	end
	if state.tabLinks[tabButton] then
		return
	end
	state.tabLinks[tabButton] = true
	local defaultColor = tabButton.BackgroundColor3
	local activeColor = highlightColors and highlightColors.active or defaultColor
	tabButton.Activated:Connect(function()
		hideAllPages()
		pageFrame.Visible = true
		tabButton.BackgroundColor3 = activeColor
		print("[UIController] Tab opened", tabButton.Name)
	end)
end

function UIController.ShowPage(pageName)
	if not state.pages then
		return
	end
	hideAllPages()
	local page = state.pages:FindFirstChild(pageName)
	if page and page:IsA("GuiObject") then
		page.Visible = true
	end
end

return UIController

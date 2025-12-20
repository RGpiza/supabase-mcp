local WeeklyLeaderboardController = {}

local state = {
	ui = nil,
	tab = nil,
	pages = nil,
	page = nil,
	list = nil,
	template = nil,
	connected = false,
}
local UIPaths = nil
local WeeklyRenderer = nil

local function resolve(ui)
	if not UIPaths then
		local modules = script.Parent.Parent and script.Parent.Parent:FindFirstChild("Modules")
		local uiPathsModule = modules and modules:FindFirstChild("UIPaths")
		UIPaths = uiPathsModule and require(uiPathsModule) or nil
		local rendererModule = modules and modules:FindFirstChild("WeeklyLeaderboardRenderer")
		WeeklyRenderer = rendererModule and require(rendererModule) or nil
	end
	if not UIPaths or not ui then
		return
	end
	local root = ui:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	local tabs = rightPanel and rightPanel:FindFirstChild("Tabs")
	local pages = rightPanel and rightPanel:FindFirstChild("Pages")
	local weeklyTab = tabs and tabs:FindFirstChild("WeeklyTab")
	local weeklyPage = UIPaths.GetWeeklyPage(ui)
	local list = weeklyPage and weeklyPage:FindFirstChild("LeaderboardList")
	local template = list and list:FindFirstChild("RowTemplate")

	state.tab = weeklyTab
	state.pages = pages
	state.page = weeklyPage
	state.list = list
	state.template = template
end

local function showPage()
	if not state.pages or not state.page then
		return
	end
	for _, child in ipairs(state.pages:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = (child == state.page)
		end
	end
end

local function clearRows()
	if not WeeklyRenderer then
		return
	end
	WeeklyRenderer.Clear(state.page)
end


function WeeklyLeaderboardController.Init(ui)
	state.ui = ui
	resolve(ui)
	if not state.tab or state.connected then
		return
	end
	state.connected = true
	state.tab.Activated:Connect(function()
		showPage()
	end)
end

function WeeklyLeaderboardController.Update(data)
	if type(data) ~= "table" then
		return
	end
	resolve(state.ui)
	if not (state.list and state.template and WeeklyRenderer) then
		return
	end
	WeeklyRenderer.Render(state.page, data)
end

return WeeklyLeaderboardController

local WeeklyController = {}

local signals
local uiController
local uiState
local rowTemplate
local list
local tab
local page
local connected = false

local function clearRows()
	if not list or not rowTemplate then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") and child ~= rowTemplate then
			child:Destroy()
		end
	end
end

local function fillRow(row, entry)
	local rankLabel = row:FindFirstChild("Rank")
	local nameLabel = row:FindFirstChild("Username") or row:FindFirstChild("Name")
	local scoreLabel = row:FindFirstChild("Score") or row:FindFirstChild("Value")
	if rankLabel and rankLabel:IsA("TextLabel") then
		rankLabel.Text = tostring(entry.rank or "")
	end
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = tostring(entry.username or entry.name or "")
	end
	if scoreLabel and scoreLabel:IsA("TextLabel") then
		scoreLabel.Text = tostring(entry.score or entry.value or "")
	end
end

local function renderWeeklyLeaderboard(data)
	if not list or not rowTemplate or type(data) ~= "table" then
		return
	end
	clearRows()
	for _, entry in ipairs(data) do
		local row = rowTemplate:Clone()
		row.Visible = true
		row.Parent = list
		fillRow(row, entry)
	end
	print("[WeeklyController] Weekly leaderboard rendered", #data)
end

local function resolveUi()
	if not uiState or not uiState.RightPanel then
		return
	end
	local rightPanel = uiState.RightPanel
	local tabs = rightPanel:FindFirstChild("Tabs")
	local pages = rightPanel:FindFirstChild("Pages")
	tab = tabs and tabs:FindFirstChild("WeeklyTab")
	page = pages and pages:FindFirstChild("WeeklyLeaderboardPage")
	list = page and page:FindFirstChild("LeaderboardList")
	rowTemplate = list and list:FindFirstChild("RowTemplate")
end

function WeeklyController.Init(context)
	signals = context.Signals
	uiController = require(script.Parent:FindFirstChild("UIController"))
	signals.UIReady:Connect(function(ui)
		uiState = ui
		resolveUi()
		if tab and page and not connected then
			connected = true
			uiController.RegisterTab(tab, page, { active = tab.BackgroundColor3 })
		end
	end)
end

function WeeklyController.Start()
	resolveUi()
end

WeeklyController.RenderWeeklyLeaderboard = renderWeeklyLeaderboard

return WeeklyController

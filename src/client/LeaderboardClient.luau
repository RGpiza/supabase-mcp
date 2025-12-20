local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormatter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NumberFormatter"))

local LeaderboardClient = {}
local REFRESH_INTERVAL = 75

local function formatValue(value)
	local numeric = typeof(value) == "number" and math.max(value, 0) or 0
	local ok, formatted = pcall(function()
		return NumberFormatter.format(numeric)
	end)
	if ok and typeof(formatted) == "string" then
		return string.format("%s Data", formatted)
	end
	return string.format("%d Data", math.floor(numeric + 0.5))
end

local function formatCountdown(seconds)
	local clamped = math.max(seconds or 0, 0)
	local days = math.floor(clamped / 86400)
	local hours = math.floor((clamped % 86400) / 3600)
	local minutes = math.floor((clamped % 3600) / 60)
	return string.format("%dd %02dh %02dm", days, hours, minutes)
end

local function cleanupRows(list, template, reservedNames)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") and child ~= template and not reservedNames[child.Name] then
			child:Destroy()
		end
	end
end

local function initSection(config)
	if not (config.page and config.list and config.rowTemplate and config.yourRankFrame) then
		return nil
	end

	local reservedNames = {
		[config.rowTemplate.Name] = true,
	}
	if config.emptyLabel and config.emptyLabel.Name ~= "" then
		reservedNames[config.emptyLabel.Name] = true
	end

	if config.subtitleLabel and config.subtitleText then
		config.subtitleLabel.Text = config.subtitleText
		config.subtitleLabel.Visible = true
	end

	if config.headerLabel and config.accentColor then
		config.headerLabel.TextColor3 = config.accentColor
	end
	if config.headerLabel and config.mode == "weekly" then
		config.headerLabel.Text = "⏱️ WEEKLY LEADERBOARD"
	end

	local state = {
		lastRequest = 0,
		pending = false,
		resetExpiresAt = nil,
		lastTopSignature = nil,
	}

	local function updateCountdownLabel()
		if not (config.countdownLabel or config.headerLabel) then
			return
		end

		local remaining = 0
		if state.resetExpiresAt then
			remaining = math.max(0, math.floor(state.resetExpiresAt - os.clock()))
		end

		local countdownText = formatCountdown(remaining)

		if config.countdownLabel and config.countdownLabel:IsA("TextLabel") then
			config.countdownLabel.Text = string.format("⏱️ Resets in %s", countdownText)
			config.countdownLabel.Visible = true
		end

		if config.mode == "weekly" and config.headerLabel and config.headerLabel:IsA("TextLabel") then
			config.headerLabel.Text = string.format("⏱️ WEEKLY LEADERBOARD (%s)", countdownText)
		end
	end

	local function scheduleCountdown(seconds)
		if not seconds then
			return
		end
		state.resetExpiresAt = os.clock() + math.max(seconds, 0)
		updateCountdownLabel()

		if state.countdownLoop then
			return
		end
		state.countdownLoop = true
		task.spawn(function()
			while state.countdownLoop and config.page.Parent do
				updateCountdownLabel()
				task.wait(60)
			end
			state.countdownLoop = false
		end)
	end

	local function applyYourRow(payload)
		local nameLabel = config.yourRankFrame:FindFirstChild("Name")
		local rankLabel = config.yourRankFrame:FindFirstChild("Rank")
		local valueLabel = config.yourRankFrame:FindFirstChild("Value")

		local youName = payload.name or config.defaultName or "You"

		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = youName
		end
		if rankLabel and rankLabel:IsA("TextLabel") then
			if payload.rank and typeof(payload.rank) == "number" then
				rankLabel.Text = string.format("#%d", payload.rank)
			else
				rankLabel.Text = "#—"
			end
		end
		if valueLabel and valueLabel:IsA("TextLabel") then
			valueLabel.Text = formatValue(payload.value)
		end
	end

	local function buildRow(entry)
		local row = config.rowTemplate:Clone()
		row.Name = string.format("Row_%d", entry.rank or entry.userId or math.random(1, 9999))
		row.Visible = true
		row.LayoutOrder = entry.rank or 1000
		row.BackgroundColor3 = config.rowColor or row.BackgroundColor3
		row.Parent = config.list

		local rankLabel = row:FindFirstChild("Rank")
		if rankLabel and rankLabel:IsA("TextLabel") then
			rankLabel.Text = entry.rank and string.format("#%d", entry.rank) or "#—"
			rankLabel.Visible = (entry.rank ~= 1)
		end

		local crownLabel = row:FindFirstChild("Crown")
		if crownLabel and crownLabel:IsA("TextLabel") then
			crownLabel.Visible = entry.rank == 1
		end

		local nameLabel = row:FindFirstChild("Name")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = entry.name or "Player"
		end

		local valueLabel = row:FindFirstChild("Value")
		if valueLabel and valueLabel:IsA("TextLabel") then
			valueLabel.Text = formatValue(entry.value)
		end
	end

	local function computeSignature(entries)
		local buffer = table.create(#entries)
		for _, entry in ipairs(entries) do
			local userId = entry.userId or 0
			local rank = entry.rank or 0
			local value = math.floor((entry.value or 0) + 0.5)
			buffer[#buffer + 1] = string.format("%d:%d:%d", userId, rank, value)
		end
		return table.concat(buffer, "|")
	end

	local function applyLeaderboard(payload)
		local entries = {}
		if typeof(payload) == "table" then
			if typeof(payload.top) == "table" then
				entries = payload.top
			elseif typeof(payload.entries) == "table" then
				entries = payload.entries
			elseif payload[1] ~= nil then
				entries = payload
			end
		end
		local you = typeof(payload) == "table" and (typeof(payload.you) == "table" and payload.you or {}) or {}

		local signature = computeSignature(entries)
		local rowsChanged = (state.lastTopSignature ~= signature)
		state.lastTopSignature = signature

		if rowsChanged then
			cleanupRows(config.list, config.rowTemplate, reservedNames)

			if #entries == 0 then
				if config.emptyLabel and config.emptyLabel:IsA("TextLabel") then
					config.emptyLabel.Text = config.emptyText or "No leaderboard data"
					config.emptyLabel.Visible = true
				end
			else
				if config.emptyLabel and config.emptyLabel:IsA("TextLabel") then
					config.emptyLabel.Visible = false
				end
				for _, entry in ipairs(entries) do
					buildRow(entry)
				end
			end

			config.list.CanvasPosition = Vector2.new(0, 0)
		end

		if not you.name then
			you.name = config.defaultName or "You"
		end

		if config.mode == "weekly" and typeof(payload.resetSeconds) == "number" then
			scheduleCountdown(payload.resetSeconds)
		end

		applyYourRow(you)
	end

	local function requestLeaderboard(force)
		if not config.remote then
			return
		end

		local now = os.clock()
		if not force and (now - state.lastRequest) < REFRESH_INTERVAL then
			return
		end

		if state.pending then
			return
		end

		state.pending = true
		if config.emptyLabel and config.emptyLabel:IsA("TextLabel") then
			config.emptyLabel.Text = "Loading..."
			config.emptyLabel.Visible = true
		end

		task.spawn(function()
			local ok, payload = pcall(function()
				if config.kind == "lifetime" and config.useLifetimeRemote then
					return config.remote:InvokeServer(force == true)
				else
					return config.remote:InvokeServer(config.mode)
				end
			end)
			state.pending = false
			if ok and typeof(payload) == "table" then
				state.lastRequest = os.clock()
				applyLeaderboard(payload)
			elseif config.emptyLabel and config.emptyLabel:IsA("TextLabel") then
				config.emptyLabel.Text = "Failed to load leaderboard"
				config.emptyLabel.Visible = true
			end
		end)
	end

	if config.page then
		config.page:GetPropertyChangedSignal("Visible"):Connect(function()
			if config.page.Visible then
				requestLeaderboard(true)
			end
		end)
	end

	if config.tab and config.tab:IsA("GuiButton") then
		config.tab.Activated:Connect(function()
			requestLeaderboard(true)
		end)
	end

	task.spawn(function()
		while config.page.Parent do
			task.wait(REFRESH_INTERVAL)
			if config.page.Visible then
				requestLeaderboard(false)
			end
		end
	end)

	requestLeaderboard(config.kind == "lifetime")

	return {
		Refresh = requestLeaderboard,
	}
end

function LeaderboardClient.Init(context)
	if not context then
		return nil
	end

	local player = context.player
	local ui = context.ui or {}
	local rightPanel = ui.rightPanel
	local remotes = context.remotes or {}
	local leaderboardRemote = remotes.leaderboardFunction
	local lifetimeRemote = remotes.lifetimeLeaderboardFunction

	if not (rightPanel and leaderboardRemote) then
		return nil
	end

	local pages = rightPanel:FindFirstChild("Pages")
	local tabs = rightPanel:FindFirstChild("Tabs")

	local sections = {
		{
			page = pages and pages:FindFirstChild("LeaderboardPage"),
			tab = tabs and tabs:FindFirstChild("LeaderboardTab"),
			kind = "lifetime",
			mode = nil,
			emptyText = "No leaderboard data",
			remote = lifetimeRemote or leaderboardRemote,
			useLifetimeRemote = lifetimeRemote ~= nil,
		},
		{
			page = pages and pages:FindFirstChild("FriendsLeaderboardPage"),
			tab = tabs and tabs:FindFirstChild("FriendsTab"),
			kind = "friends",
			mode = "friends",
			emptyText = "Invite friends to compete!",
			subtitleText = "Only players you're friends with",
			remote = leaderboardRemote,
		},
		{
			page = pages and pages:FindFirstChild("WeeklyLeaderboardPage"),
			tab = tabs and tabs:FindFirstChild("WeeklyTab"),
			kind = "weekly",
			mode = "weekly",
			emptyText = "Play this week to place here!",
			subtitleText = "⏱️ Cosmetic rewards only",
			accentColor = Color3.fromRGB(220, 190, 255),
			rowColor = Color3.fromRGB(30, 24, 40),
			remote = leaderboardRemote,
		},
	}

	for _, section in ipairs(sections) do
		if section.page and section.remote then
			section.list = section.page:FindFirstChild("List", true)
				or section.page:FindFirstChildWhichIsA("ScrollingFrame", true)
			section.rowTemplate = section.list and section.list:FindFirstChild("RowTemplate", true)
			section.emptyLabel = section.list and section.list:FindFirstChild("Empty", true)
			section.yourRankFrame = section.page:FindFirstChild("YourRank", true)
			section.subtitleLabel = section.page:FindFirstChild("Subtitle", true)
			section.headerLabel = section.page:FindFirstChild("Header", true)
			section.countdownLabel = section.page:FindFirstChild("Countdown", true)
			section.defaultName = player and (player.DisplayName or player.Name) or "You"
			initSection(section)
		end
	end

	return true
end

return LeaderboardClient

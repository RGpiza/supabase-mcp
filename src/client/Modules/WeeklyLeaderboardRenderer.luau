local WeeklyLeaderboardRenderer = {}

local function resolveWeeklyList(weeklyPage)
	if not weeklyPage then
		return nil, nil
	end
	local list = weeklyPage:FindFirstChild("LeaderboardList")
	local template = list and list:FindFirstChild("RowTemplate")
	return list, template
end

local function findLabel(row, names)
	for _, name in ipairs(names) do
		local label = row:FindFirstChild(name)
		if label and label:IsA("TextLabel") then
			return label
		end
	end
	return nil
end

local function updateRow(row, entry)
	local rankLabel = findLabel(row, { "Rank" })
	local nameLabel = findLabel(row, { "Username", "Name" })
	local scoreLabel = findLabel(row, { "Score", "Value" })

	if rankLabel then
		rankLabel.Text = tostring(entry.Rank or entry.rank or "")
	end
	if nameLabel then
		nameLabel.Text = tostring(entry.Name or entry.username or entry.name or "")
	end
	if scoreLabel then
		scoreLabel.Text = tostring(entry.Score or entry.score or entry.value or "")
	end
end

function WeeklyLeaderboardRenderer.Clear(weeklyPage)
	local list, _ = resolveWeeklyList(weeklyPage)
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") and child:GetAttribute("__WeeklyRow") == true then
			child:Destroy()
		end
	end
end

function WeeklyLeaderboardRenderer.Render(weeklyPage, data)
	if type(data) ~= "table" then
		return
	end
	local list, template = resolveWeeklyList(weeklyPage)
	if not (list and template) then
		return
	end

	local existing = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") and child:GetAttribute("__WeeklyRow") == true then
			local userId = child:GetAttribute("UserId")
			if type(userId) == "number" then
				existing[userId] = child
			end
		end
	end

	local seen = {}
	for _, entry in ipairs(data) do
		local userId = entry.UserId or entry.userId or entry.userID
		if type(userId) ~= "number" then
			continue
		end
		local row = existing[userId]
		if not row then
			row = template:Clone()
			row.Visible = true
			row.Parent = list
			row:SetAttribute("__WeeklyRow", true)
			row:SetAttribute("UserId", userId)
		end
		updateRow(row, entry)
		seen[userId] = true
	end

	for userId, row in pairs(existing) do
		if not seen[userId] then
			row:Destroy()
		end
	end
end

return WeeklyLeaderboardRenderer

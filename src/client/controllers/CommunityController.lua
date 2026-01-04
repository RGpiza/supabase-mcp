local CommunityController = {}

local initialized = false

function CommunityController.Init(ctx)
	if initialized then
		return true
	end
	initialized = true

	local Players = ctx.Players or game:GetService("Players")
	local ReplicatedStorage = ctx.ReplicatedStorage or game:GetService("ReplicatedStorage")
	local HttpService = ctx.HttpService or game:GetService("HttpService")
	local TweenService = ctx.TweenService or game:GetService("TweenService")
	local player = ctx.player or Players.LocalPlayer

	local communityPage = ctx.communityPage
	local likeGoals = ctx.likeGoals
	local likesLabel = ctx.likesLabel
	local milestoneList = ctx.milestoneList
	local milestoneTemplate = ctx.milestoneTemplate
	local milestoneEmpty = ctx.milestoneEmpty
	local progressBar = ctx.progressBar
	local progressFill = ctx.progressFill
	local nextRewardLabel = ctx.nextRewardLabel
	local claimNextButton = ctx.claimNextButton
	local claimAllButton = ctx.claimAllButton
	local favoriteClaimButton = ctx.favoriteClaimButton
	local favoriteStatusLabel = ctx.favoriteStatusLabel
	local errorLabel = ctx.errorLabel
	local retryButton = ctx.retryButton
	local toastLabel = ctx.toastLabel

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		return false
	end

	local getCommunityState = remotesFolder:FindFirstChild("GetCommunityState")
	local getSocialGoalsState = remotesFolder:FindFirstChild("GetSocialGoalsState")
	local claimLikeMilestone = remotesFolder:FindFirstChild("ClaimLikeMilestone")
	local claimSocialMilestone = remotesFolder:FindFirstChild("ClaimMilestone")
	local claimFavoriteReward = remotesFolder:FindFirstChild("ClaimFavoriteReward")
	local communityStateUpdated = remotesFolder:FindFirstChild("CommunityStateUpdated")
	local socialGoalsUpdated = remotesFolder:FindFirstChild("SocialGoalsStateUpdated")

	if getCommunityState and not getCommunityState:IsA("RemoteFunction") then
		getCommunityState = nil
	end
	if getSocialGoalsState and not getSocialGoalsState:IsA("RemoteFunction") then
		getSocialGoalsState = nil
	end
	if claimLikeMilestone and not claimLikeMilestone:IsA("RemoteFunction") then
		claimLikeMilestone = nil
	end
	if claimSocialMilestone and not claimSocialMilestone:IsA("RemoteFunction") then
		claimSocialMilestone = nil
	end
	if claimFavoriteReward and not claimFavoriteReward:IsA("RemoteFunction") then
		claimFavoriteReward = nil
	end
	if communityStateUpdated and not communityStateUpdated:IsA("RemoteEvent") then
		communityStateUpdated = nil
	end
	if socialGoalsUpdated and not socialGoalsUpdated:IsA("RemoteEvent") then
		socialGoalsUpdated = nil
	end

	local lastFetch = 0
	local REFRESH_DEBOUNCE = 0.5
	local lastHash = nil
	local refreshVersion = 0
	local currentState = nil
	local currentFavoriteId = nil
	local AUTO_REFRESH_SEC = 5

	local function showToast(message)
		if not toastLabel then
			return
		end
		toastLabel.Text = message
		toastLabel.Visible = true
		task.delay(2, function()
			toastLabel.Visible = false
		end)
	end

	local function clearRows()
		if not milestoneList then
			return
		end
		for _, child in ipairs(milestoneList:GetChildren()) do
			if child ~= milestoneTemplate and child ~= milestoneEmpty then
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
		end
	end

	local function formatReward(entry)
		if entry.rewardText then
			return entry.rewardText
		end
		local rewardType = entry.rewardType
		local value = entry.rewardValue
		if rewardType == "PrestigePoints" then
			return string.format("+%d Prestige Points", value or 0)
		elseif rewardType == "ProductionBonus" then
			return string.format("+%d%% Production", math.floor((value or 0) * 100))
		elseif rewardType == "AutomationMultiplier" then
			return string.format("-%d%% Auto Tick", math.floor((value or 0) * 100))
		end
		return "Reward"
	end

	local function computeNextGoal(likes, milestones)
		local nextGoal = nil
		for _, entry in ipairs(milestones) do
			if likes < (entry.goalLikes or entry.goal or 0) then
				local goal = entry.goalLikes or entry.goal
				if not nextGoal or goal < nextGoal then
					nextGoal = goal
				end
			end
		end
		return nextGoal
	end

	local function render(state)
		currentState = state
		if errorLabel then
			errorLabel.Visible = false
		end
		if retryButton then
			retryButton.Visible = false
		end
		if not state or typeof(state) ~= "table" then
			if errorLabel then
				errorLabel.Visible = true
			end
			if retryButton then
				retryButton.Visible = true
			end
			return
		end
		local likes = tonumber(state.currentLikes or state.likes) or 0
		local nextMilestone = tonumber(state.nextMilestone) or 0
		local progressToNext = tonumber(state.progressToNext) or 0
		local canClaim = state.canClaim == true
		local pendingCount = tonumber(state.pendingCount) or 0
		local rewardPreview = tostring(state.rewardPreview or "-")
		if likesLabel then
			likesLabel.Text = string.format("Current: %d / Next: %s", likes, nextMilestone > 0 and tostring(nextMilestone) or "-")
		end
		if nextRewardLabel then
			nextRewardLabel.Text = string.format("Next Reward: %s", rewardPreview)
			nextRewardLabel.Visible = true
		end
		if progressFill then
			local target = UDim2.new(math.clamp(progressToNext, 0, 1), 0, 1, 0)
			local tween = TweenService:Create(progressFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = target,
			})
			tween:Play()
		end
		if claimNextButton then
			claimNextButton.Text = canClaim and "CLAIM" or "LOCKED"
			claimNextButton.Active = canClaim
		end
		if claimAllButton then
			claimAllButton.Text = pendingCount > 1 and ("CLAIM ALL (" .. tostring(pendingCount) .. ")") or "CLAIM ALL"
			claimAllButton.Active = pendingCount > 1
		end
		if milestoneList then
			milestoneList.Visible = false
		end
		if milestoneEmpty then
			milestoneEmpty.Visible = false
		end
		currentFavoriteId = nil
		local favorite = typeof(state.favorite) == "table" and state.favorite or {}
		local favoritesList = typeof(state.favorites) == "table" and state.favorites or nil
		local favClaimed = favorite.claimed == true
		if favoritesList then
			favClaimed = true
			for _, entry in ipairs(favoritesList) do
				if entry.eligible == true and entry.claimed ~= true then
					currentFavoriteId = entry.id
					favorite = entry
					favClaimed = false
					break
				end
			end
			if not currentFavoriteId and #favoritesList > 0 then
				favorite = favoritesList[1]
			end
		end
		if favoriteStatusLabel then
			if favoritesList and favorite then
				local milestone = favorite.milestone or 0
				if favClaimed then
					local rewardText = favorite.rewardText or formatReward(favorite)
					favoriteStatusLabel.Text = string.format("Claimed up to %d Favorites — %s", milestone, rewardText)
				else
					favoriteStatusLabel.Text = string.format("%d Favorites — %s", milestone, formatReward(favorite))
				end
			else
				if favClaimed then
					local rewardText = favorite.rewardText or "Reward"
					favoriteStatusLabel.Text = string.format("Claimed — %s", rewardText)
				else
					local rewardText = favorite.rewardText or "Reward available"
					favoriteStatusLabel.Text = string.format("Reward: %s", rewardText)
				end
			end
			favoriteStatusLabel.Visible = true
		end
		if favoriteClaimButton then
			favoriteClaimButton.Text = favClaimed and "CLAIMED" or "CLAIM"
			favoriteClaimButton.Active = not favClaimed
		end
	end

	local function hashState(state)
		return HttpService:JSONEncode(state)
	end

	local function applySnapshot(state)
		local newHash = hashState(state)
		if newHash == lastHash then
			return false
		end
		lastHash = newHash
		render(state)
		refreshVersion += 1
		print(("[Community] Refresh v=%d hash=%s"):format(refreshVersion, tostring(newHash)))
		return true
	end

	local function refreshCommunity(force)
		if not getCommunityState and not getSocialGoalsState then
			return
		end
		local now = os.clock()
		if not force and (now - lastFetch) < REFRESH_DEBOUNCE then
			return
		end
		lastFetch = now
		local ok, result = pcall(function()
			if getSocialGoalsState then
				return getSocialGoalsState:InvokeServer()
			end
			return getCommunityState:InvokeServer()
		end)
		if ok and typeof(result) == "table" then
			applySnapshot(result)
		else
			render(nil)
		end
	end

	local function requestClaim(mode)
		if not claimSocialMilestone then
			return
		end
		local ok, result = pcall(function()
			return claimSocialMilestone:InvokeServer(mode)
		end)
		if ok and typeof(result) == "table" then
			applySnapshot(result)
		else
			showToast("Claim failed")
		end
	end

	if retryButton and retryButton:IsA("GuiButton") then
		retryButton.MouseButton1Click:Connect(function()
			refreshCommunity(true)
		end)
	end

	if favoriteClaimButton and favoriteClaimButton:IsA("TextButton") then
		favoriteClaimButton.MouseButton1Click:Connect(function()
			local ok, result
			if claimSocialMilestone and currentFavoriteId then
				ok, result = pcall(function()
					return claimSocialMilestone:InvokeServer("favorites", currentFavoriteId)
				end)
			elseif claimFavoriteReward then
				ok, result = pcall(function()
					return claimFavoriteReward:InvokeServer()
				end)
			end
			if ok and typeof(result) == "table" then
				applySnapshot(result)
				refreshCommunity(true)
			else
				showToast("Claim failed")
			end
		end)
	end

	if claimNextButton and claimNextButton:IsA("TextButton") then
		claimNextButton.MouseButton1Click:Connect(function()
			requestClaim("next")
			refreshCommunity(true)
		end)
	end

	if claimAllButton and claimAllButton:IsA("TextButton") then
		claimAllButton.MouseButton1Click:Connect(function()
			requestClaim("all")
			refreshCommunity(true)
		end)
	end

	if communityStateUpdated then
		communityStateUpdated.OnClientEvent:Connect(function(state)
			if typeof(state) == "table" then
				applySnapshot(state)
			end
		end)
	end
	if socialGoalsUpdated then
		socialGoalsUpdated.OnClientEvent:Connect(function(state)
			if typeof(state) == "table" then
				applySnapshot(state)
			end
		end)
	end

	function CommunityController.Open()
		refreshCommunity(true)
	end

	function CommunityController.Refresh()
		refreshCommunity(true)
	end

	task.spawn(function()
		while true do
			task.wait(AUTO_REFRESH_SEC)
			if communityPage and communityPage.Visible then
				refreshCommunity(false)
			end
		end
	end)

	return true
end

return CommunityController

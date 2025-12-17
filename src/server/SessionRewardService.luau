local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SessionRewardService = {}

local TRACK_INTERVAL = 1

local rewardsConfig = {
	{
		id = "session_5_min",
		thresholdSeconds = 5 * 60,
		durationSeconds = 5 * 60,
		effects = {
			dataMultiplier = 1.25,
		},
	},
	{
		id = "session_10_min",
		thresholdSeconds = 10 * 60,
		durationSeconds = 10 * 60,
		effects = {
			automationSpeedMultiplier = 1.2,
		},
	},
	{
		id = "session_20_min",
		thresholdSeconds = 20 * 60,
		durationSeconds = 5 * 60,
		effects = {
			dataMultiplier = 2,
			automationSpeedMultiplier = 2,
		},
	},
}

local rewardsById = {}
for _, reward in ipairs(rewardsConfig) do
	rewardsById[reward.id] = reward
end

local targetSeconds = rewardsConfig[#rewardsConfig].thresholdSeconds

local playerStates = {}
local accumulatedTime = 0
local initialized = false

local function getOrCreateState(player)
	local state = playerStates[player]
	if state then
		return state
	end

	state = {
		startTime = time(),
		rewards = {},
		dataMultiplier = 1,
		automationMultiplier = 1,
		pendingActivations = {},
		elapsed = 0,
	}
	playerStates[player] = state
	return state
end

local function recomputeMultipliers(state)
	local dataMultiplier = 1
	local automationMultiplier = 1

	for _, reward in ipairs(rewardsConfig) do
		local rewardState = state.rewards[reward.id]
		if rewardState and rewardState.active then
			if reward.effects.dataMultiplier then
				dataMultiplier *= reward.effects.dataMultiplier
			end
			if reward.effects.automationSpeedMultiplier then
				automationMultiplier *= reward.effects.automationSpeedMultiplier
			end
		end
	end

	state.dataMultiplier = dataMultiplier
	state.automationMultiplier = automationMultiplier
end

local function updateRewards(state, now)
	local changed = false
	local elapsed = math.max(0, now - state.startTime)
	state.elapsed = elapsed

	for _, reward in ipairs(rewardsConfig) do
		local rewardState = state.rewards[reward.id]
		if not rewardState then
			rewardState = {}
			state.rewards[reward.id] = rewardState
		end

		if not rewardState.completed then
			if not rewardState.active and elapsed >= reward.thresholdSeconds then
				rewardState.active = true
				rewardState.completed = false
				rewardState.expiresAt = now + reward.durationSeconds
				table.insert(state.pendingActivations, reward.id)
				changed = true
			end
		end

		if rewardState.active and rewardState.expiresAt and now >= rewardState.expiresAt then
			rewardState.active = false
			rewardState.completed = true
			changed = true
		end
	end

	if changed then
		recomputeMultipliers(state)
	end
end

function SessionRewardService.Tick()
	local now = time()
	for player, state in pairs(playerStates) do
		if player and player.Parent then
			updateRewards(state, now)
		else
			playerStates[player] = nil
		end
	end
end

function SessionRewardService.PlayerAdded(player)
	local state = getOrCreateState(player)
	state.startTime = time()
	state.rewards = {}
	state.pendingActivations = {}
	state.dataMultiplier = 1
	state.automationMultiplier = 1
	state.elapsed = 0
end

function SessionRewardService.PlayerRemoving(player)
	playerStates[player] = nil
end

function SessionRewardService.GetDataMultiplier(player)
	local state = playerStates[player]
	if not state then
		return 1
	end
	return state.dataMultiplier or 1
end

function SessionRewardService.GetAutomationMultiplier(player)
	local state = playerStates[player]
	if not state then
		return 1
	end
	return state.automationMultiplier or 1
end

function SessionRewardService.GetProgress(player)
	local state = playerStates[player]
	if not state then
		return nil
	end

	local progress = {
		elapsedSeconds = math.clamp(math.floor(state.elapsed or 0), 0, targetSeconds),
		targetSeconds = targetSeconds,
		activeRewards = {},
	}

	local now = time()
	for _, reward in ipairs(rewardsConfig) do
		local rewardState = state.rewards[reward.id]
		if rewardState and rewardState.active and rewardState.expiresAt then
			table.insert(progress.activeRewards, {
				id = reward.id,
				remainingSeconds = math.max(0, math.floor(rewardState.expiresAt - now)),
			})
		end
	end

	return progress
end

function SessionRewardService.PopPendingActivations(player)
	local state = playerStates[player]
	if not state or not state.pendingActivations then
		return nil
	end

	if #state.pendingActivations == 0 then
		return nil
	end

	local activations = table.clone(state.pendingActivations)
	table.clear(state.pendingActivations)
	return activations
end

local function onPlayerAdded(player)
	SessionRewardService.PlayerAdded(player)
end

local function onPlayerRemoving(player)
	SessionRewardService.PlayerRemoving(player)
end

function SessionRewardService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		accumulatedTime += dt
		while accumulatedTime >= TRACK_INTERVAL do
			accumulatedTime -= TRACK_INTERVAL
			SessionRewardService.Tick()
		end
	end)
end

SessionRewardService.Init()

return SessionRewardService

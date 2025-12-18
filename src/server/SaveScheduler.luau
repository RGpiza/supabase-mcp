local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local SAVE_INTERVAL = 45
local POLL_INTERVAL = 10

local SaveScheduler = {}

local playerStates = {}
local schedulerActive = false

local function getUserId(player)
	if not player or not player.UserId then
		return nil
	end
	return tostring(player.UserId)
end

local function cleanupState(userId)
	if not userId then
		return
	end
	playerStates[userId] = nil
end

local function getOrCreateState(player)
	if not player then
		return nil
	end

	local userId = getUserId(player)
	if not userId then
		return nil
	end

	local state = playerStates[userId]
	if not state then
		state = {
			player = player,
			dirty = false,
			dirtyVersion = 0,
			lastSave = 0,
			saving = false,
		}
		playerStates[userId] = state
	else
		state.player = player
	end

	return state
end

local function schedulerStep()
	local now = os.clock()
	local hasPending = false
	for userId, state in pairs(playerStates) do
		local player = state.player
		if not player or not player.Parent then
			cleanupState(userId)
		elseif state.dirty then
			hasPending = true
			local elapsed = now - (state.lastSave or 0)
			if not state.saving and (state.lastSave == 0 or elapsed >= SAVE_INTERVAL) then
				SaveScheduler.FlushPlayer(player, false)
			end
		end
	end
	return hasPending
end

local function ensureScheduler()
	if schedulerActive then
		return
	end

	schedulerActive = true
	task.spawn(function()
		while schedulerStep() do
			task.wait(POLL_INTERVAL)
		end
		schedulerActive = false
	end)
end

function SaveScheduler.MarkDirty(player)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	state.dirty = true
	state.dirtyVersion = (state.dirtyVersion or 0) + 1
	ensureScheduler()
end

function SaveScheduler.FlushPlayer(player, force)
	local state = getOrCreateState(player)
	if not state then
		return false
	end

	local userId = getUserId(player)

	if state.saving then
		if force then
			while state.saving do
				task.wait()
			end
		else
			return false
		end
	end

	if not force then
		if not state.dirty then
			return true
		end

		local now = os.clock()
		if state.lastSave > 0 and (now - state.lastSave) < SAVE_INTERVAL then
			return false
		end
	end

	state.saving = true
	local saveVersion = state.dirtyVersion
	local success = PlayerDataService.Save(player)
	state.saving = false

	if success then
		state.lastSave = os.clock()
		if state.dirtyVersion == saveVersion then
			state.dirty = false
		end
		if not player or not player.Parent then
			cleanupState(userId)
		end
		return true
	end

	state.dirty = true
	ensureScheduler()
	return false
end

function SaveScheduler.Forget(player)
	local userId = getUserId(player)
	if userId then
		cleanupState(userId)
	end
end

PlayerDataService.OnAfterSet(function(player)
	if player then
		SaveScheduler.MarkDirty(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	SaveScheduler.Forget(player)
end)

return SaveScheduler

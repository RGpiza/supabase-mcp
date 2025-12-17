local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local GlobalAnnouncementService = {}

local ANNOUNCEMENT_COOLDOWN = 300
local ANNOUNCEMENT_COLOR = Color3.fromRGB(208, 220, 235)

local dataMilestones = {
	{ id = "data_1e6", value = 1e6, label = "1e6 Data" },
	{ id = "data_1e8", value = 1e8, label = "1e8 Data" },
	{ id = "data_1e10", value = 1e10, label = "1e10 Data" },
	{ id = "data_1e12", value = 1e12, label = "1e12 Data" },
	{ id = "data_1e15", value = 1e15, label = "1e15 Data" },
}

local announcementEvent
local lastAnnouncementTimes = {}
local initialized = false

local function ensureMilestoneTables(state)
	if typeof(state.globalMilestones) ~= "table" then
		state.globalMilestones = {}
	end

	local container = state.globalMilestones
	if typeof(container.data) ~= "table" then
		container.data = {}
	end
	if typeof(container.prestige) ~= "table" then
		container.prestige = {}
	end
	if typeof(container.prestigeMultiples) ~= "table" then
		container.prestigeMultiples = {}
	end

	return container
end

local function dispatchAnnouncement(player, milestoneText)
	if not announcementEvent or not player or not player.Parent then
		return false
	end

	local now = os.time()
	local last = lastAnnouncementTimes[player]
	if last and now - last < ANNOUNCEMENT_COOLDOWN then
		return false
	end

	lastAnnouncementTimes[player] = now
	announcementEvent:FireAllClients({
		message = string.format("🌐 %s just reached %s!", player.Name, milestoneText),
		color = ANNOUNCEMENT_COLOR,
	})

	return true
end

local function trackDataMilestone(player, previousState, newState)
	local prevData = typeof(previousState.data) == "number" and previousState.data or 0
	local newData = typeof(newState.data) == "number" and newState.data or 0
	if newData <= prevData then
		return nil
	end

	local milestones = ensureMilestoneTables(newState).data
	local triggeredLabel

	for _, milestone in ipairs(dataMilestones) do
		if not milestones[milestone.id] then
			if prevData < milestone.value and newData >= milestone.value then
				milestones[milestone.id] = true
				triggeredLabel = milestone.label
			end
		end
	end

	return triggeredLabel
end

local function trackPrestigeMilestones(previousState, newState)
	local prevPrestige = typeof(previousState.prestige) == "number" and previousState.prestige or 0
	local newPrestige = typeof(newState.prestige) == "number" and newState.prestige or 0
	if newPrestige <= prevPrestige then
		return nil
	end

	local container = ensureMilestoneTables(newState)
	local prestigeState = container.prestige
	local multiplesState = container.prestigeMultiples

	if not prestigeState.first and prevPrestige < 1 and newPrestige >= 1 then
		prestigeState.first = true
		return "their first Prestige"
	end

	local prevMultiple = math.floor(prevPrestige / 10)
	local newMultiple = math.floor(newPrestige / 10)
	if newMultiple > prevMultiple then
		local milestoneLevel = newMultiple * 10
		local key = tostring(milestoneLevel)
		if not multiplesState[key] then
			multiplesState[key] = true
			return string.format("Prestige %d", milestoneLevel)
		end
	end

	return nil
end

local function handlePlayerDataChanged(player, previousState, newState)
	if not player or not previousState or not newState then
		return
	end

	local prestigeMessage = trackPrestigeMilestones(previousState, newState)
	if prestigeMessage then
		if dispatchAnnouncement(player, prestigeMessage) then
			return
		end
	end

	local dataMessage = trackDataMilestone(player, previousState, newState)
	if dataMessage then
		dispatchAnnouncement(player, dataMessage)
	end
end

function GlobalAnnouncementService.Init(remoteEvent)
	if initialized then
		return
	end
	initialized = true
	announcementEvent = remoteEvent

	PlayerDataService.OnAfterSet(handlePlayerDataChanged)

	Players.PlayerRemoving:Connect(function(player)
		lastAnnouncementTimes[player] = nil
	end)
end

return GlobalAnnouncementService

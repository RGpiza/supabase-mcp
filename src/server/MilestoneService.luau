local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

local MilestoneService = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local milestoneRemote = remotesFolder and remotesFolder:FindFirstChild("MilestoneNotification")

type PlayerState = {
	data: number?,
	upgrades: { [string]: number }?,
	prestige: number?,
	corePower: number?,
	milestones: { [string]: boolean }?,
}

local milestones = {
	{
		id = "storage_tier_2",
		description = "Reach Storage Tier II",
		condition = function(state: PlayerState)
			return UpgradeConfig.GetStorageTier(state.upgrades or {}) >= 2
		end,
		reward = function(state: PlayerState)
			state.data = (state.data or 0) + 10_000
		end,
		message = "Storage Tier II unlocked! Bonus 10,000 Data.",
	},
	{
		id = "storage_tier_3",
		description = "Reach Storage Tier III",
		condition = function(state: PlayerState)
			return UpgradeConfig.GetStorageTier(state.upgrades or {}) >= 3
		end,
		reward = function(state: PlayerState)
			state.corePower = (state.corePower or 0) + 1
		end,
		message = "Storage Tier III unlocked! +1 Core Power.",
	},
	{
		id = "first_prestige",
		description = "Complete your first Prestige",
		condition = function(state: PlayerState)
			return (state.prestige or 0) >= 1
		end,
		reward = function(state: PlayerState)
			state.data = (state.data or 0) + 50_000
		end,
		message = "First Prestige complete! Bonus 50,000 Data.",
	},
}

local function ensureMilestoneTable(state: PlayerState)
	if typeof(state.milestones) ~= "table" then
		state.milestones = {}
	end
	return state.milestones
end

local function notifyClient(player, milestoneId, message)
	if milestoneRemote then
		milestoneRemote:FireClient(player, milestoneId, message)
	end
end

local function applyMilestones(player, state: PlayerState)
	local completed = ensureMilestoneTable(state)
	local changed = false

	for _, milestone in ipairs(milestones) do
		if not completed[milestone.id] and milestone.condition(state) then
			if milestone.reward then
				milestone.reward(state)
			end
			completed[milestone.id] = true
			changed = true
			notifyClient(player, milestone.id, milestone.message or milestone.description)
		end
	end

	if changed then
		PlayerDataService.Set(player, state)
	end
end

function MilestoneService.CheckMilestones(player)
	local state = PlayerDataService.Get(player)
	if typeof(state) ~= "table" then
		return
	end

	applyMilestones(player, state)
end

return MilestoneService

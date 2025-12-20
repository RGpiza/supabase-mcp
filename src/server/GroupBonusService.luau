local GroupBonusService = {}

local GROUP_ID = 1_032_797_065 -- Arcadi Games
local GROUP_MULTIPLIER = 1.10

local membershipCache = {}

local function checkMembership(player)
	if membershipCache[player] ~= nil then
		return membershipCache[player]
	end

	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)

	if not success then
		warn("[GroupBonusService] Failed to check group membership for", player, isInGroup)
		isInGroup = false
	end

	membershipCache[player] = isInGroup
	return isInGroup
end

function GroupBonusService.IsInGroup(player)
	return checkMembership(player)
end

function GroupBonusService.GetGroupMultiplier(player)
	return checkMembership(player) and GROUP_MULTIPLIER or 1.0
end

function GroupBonusService.Release(player)
	membershipCache[player] = nil
end

return GroupBonusService

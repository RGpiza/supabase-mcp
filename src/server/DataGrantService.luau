local PlayerDataService = require(script.Parent.PlayerDataService)
local GlobalStatsService = require(script.Parent.GlobalStatsService)

local DataGrantService = {}

local function sanitizeAmount(amount)
	local numeric = tonumber(amount)
	if not numeric then
		return 0
	end
	return math.max(numeric, 0)
end

function DataGrantService.GrantData(player, amount, source)
	if not player then
		return 0, nil
	end

	local grantAmount = sanitizeAmount(amount)
	if grantAmount <= 0 then
		return 0, nil
	end

	local state = PlayerDataService.Get(player)
	if typeof(state) ~= "table" then
		return 0, nil
	end

	local currentBalance = typeof(state.data) == "number" and state.data or 0
	local newBalance = currentBalance + grantAmount

	PlayerDataService.Set(player, {
		data = newBalance,
	})

	GlobalStatsService.AddData(grantAmount)

	return grantAmount, newBalance
end

return DataGrantService

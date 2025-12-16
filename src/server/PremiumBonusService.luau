local PremiumBonusService = {}

local PREMIUM_MULTIPLIER = 1.25

local premiumCache = {}

local function cacheMembership(player)
	if premiumCache[player] ~= nil then
		return premiumCache[player]
	end

	local hasPremium = false

	if player then
		local success, result = pcall(function()
			return player.MembershipType == Enum.MembershipType.Premium
		end)

		if success then
			hasPremium = result
		else
			warn("[PremiumBonusService] Membership check failed for", player, result)
		end
	end

	premiumCache[player] = hasPremium
	return hasPremium
end

function PremiumBonusService.HasPremium(player)
	return cacheMembership(player)
end

function PremiumBonusService.GetPremiumMultiplier(player)
	return cacheMembership(player) and PREMIUM_MULTIPLIER or 1.0
end

function PremiumBonusService.Release(player)
	premiumCache[player] = nil
end

return PremiumBonusService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostService = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoostService"))

local OfflineProgress = {}

local function sanitizeTimestamp(value, fallback)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function computeActiveBoostMultiplier(boosts, referenceTime)
	local multiplier = 1

	for boostName, expiration in pairs(boosts) do
		if typeof(expiration) == "number" and expiration > referenceTime then
			local definition = BoostService.GetDefinition(boostName)
			if definition and typeof(definition.multiplier) == "number" then
				multiplier *= definition.multiplier
			end
		end
	end

	return multiplier
end

local function collectNextExpiration(boosts, referenceTime, upperBound)
	local nextExpiration = upperBound
	local hasActive = false

	for _, expiration in pairs(boosts) do
		if typeof(expiration) == "number" and expiration > referenceTime then
			hasActive = true
			if expiration < nextExpiration then
				nextExpiration = expiration
			end
		end
	end

	if not hasActive then
		return nil
	end

	return nextExpiration
end

local function trimExpiredBoosts(boosts, now)
	for boostName, expiration in pairs(boosts) do
		if typeof(expiration) ~= "number" or expiration <= now then
			boosts[boostName] = nil
		end
	end
end

function OfflineProgress.Calculate(data, baseDps, now)
	if typeof(data) ~= "table" then
		return 0, now
	end

	local sanitizedNow = sanitizeTimestamp(now, os.time())
	local lastSeen = sanitizeTimestamp(data.lastSeen, sanitizedNow)

	if sanitizedNow <= lastSeen or typeof(baseDps) ~= "number" or baseDps <= 0 then
		data.lastSeen = sanitizedNow
		trimExpiredBoosts(data.boosts or {}, sanitizedNow)
		return 0, sanitizedNow
	end

	local boosts = data.boosts
	if typeof(boosts) ~= "table" then
		boosts = {}
		data.boosts = boosts
	end

	local totalGain = 0
	local baseGain = 0
	local boostedGain = 0
	local cursor = lastSeen
	local usedBoosts = false

	while cursor < sanitizedNow do
		local nextExpiration = collectNextExpiration(boosts, cursor, sanitizedNow)
		local segmentEnd = nextExpiration and math.min(nextExpiration, sanitizedNow) or sanitizedNow
		local duration = math.max(0, segmentEnd - cursor)
		if duration <= 0 then
			break
		end

		local multiplier = computeActiveBoostMultiplier(boosts, cursor)
		local clampedMultiplier = math.max(1, multiplier)
		local baseSegment = baseDps * duration
		local boostedSegment = baseDps * math.max(0, clampedMultiplier - 1) * duration

		if multiplier > 1 then
			usedBoosts = true
		end

		baseGain += baseSegment
		boostedGain += boostedSegment
		totalGain += baseSegment + boostedSegment

		cursor = segmentEnd
		if not nextExpiration then
			break
		end
	end

	trimExpiredBoosts(boosts, sanitizedNow)
	data.lastSeen = sanitizedNow
	return totalGain, sanitizedNow, usedBoosts, baseGain, boostedGain
end

return OfflineProgress

local BoostService = {}

local BOOST_DEFINITIONS = {
	["+5 Min Boost"] = {
		duration = 5 * 60,
		multiplier = 2,
		sku = "Dev_5MinBoost",
	},
	["+1 Hour Boost"] = {
		duration = 60 * 60,
		multiplier = 2,
		sku = "Dev_1HourBoost",
	},
}

function BoostService.GetDefinition(boostName)
	return BOOST_DEFINITIONS[boostName]
end

function BoostService.GetDefinitions()
	return BOOST_DEFINITIONS
end

function BoostService.GetMultiplier(boostName)
	local definition = BOOST_DEFINITIONS[boostName]
	if definition and typeof(definition.multiplier) == "number" then
		return definition.multiplier
	end
	return 1
end

return BoostService

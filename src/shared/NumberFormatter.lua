local NumberFormatter = {}

local FORMAT_STEPS = {
	{
		limit = 1_000,
		divisor = 1,
		suffix = "",
	},
	{
		limit = 1_000_000,
		divisor = 1_000,
		suffix = "K",
	},
	{
		limit = 1_000_000_000,
		divisor = 1_000_000,
		suffix = "M",
	},
	{
		limit = 1_000_000_000_000,
		divisor = 1_000_000_000,
		suffix = "B",
	},
}

local function trimTrailingZeros(text)
	local trimmed = text:gsub("%.?0+$", "")
	if trimmed == "" or trimmed == "-" then
		return "0"
	end
	return trimmed
end

local function formatWithSuffix(value, divisor, suffix)
	local scaled = value / divisor
	local formatted = string.format("%.2f", scaled)
	return trimTrailingZeros(formatted) .. suffix
end

function NumberFormatter.format(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return "0"
	end

	local absValue = math.abs(numberValue)

	for _, step in FORMAT_STEPS do
		if absValue < step.limit then
			return formatWithSuffix(numberValue, step.divisor, step.suffix)
		end
	end

	return string.format("%.2e", numberValue)
end

return NumberFormatter

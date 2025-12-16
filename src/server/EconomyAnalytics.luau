local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local EconomyAnalytics = {}

local CURRENCY_NAME = "Data"

local function sanitizeAmount(amount)
	if typeof(amount) ~= "number" or amount <= 0 then
		return nil
	end
	return amount
end

local function sanitizeBalance(balance)
	if typeof(balance) ~= "number" then
		return 0
	end
	return math.max(balance, 0)
end

local function sanitizeSku(sku)
	if typeof(sku) == "string" and sku ~= "" then
		return sku
	end
	return nil
end

local function resolveTransactionType(transactionType)
	if typeof(transactionType) == "string" then
		return transactionType
	end

	if typeof(transactionType) == "EnumItem" then
		return transactionType.Name
	end

	return "Gameplay"
end

local function logEconomyEvent(player, flowType, transactionType, amount, balanceAfter, sku, customFields)
	if RunService:IsStudio() then
		return
	end

	local sanitizedAmount = sanitizeAmount(amount)
	if not sanitizedAmount then
		return
	end

	local sanitizedBalance = sanitizeBalance(balanceAfter)
	local sanitizedSku = sanitizeSku(sku)

	local success, err = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			CURRENCY_NAME,
			sanitizedAmount,
			sanitizedBalance,
			resolveTransactionType(transactionType),
			sanitizedSku or "",
			customFields
		)
	end)

	if not success then
		warn("[EconomyAnalytics] Failed to log economy event:", err)
	end
end

function EconomyAnalytics.LogSource(player, amount, balanceAfter, transactionType, sku, customFields)
	if not player then
		return
	end

	logEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		transactionType or Enum.AnalyticsEconomyTransactionType.Gameplay,
		amount,
		balanceAfter,
		sku,
		customFields
	)
end

function EconomyAnalytics.LogSink(player, cost, balanceAfter, transactionType, sku, customFields)
	if not player then
		return
	end

	logEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		transactionType or Enum.AnalyticsEconomyTransactionType.Shop,
		cost,
		balanceAfter,
		sku,
		customFields
	)
end

return EconomyAnalytics

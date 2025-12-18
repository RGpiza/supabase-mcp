local PurchaseCooldowns = {}

local registry = {}
local initialized = false

function PurchaseCooldowns.Init()
	if initialized then
		return
	end
	initialized = true
	table.clear(registry)
end

function PurchaseCooldowns.Reset()
	table.clear(registry)
end

function PurchaseCooldowns.CanPurchase(upgradeId, now, debounce)
	if typeof(upgradeId) ~= "string" then
		return false
	end

	local timestamp = typeof(now) == "number" and now or os.clock()
	local limit = typeof(debounce) == "number" and debounce or 0
	local last = registry[upgradeId]
	if last and timestamp - last < limit then
		return false
	end

	return true
end

function PurchaseCooldowns.MarkPurchased(upgradeId, now)
	if typeof(upgradeId) ~= "string" then
		return
	end
	registry[upgradeId] = typeof(now) == "number" and now or os.clock()
end

return PurchaseCooldowns

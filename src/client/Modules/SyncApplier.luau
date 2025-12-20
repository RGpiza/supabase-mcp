local SyncApplier = {}

function SyncApplier.Apply(payload, context)
	if typeof(payload) ~= "table" or type(context) ~= "table" then
		return false
	end

	local playerState = context.playerState
	local cachedStateRef = context.cachedStateRef
	local displayedDataRef = context.displayedDataRef
	if not (playerState and cachedStateRef and displayedDataRef) then
		return false
	end

	playerState.data = typeof(payload.data) == "number" and payload.data or 0
	playerState.upgrades = typeof(payload.upgrades) == "table" and payload.upgrades or {}
	playerState.prestige = typeof(payload.prestige) == "number" and payload.prestige or 0
	playerState.corePower = typeof(payload.corePower) == "number" and payload.corePower or 0
	playerState.dps = typeof(payload.dps) == "number" and payload.dps or 0

	local stateClone = table.clone(payload)
	stateClone.data = playerState.data
	stateClone.upgrades = playerState.upgrades
	stateClone.prestige = playerState.prestige
	stateClone.corePower = playerState.corePower
	stateClone.dps = playerState.dps
	cachedStateRef.value = stateClone

	if displayedDataRef.value == nil then
		displayedDataRef.value = playerState.data
	else
		local targetValue = playerState.data or 0
		local snapThreshold = math.max(math.abs(targetValue) * 0.05, 100)
		if math.abs(targetValue - displayedDataRef.value) > snapThreshold then
			displayedDataRef.value = targetValue
		end
	end

	if context.activateCoreSystems then
		context.activateCoreSystems(payload)
	end

	if context.refreshAllCards then
		context.refreshAllCards()
	end
	if context.updateAutoBuyRecommendation then
		context.updateAutoBuyRecommendation(context.autoBuyContext)
	end
	if context.rebindUpgrades then
		context.rebindUpgrades(payload)
	end

	return true
end

return SyncApplier

local AutoBuyController = {}

local toggledEvent = Instance.new("BindableEvent")
AutoBuyController.Toggled = toggledEvent.Event

local stateByCategory = {
	CPU = false,
	RAM = false,
	STO = false,
}

function AutoBuyController.Init()
	return
end

function AutoBuyController.SetEnabled(category, enabled)
	if category ~= "CPU" and category ~= "RAM" and category ~= "STO" then
		return
	end
	local nextState = enabled == true
	if stateByCategory[category] == nextState then
		return
	end
	stateByCategory[category] = nextState
	toggledEvent:Fire(category, nextState)
end

function AutoBuyController.GetEnabled(category)
	if category ~= "CPU" and category ~= "RAM" and category ~= "STO" then
		return false
	end
	return stateByCategory[category] == true
end

return AutoBuyController

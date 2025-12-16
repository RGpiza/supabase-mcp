local AutomationConfig = {}

type AutomationDefinition = {
	id: string,
	name: string,
	description: string,
	unlockRequirement: {
		storageTier: number?,
		milestone: string?,
	},
	intervalSeconds: number,
	enabledByDefault: boolean,
}

local definitions: { AutomationDefinition } = {
	{
		id = "auto_cpu",
		name = "CPU Auto Builder",
		description = "Automatically purchases CPU upgrades when possible.",
		unlockRequirement = {
			storageTier = 1,
		},
		intervalSeconds = 2.0,
		enabledByDefault = false,
	},
	{
		id = "auto_ram",
		name = "RAM Auto Optimizer",
		description = "Automatically purchases RAM upgrades when possible.",
		unlockRequirement = {
			storageTier = 2,
		},
		intervalSeconds = 2.0,
		enabledByDefault = false,
	},
}

local byId = {}
for _, automation in ipairs(definitions) do
	byId[automation.id] = automation
end

function AutomationConfig.GetAll()
	return definitions
end

function AutomationConfig.GetById(id)
	return byId[id]
end

return AutomationConfig

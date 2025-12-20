local AutomationConfig = {}

type AutomationDefinition = {
	id: string,
	branch: string,
	attribute: string,
	name: string,
	description: string,
	unlockRequirement: {
		storageTier: number?,
	},
	enabledByDefault: boolean,
}

local definitions: { AutomationDefinition } = {
	{
		id = "auto_cpu",
		branch = "CPU",
		attribute = "AutoBuyCPU",
		name = "CPU Auto Builder",
		description = "Automatically purchases CPU upgrades when possible.",
		unlockRequirement = {
			storageTier = 0,
		},
		enabledByDefault = false,
	},
	{
		id = "auto_ram",
		branch = "RAM",
		attribute = "AutoBuyRAM",
		name = "RAM Auto Optimizer",
		description = "Automatically purchases RAM upgrades when possible.",
		unlockRequirement = {
			storageTier = 0,
		},
		enabledByDefault = false,
	},
	{
		id = "auto_storage",
		branch = "STORAGE",
		attribute = "AutoBuySTORAGE",
		name = "Storage Auto Architect",
		description = "Automatically purchases Storage upgrades when possible.",
		unlockRequirement = {
			storageTier = 0,
		},
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

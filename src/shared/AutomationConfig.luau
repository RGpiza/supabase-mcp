local AutomationConfig = {}

type AutomationDefinition = {
	id: string,
	branch: string,
	attribute: string,
	name: string,
	description: string,
	unlockRequirement: {
		storageTier: number?,
		prestigeLevel: number?,
	},
	enabledByDefault: boolean,
}

type SpeedTierDefinition = {
	tier: number,
	name: string,
	description: string,
	interval: number,
	cost: number,
}

local DEFAULT_PRIORITY = { "auto_cpu", "auto_ram", "auto_storage" }
local PRESET_SLOT_COUNT = 4

local DEFAULT_PRESETS = {
	{
		name = "Balanced",
		enabled = {
			auto_cpu = true,
			auto_ram = true,
			auto_storage = true,
		},
		priority = table.clone(DEFAULT_PRIORITY),
		speedTier = 0,
	},
	{
		name = "CPU Rush",
		enabled = {
			auto_cpu = true,
			auto_ram = false,
			auto_storage = false,
		},
		priority = table.clone(DEFAULT_PRIORITY),
		speedTier = 0,
	},
	{
		name = "Storage Push",
		enabled = {
			auto_cpu = false,
			auto_ram = false,
			auto_storage = true,
		},
		priority = { "auto_storage", "auto_cpu", "auto_ram" },
		speedTier = 0,
	},
	{
		name = "Custom Slot",
		enabled = {
			auto_cpu = true,
			auto_ram = true,
			auto_storage = false,
		},
		priority = table.clone(DEFAULT_PRIORITY),
		speedTier = 0,
	},
}

local speedUpgrades: { SpeedTierDefinition } = {
	{
		tier = 0,
		name = "Base Routine",
		description = "Base scan every 0.5s.",
		interval = 0.5,
		cost = 0,
	},
	{
		tier = 1,
		name = "Turbo Scripts",
		description = "0.4s interval.",
		interval = 0.4,
		cost = 25_000,
	},
	{
		tier = 2,
		name = "Quantum Queue",
		description = "0.3s interval.",
		interval = 0.3,
		cost = 250_000,
	},
	{
		tier = 3,
		name = "Neural Dispatcher",
		description = "0.2s interval.",
		interval = 0.2,
		cost = 2_500_000,
	},
	{
		tier = 4,
		name = "Singularity Loop",
		description = "0.1s interval.",
		interval = 0.1,
		cost = 25_000_000,
	},
}

local definitions: { AutomationDefinition } = {
	{
		id = "auto_cpu",
		branch = "CPU",
		attribute = "AutoBuyCPU",
		name = "CPU Auto Builder",
		description = "Automatically purchases CPU upgrades when possible.",
		unlockRequirement = {
			prestigeLevel = 1,
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
			prestigeLevel = 2,
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
			prestigeLevel = 3,
		},
		enabledByDefault = false,
	},
}

local byId = {}
for _, automation in ipairs(definitions) do
	byId[automation.id] = automation
end

local function cloneTable(source)
	local copy = {}
	for key, value in pairs(source) do
		if typeof(value) == "table" then
			copy[key] = cloneTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function AutomationConfig.GetAll()
	return definitions
end

function AutomationConfig.GetById(id)
	return byId[id]
end

function AutomationConfig.GetDefaultPriority()
	return table.clone(DEFAULT_PRIORITY)
end

function AutomationConfig.GetSpeedUpgrades()
	return speedUpgrades
end

function AutomationConfig.GetSpeedTierInfo(tier)
	local numericTier = typeof(tier) == "number" and math.floor(tier) or 0
	local clamped = math.clamp(numericTier, 0, speedUpgrades[#speedUpgrades].tier)
	for _, definition in ipairs(speedUpgrades) do
		if definition.tier == clamped then
			return definition
		end
	end
	return speedUpgrades[1]
end

function AutomationConfig.GetMaxSpeedTier()
	return speedUpgrades[#speedUpgrades].tier
end

function AutomationConfig.GetDefaultPresets()
	local list = {}
	for index, preset in ipairs(DEFAULT_PRESETS) do
		list[index] = cloneTable(preset)
	end
	return list
end

function AutomationConfig.GetPresetSlotCount()
	return PRESET_SLOT_COUNT
end

return AutomationConfig

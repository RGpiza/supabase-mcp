local PrestigeConfig = {}

PrestigeConfig.PP_BASE_REQUIREMENT = 1e6
PrestigeConfig.PP_GAIN_POWER = 0.5
PrestigeConfig.PP_GAIN_MULT = 10
PrestigeConfig.PP_CAP = 10000

PrestigeConfig.AUTOMATION_TICK_MS_DEFAULT = 1000

PrestigeConfig.NODES = {
	auto_cpu_1 = {
		cost = 5,
		prereq = nil,
		automationKey = "cpuAuto",
		title = "Auto CPU",
	},
	auto_ram_1 = {
		cost = 8,
		prereq = "auto_cpu_1",
		automationKey = "ramAuto",
		title = "Auto RAM",
	},
	auto_sto_1 = {
		cost = 12,
		prereq = "auto_ram_1",
		automationKey = "stoAuto",
		title = "Auto STO",
	},
}

return PrestigeConfig

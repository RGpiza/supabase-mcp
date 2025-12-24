local PrestigeUpgradesConfig = {}

PrestigeUpgradesConfig.Definitions = {
	-- Core Global Upgrades (Early Game)
	pp_global_mult_1 = {
		id = "pp_global_mult_1",
		name = "Global Overclock",
		description = "Add 5% global data generation multiplier per level",
		cost = 2,
		costScale = 1.6,
		maxLevel = 10,
	},
	pp_cpu_mult_1 = {
		id = "pp_cpu_mult_1",
		name = "CPU Micro-Boost",
		description = "Boost CPU upgrade power by 4% per level",
		cost = 2,
		costScale = 1.6,
		maxLevel = 10,
	},
	pp_ram_mult_1 = {
		id = "pp_ram_mult_1",
		name = "RAM Burst",
		description = "Boost RAM upgrade power by 4% per level",
		cost = 2,
		costScale = 1.6,
		maxLevel = 10,
	},
	pp_storage_mult_1 = {
		id = "pp_storage_mult_1",
		name = "Storage Amplifier",
		description = "Boost Storage upgrade power by 5% per level",
		cost = 3,
		costScale = 1.7,
		maxLevel = 8,
	},
	
	-- Automation Upgrades (Early-Mid Game)
	pp_auto_speed_1 = {
		id = "pp_auto_speed_1",
		name = "Auto Tick",
		description = "Reduce auto-buy interval by 15% per level",
		cost = 3,
		costScale = 1.7,
		maxLevel = 10,
	},
	pp_auto_eff_1 = {
		id = "pp_auto_eff_1",
		name = "Smart Auto",
		description = "Auto-buy chooses upgrades with 20% higher value per level",
		cost = 6,
		costScale = 1.8,
		maxLevel = 5,
	},
	pp_auto_bypass_1 = {
		id = "pp_auto_bypass_1",
		name = "Early Automation",
		description = "Unlock auto upgrades for CPU Mk.II and RAM Mk.II early",
		cost = 25,
		costScale = 1.0,
		maxLevel = 1,
	},
	
	-- Mid-Game Power Upgrades
	pp_offline_core_1 = {
		id = "pp_offline_core_1",
		name = "Offline Surge",
		description = "Increase offline progress strength by 10% per level",
		cost = 6,
		costScale = 1.7,
		maxLevel = 6,
	},
	pp_prestige_gain_1 = {
		id = "pp_prestige_gain_1",
		name = "Prestige Yield",
		description = "Gain 8% more Prestige Points per prestige per level",
		cost = 8,
		costScale = 1.9,
		maxLevel = 8,
	},
	pp_prestige_req_1 = {
		id = "pp_prestige_req_1",
		name = "Prestige Shortcut",
		description = "Reduce prestige requirement by 3% per level",
		cost = 10,
		costScale = 2.0,
		maxLevel = 6,
	},
	pp_batch_buy_1 = {
		id = "pp_batch_buy_1",
		name = "Batch Purchase",
		description = "Enable x10 and x100 bulk buying options",
		cost = 12,
		costScale = 2.2,
		maxLevel = 2,
	},
	
	-- Advanced Automation (Mid-Late Game)
	pp_auto_speed_2 = {
		id = "pp_auto_speed_2",
		name = "Hyper Auto",
		description = "Further reduce auto-buy interval by 10% per level",
		cost = 15,
		costScale = 1.8,
		maxLevel = 8,
	},
	pp_auto_eff_2 = {
		id = "pp_auto_eff_2",
		name = "Optimal Auto",
		description = "Auto-buy chooses upgrades with 15% higher value per level",
		cost = 12,
		costScale = 1.9,
		maxLevel = 6,
	},
	pp_auto_unlock_2 = {
		id = "pp_auto_unlock_2",
		name = "Advanced Automation",
		description = "Unlock auto-upgrades for CPU Mk.III and RAM Mk.II",
		cost = 35,
		costScale = 1.0,
		maxLevel = 1,
	},
	
	-- Endgame Scaling (Late Game)
	pp_milestone_amp_1 = {
		id = "pp_milestone_amp_1",
		name = "Milestone Amplifier",
		description = "Add 12% bonus to milestone rewards per level",
		cost = 8,
		costScale = 1.9,
		maxLevel = 5,
	},
	pp_endgame_boost_1 = {
		id = "pp_endgame_boost_1",
		name = "Singular Boost",
		description = "Add 20% late-game scaling boost per level",
		cost = 40,
		costScale = 2.5,
		maxLevel = 3,
	},
	pp_softcap_smooth_1 = {
		id = "pp_softcap_smooth_1",
		name = "Softcap Smoothing",
		description = "Reduce upgrade cost scaling by 1.5% per level",
		cost = 30,
		costScale = 2.2,
		maxLevel = 4,
	},
	pp_global_mult_2 = {
		id = "pp_global_mult_2",
		name = "Universal Overclock II",
		description = "Add 8% global multiplier per level",
		cost = 18,
		costScale = 1.7,
		maxLevel = 12,
	},
	pp_offline_duration_1 = {
		id = "pp_offline_duration_1",
		name = "Extended Offline",
		description = "Add 15 minutes to offline progress duration per level",
		cost = 25,
		costScale = 2.0,
		maxLevel = 6,
	},
	pp_ui_enhance_1 = {
		id = "pp_ui_enhance_1",
		name = "Enhanced Interface",
		description = "Show real-time DPS calculations and upgrade comparisons",
		cost = 25,
		costScale = 1.0,
		maxLevel = 1,
	},
}

return PrestigeUpgradesConfig

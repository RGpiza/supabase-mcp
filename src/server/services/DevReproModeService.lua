local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DebugConfig = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end

-- Import services for integration
local ProductionFeedbackService = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent.ProductionFeedbackService)
	end)
	if ok and type(mod) == "table" then
		ProductionFeedbackService = mod
	end
end

local AntiCheatService = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent.AntiCheatService)
	end)
	if ok and type(mod) == "table" then
		AntiCheatService = mod
	end
end

local DevReproModeService = {}

-- Configuration
local CONFIG = {
	-- Only available in Studio
	ENABLED = RunService:IsStudio(),
	
	-- Simulation settings
	SIMULATION_DELAY = 2, -- seconds between simulated errors
	MAX_SIMULTANEOUS_ERRORS = 5,
	
	-- Error simulation types
	ERROR_TYPES = {
		SERVER_ERROR = {
			serviceName = "ProductionService",
			shortMessage = "Simulated server error for testing",
			severity = 3,
		},
		REMOTE_MISUSE = {
			serviceName = "RemoteRouter",
			shortMessage = "Simulated remote misuse for testing",
			severity = 2,
		},
		DATASTORE_FAILURE = {
			serviceName = "PlayerDataService",
			shortMessage = "Simulated DataStore failure for testing",
			severity = 4,
		},
		ANTICHEAT_ESCALATION = {
			serviceName = "AntiCheatService",
			shortMessage = "Simulated anti-cheat escalation for testing",
			severity = 2,
		},
		ECONOMY_ROLLBACK = {
			serviceName = "ProductionService",
			shortMessage = "Simulated economy rollback for testing",
			severity = 4,
		},
		SERVICE_CRASH = {
			serviceName = "ProductionService",
			shortMessage = "Simulated service crash for testing",
			severity = 4,
		},
	},
}

-- Internal state
local isReproModeActive = false
local simulationTasks = {}
local simulatedErrors = {}

-- Utility functions
local function log(level, message, ...)
	if DebugConfig then
		if level == "error" then
			DebugConfig.Error(message, ...)
		elseif level == "warn" then
			DebugConfig.Warn(message, ...)
		else
			DebugConfig.Log(message, ...)
		end
	end
end

local function getSimulationId()
	return "sim_" .. HttpService:GenerateGUID(false)
end

-- Error simulation functions
local function simulateServerError()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	local errorType = CONFIG.ERROR_TYPES.SERVER_ERROR
	ProductionFeedbackService.ReportServerError(
		errorType.serviceName,
		errorType.shortMessage,
		0 -- No player for server errors
	)
	
	log("info", "Simulated server error")
end

local function simulateRemoteMisuse()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	local errorType = CONFIG.ERROR_TYPES.REMOTE_MISUSE
	ProductionFeedbackService.ReportRemoteMisuse(
		errorType.serviceName,
		errorType.shortMessage,
		123456789 -- Simulated player ID
	)
	
	log("info", "Simulated remote misuse")
end

local function simulateDataStoreFailure()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	local errorType = CONFIG.ERROR_TYPES.DATASTORE_FAILURE
	ProductionFeedbackService.ReportDataStoreFailure(
		errorType.serviceName,
		errorType.shortMessage,
		987654321 -- Simulated player ID
	)
	
	log("info", "Simulated DataStore failure")
end

local function simulateAntiCheatEscalation()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	local errorType = CONFIG.ERROR_TYPES.ANTICHEAT_ESCALATION
	ProductionFeedbackService.ReportAntiCheatEscalation(
		errorType.serviceName,
		errorType.shortMessage,
		555666777 -- Simulated player ID
	)
	
	log("info", "Simulated anti-cheat escalation")
end

local function simulateEconomyRollback()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	local errorType = CONFIG.ERROR_TYPES.ECONOMY_ROLLBACK
	ProductionFeedbackService.ReportEconomyRollback(
		errorType.serviceName,
		errorType.shortMessage,
		111222333 -- Simulated player ID
	)
	
	log("info", "Simulated economy rollback")
end

local function simulateServiceCrash()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	local errorType = CONFIG.ERROR_TYPES.SERVICE_CRASH
	ProductionFeedbackService.ReportServiceCrash(
		errorType.serviceName,
		errorType.shortMessage,
		0 -- No player for service crashes
	)
	
	log("info", "Simulated service crash")
end

-- Simulation management
local function startErrorSimulation()
	if not CONFIG.ENABLED or isReproModeActive then
		return
	end
	
	isReproModeActive = true
	log("info", "DEV_REPRO_MODE: Starting error simulation")
	
	-- Start various simulation tasks
	simulationTasks.serverError = task.spawn(function()
		while isReproModeActive do
			simulateServerError()
			task.wait(CONFIG.SIMULATION_DELAY * 3)
		end
	end)
	
	simulationTasks.remoteMisuse = task.spawn(function()
		while isReproModeActive do
			simulateRemoteMisuse()
			task.wait(CONFIG.SIMULATION_DELAY * 2)
		end
	end)
	
	simulationTasks.dataStoreFailure = task.spawn(function()
		while isReproModeActive do
			simulateDataStoreFailure()
			task.wait(CONFIG.SIMULATION_DELAY * 5)
		end
	end)
	
	simulationTasks.antiCheatEscalation = task.spawn(function()
		while isReproModeActive do
			simulateAntiCheatEscalation()
			task.wait(CONFIG.SIMULATION_DELAY * 4)
		end
	end)
	
	simulationTasks.economyRollback = task.spawn(function()
		while isReproModeActive do
			simulateEconomyRollback()
			task.wait(CONFIG.SIMULATION_DELAY * 6)
		end
	end)
	
	simulationTasks.serviceCrash = task.spawn(function()
		while isReproModeActive do
			simulateServiceCrash()
			task.wait(CONFIG.SIMULATION_DELAY * 8)
		end
	end)
end

local function stopErrorSimulation()
	if not CONFIG.ENABLED or not isReproModeActive then
		return
	end
	
	isReproModeActive = false
	
	-- Cancel all simulation tasks
	for taskName, taskHandle in pairs(simulationTasks) do
		if taskHandle then
			task.cancel(taskHandle)
		end
	end
	
	simulationTasks = {}
	log("info", "DEV_REPRO_MODE: Stopped error simulation")
end

-- Manual error injection functions
function DevReproModeService.InjectServerError(serviceName, message, playerUserId)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	ProductionFeedbackService.ReportServerError(serviceName or "ProductionService", message or "Manual server error", playerUserId or 0)
	log("info", "DEV_REPRO_MODE: Injected server error")
	return true, "Server error injected successfully"
end

function DevReproModeService.InjectRemoteMisuse(serviceName, message, playerUserId)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	ProductionFeedbackService.ReportRemoteMisuse(serviceName or "RemoteRouter", message or "Manual remote misuse", playerUserId or 123456789)
	log("info", "DEV_REPRO_MODE: Injected remote misuse")
	return true, "Remote misuse injected successfully"
end

function DevReproModeService.InjectDataStoreFailure(serviceName, message, playerUserId)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	ProductionFeedbackService.ReportDataStoreFailure(serviceName or "PlayerDataService", message or "Manual DataStore failure", playerUserId or 987654321)
	log("info", "DEV_REPRO_MODE: Injected DataStore failure")
	return true, "DataStore failure injected successfully"
end

function DevReproModeService.InjectAntiCheatEscalation(serviceName, message, playerUserId)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	ProductionFeedbackService.ReportAntiCheatEscalation(serviceName or "AntiCheatService", message or "Manual anti-cheat escalation", playerUserId or 555666777)
	log("info", "DEV_REPRO_MODE: Injected anti-cheat escalation")
	return true, "Anti-cheat escalation injected successfully"
end

function DevReproModeService.InjectEconomyRollback(serviceName, message, playerUserId)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	ProductionFeedbackService.ReportEconomyRollback(serviceName or "ProductionService", message or "Manual economy rollback", playerUserId or 111222333)
	log("info", "DEV_REPRO_MODE: Injected economy rollback")
	return true, "Economy rollback injected successfully"
end

function DevReproModeService.InjectServiceCrash(serviceName, message, playerUserId)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	ProductionFeedbackService.ReportServiceCrash(serviceName or "ProductionService", message or "Manual service crash", playerUserId or 0)
	log("info", "DEV_REPRO_MODE: Injected service crash")
	return true, "Service crash injected successfully"
end

-- Simulation control functions
function DevReproModeService.StartSimulation()
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	if isReproModeActive then
		return false, "Simulation already active"
	end
	
	startErrorSimulation()
	return true, "Error simulation started"
end

function DevReproModeService.StopSimulation()
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	if not isReproModeActive then
		return false, "No simulation active"
	end
	
	stopErrorSimulation()
	return true, "Error simulation stopped"
end

function DevReproModeService.ToggleSimulation()
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	if isReproModeActive then
		stopErrorSimulation()
		return true, "Error simulation stopped"
	else
		startErrorSimulation()
		return true, "Error simulation started"
	end
end

function DevReproModeService.GetSimulationStatus()
	return {
		enabled = CONFIG.ENABLED,
		active = isReproModeActive,
		taskCount = #table.keys(simulationTasks),
		simulationTypes = table.keys(CONFIG.ERROR_TYPES),
	}
end

-- Remote function handlers for Studio clients
function DevReproModeService.HandleStartSimulation(player, params)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	return DevReproModeService.StartSimulation()
end

function DevReproModeService.HandleStopSimulation(player, params)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	return DevReproModeService.StopSimulation()
end

function DevReproModeService.HandleInjectError(player, params)
	if not CONFIG.ENABLED then
		return false, "DEV_REPRO_MODE only available in Studio"
	end
	
	local errorType = params.errorType
	local serviceName = params.serviceName
	local message = params.message
	local playerUserId = params.playerUserId
	
	if not errorType or not table.find(table.keys(CONFIG.ERROR_TYPES), errorType) then
		return false, "Invalid error type"
	end
	
	local injectFunction = DevReproModeService["Inject" .. errorType]
	if not injectFunction then
		return false, "Error injection function not found"
	end
	
	return injectFunction(serviceName, message, playerUserId)
end

-- Initialize service
function DevReproModeService.OnStart()
	if CONFIG.ENABLED then
		log("info", "DevReproModeService initialized (Studio mode)")
		log("info", "DEV_REPRO_MODE ready for testing")
	else
		log("info", "DevReproModeService disabled (published game)")
	end
end

return DevReproModeService

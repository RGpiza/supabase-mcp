local InitManager = {}

-- Debug flag for development
local DEBUG = false

-- Internal state
local initialized = false
local phases = {}
local services = {}
local controllers = {}
local lazyFeatures = {}
local initOrder = {}

-- Service/Controller states
local STATES = {
	PENDING = "pending",
	INITIALIZING = "initializing",
	INITIALIZED = "initialized",
	ERROR = "error"
}

local function log(msg, ...)
	if DEBUG then
		print("[InitManager]", msg, ...)
	end
end

local function errorLog(msg, ...)
	warn("[InitManager]", msg, ...)
end

-- Phase management
function InitManager.definePhase(name, dependencies)
	if phases[name] then
		errorLog("Phase already defined:", name)
		return false
	end
	
	phases[name] = {
		name = name,
		dependencies = dependencies or {},
		state = STATES.PENDING,
		items = {}
	}
	
	log("Phase defined:", name)
	return true
end

-- Note: Default phases should be defined by the loader, not here
-- to avoid duplication issues

-- Service/Controller registration
function InitManager.registerService(name, initFunction, phase, dependencies)
	if services[name] or controllers[name] then
		errorLog("Service/Controller already registered:", name)
		return false
	end
	
	local item = {
		name = name,
		initFunction = initFunction,
		phase = phase or "core",
		dependencies = dependencies or {},
		state = STATES.PENDING,
		instance = nil,
		error = nil
	}
	
	if phase == "features" then
		lazyFeatures[name] = item
	else
		services[name] = item
		if not phases[phase] then
			InitManager.definePhase(phase, {})
		end
		table.insert(phases[phase].items, item)
	end
	
	log("Service registered:", name, "phase:", phase)
	return true
end

function InitManager.registerController(name, initFunction, phase, dependencies)
	return InitManager.registerService(name, initFunction, phase, dependencies)
end

-- Lazy feature management
function InitManager.registerLazyFeature(name, initFunction, dependencies)
	return InitManager.registerService(name, initFunction, "features", dependencies)
end

function InitManager.loadLazyFeature(name)
	if not lazyFeatures[name] then
		errorLog("Lazy feature not registered:", name)
		return false
	end
	
	local feature = lazyFeatures[name]
	if feature.state == STATES.INITIALIZED then
		log("Lazy feature already loaded:", name)
		return true
	end
	
	if feature.state == STATES.INITIALIZING then
		log("Lazy feature already initializing:", name)
		return false
	end
	
	return InitManager._initializeItem(feature)
end

-- Internal initialization logic
function InitManager._initializeItem(item)
	if item.state == STATES.INITIALIZED then
		return true
	end
	
	if item.state == STATES.INITIALIZING then
		return false
	end
	
	item.state = STATES.INITIALIZING
	log("Initializing:", item.name)
	
	local success, result = pcall(item.initFunction)
	if success then
		item.state = STATES.INITIALIZED
		item.instance = result
		log("Initialized:", item.name)
		return true
	else
		item.state = STATES.ERROR
		item.error = result
		errorLog("Failed to initialize:", item.name, result)
		return false
	end
end

function InitManager._initializePhase(phaseName)
	if not phases[phaseName] then
		errorLog("Phase not defined:", phaseName)
		return false
	end
	
	local phase = phases[phaseName]
	if phase.state == STATES.INITIALIZED then
		return true
	end
	
	if phase.state == STATES.INITIALIZING then
		return false
	end
	
	phase.state = STATES.INITIALIZING
	log("Starting phase:", phaseName)
	
	-- Initialize dependencies first
	for _, dep in ipairs(phase.dependencies) do
		if not InitManager._initializePhase(dep) then
			errorLog("Failed to initialize dependency phase:", dep)
			return false
		end
	end
	
	-- Initialize items in this phase
	for _, item in ipairs(phase.items) do
		if not InitManager._initializeItem(item) then
			errorLog("Failed to initialize item in phase:", phaseName, item.name)
			return false
		end
	end
	
	phase.state = STATES.INITIALIZED
	log("Completed phase:", phaseName)
	return true
end

-- Main initialization
function InitManager.initialize()
	if initialized then
		log("Already initialized")
		return true
	end
	
	initialized = true
	log("Starting initialization...")
	
	-- Initialize core phase
	if not InitManager._initializePhase("core") then
		errorLog("Failed to initialize core phase")
		return false
	end
	
	-- Initialize UI shell phase
	if not InitManager._initializePhase("ui_shell") then
		errorLog("Failed to initialize UI shell phase")
		return false
	end
	
	-- Features phase is lazy-loaded, so we don't initialize it here
	log("Initialization complete - features will be lazy-loaded")
	return true
end

-- Status queries
function InitManager.getStatus()
	return {
		initialized = initialized,
		phases = phases,
		services = services,
		controllers = controllers,
		lazyFeatures = lazyFeatures
	}
end

function InitManager.isInitialized(name)
	local item = services[name] or controllers[name] or lazyFeatures[name]
	return item and item.state == STATES.INITIALIZED
end

function InitManager.getPhaseStatus(phaseName)
	local phase = phases[phaseName]
	return phase and phase.state or STATES.PENDING
end

-- Utility functions
function InitManager.waitForInitialization(name, timeout)
	timeout = timeout or 10
	local item = services[name] or controllers[name]
	if not item then
		return false, "Item not registered"
	end
	
	local startTime = tick()
	while item.state ~= STATES.INITIALIZED do
		if tick() - startTime > timeout then
			return false, "Timeout waiting for initialization"
		end
		task.wait(0.1)
	end
	
	return true, item.instance
end

-- Auto-initialization on require - removed to allow loaders to control phases

return InitManager

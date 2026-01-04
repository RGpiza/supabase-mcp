local FeatureLoader = {}

-- Debug flag
local DEBUG = false

-- Internal state
local loadedFeatures = {}
local featureCallbacks = {}
local featureDependencies = {}

local function log(msg, ...)
	if DEBUG then
		print("[FeatureLoader]", msg, ...)
	end
end

local function errorLog(msg, ...)
	warn("[FeatureLoader]", msg, ...)
end

-- Register a feature for lazy loading
function FeatureLoader.registerFeature(name, loadFunction, dependencies)
	if loadedFeatures[name] then
		errorLog("Feature already registered:", name)
		return false
	end
	
	loadedFeatures[name] = {
		name = name,
		loadFunction = loadFunction,
		dependencies = dependencies or {},
		state = "pending",
		instance = nil,
		error = nil
	}
	
	log("Feature registered:", name)
	return true
end

-- Load a feature and its dependencies
function FeatureLoader.loadFeature(name)
	if not loadedFeatures[name] then
		errorLog("Feature not registered:", name)
		return false, "Feature not registered"
	end
	
	local feature = loadedFeatures[name]
	
	-- Check if already loaded
	if feature.state == "loaded" then
		log("Feature already loaded:", name)
		return true, feature.instance
	end
	
	-- Check if currently loading
	if feature.state == "loading" then
		log("Feature already loading:", name)
		return false, "Feature already loading"
	end
	
	-- Load dependencies first
	for _, depName in ipairs(feature.dependencies) do
		local success, result = FeatureLoader.loadFeature(depName)
		if not success then
			errorLog("Failed to load dependency:", depName, result)
			return false, "Dependency failed: " .. depName
		end
	end
	
	-- Load the feature
	feature.state = "loading"
	log("Loading feature:", name)
	
	local success, result = pcall(feature.loadFunction)
	if success then
		feature.state = "loaded"
		feature.instance = result
		log("Feature loaded:", name)
		
		-- Notify callbacks
		if featureCallbacks[name] then
			for _, callback in ipairs(featureCallbacks[name]) do
				pcall(callback, result)
			end
		end
		
		return true, result
	else
		feature.state = "error"
		feature.error = result
		errorLog("Failed to load feature:", name, result)
		return false, result
	end
end

-- Check if a feature is loaded
function FeatureLoader.isLoaded(name)
	local feature = loadedFeatures[name]
	return feature and feature.state == "loaded"
end

-- Get a loaded feature
function FeatureLoader.getFeature(name)
	local feature = loadedFeatures[name]
	if feature and feature.state == "loaded" then
		return feature.instance
	end
	return nil
end

-- Register callback for when a feature loads
function FeatureLoader.onFeatureLoaded(name, callback)
	if not loadedFeatures[name] then
		errorLog("Feature not registered:", name)
		return false
	end
	
	if not featureCallbacks[name] then
		featureCallbacks[name] = {}
	end
	
	table.insert(featureCallbacks[name], callback)
	
	-- If already loaded, call immediately
	if loadedFeatures[name].state == "loaded" then
		pcall(callback, loadedFeatures[name].instance)
	end
	
	return true
end

-- Feature-specific loaders
function FeatureLoader.loadPrestigeTree()
	log("Loading Prestige Tree feature...")
	
	-- This would load the PrestigeUpgradesController and related systems
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PrestigeUpgradesController = require(ReplicatedStorage.client.controllers.PrestigeUpgradesController)
	
	-- Initialize the controller
	local controller = PrestigeUpgradesController.Init({
		-- Pass required context
	})
	
	log("Prestige Tree loaded")
	return controller
end

function FeatureLoader.loadLeaderboards()
	log("Loading Leaderboards feature...")
	
	-- This would load the LeaderboardService and UI components
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LeaderboardService = require(ReplicatedStorage.server.services.LeaderboardService)
	
	-- Initialize the service
	local service = LeaderboardService
	
	-- Cache leaderboard data and set up throttled refresh
	local cachedData = {}
	local lastRefresh = 0
	local REFRESH_INTERVAL = 30 -- seconds
	
	local function refreshLeaderboards()
		local now = tick()
		if now - lastRefresh < REFRESH_INTERVAL then
			return cachedData
		end
		
		-- Refresh data (this would be the actual leaderboard refresh logic)
		cachedData = service:GetLeaderboardData()
		lastRefresh = now
		return cachedData
	end
	
	log("Leaderboards loaded")
	return {
		service = service,
		refresh = refreshLeaderboards,
		getData = function() return cachedData end
	}
end

function FeatureLoader.loadStore()
	log("Loading Store feature...")
	
	-- This would load the StoreUIController and MonetizationService
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StoreUIController = require(ReplicatedStorage.client.controllers.StoreUIController)
	local MonetizationService = require(ReplicatedStorage.server.services.MonetizationService)
	
	-- Initialize the controller
	local controller = StoreUIController.Init({
		-- Pass required context
	})
	
	log("Store loaded")
	return {
		controller = controller,
		service = MonetizationService
	}
end

-- Auto-register common features
if game:GetService("RunService"):IsServer() then
	-- Server features
	FeatureLoader.registerFeature("Leaderboards", FeatureLoader.loadLeaderboards, {})
	FeatureLoader.registerFeature("Monetization", function()
		local MonetizationService = require(game:GetService("ServerScriptService").services.MonetizationService)
		return MonetizationService
	end, {})
else
	-- Client features
	FeatureLoader.registerFeature("PrestigeTree", FeatureLoader.loadPrestigeTree, {})
	FeatureLoader.registerFeature("Store", FeatureLoader.loadStore, {})
end

return FeatureLoader

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local AnalyticsService = game:GetService("AnalyticsService")

local DataGrantService = require(script.Parent.DataGrantService)
local BoostManager = require(script.Parent.BoostManager)
local AutomationConstants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AutomationConstants"))

local STORE_DATASTORE_NAME = "StoreService_PlayerData_V1"
local MAX_RETRIES = 5
local RETRY_DELAY = 2

local defaultStoreData = {
	Currency = 0,
	ActiveBoosts = {},
	OwnedPasses = {},
	ProcessedReceipts = {},
}

-- Replace placeholder IDs with the experiences actual product and gamepass ids.
local DEV_PRODUCTS = {
	[111111] = {
		name = "Currency Pack",
		currencyAmount = 5000,
		currencyCode = "DATA",
	},
	[111112] = {
		name = "5 Min Boost",
		boostName = "+5 Min Boost",
		boostDuration = 5 * 60,
	},
	[111113] = {
		name = "1 Hour Boost",
		boostName = "+1 Hour Boost",
		boostDuration = 60 * 60,
	},
}

local GAMEPASSES = {
	[222221] = {
		name = "x2 Data",
		attribute = "HasX2DataPass",
	},
	[222222] = {
		name = "Faster Auto",
		attribute = "HasFasterAutoPass",
	},
	[AutomationConstants.GamepassIdPreset4] = {
		name = "Preset Slot 4",
		attribute = AutomationConstants.Preset4Attribute,
	},
}

local playerStoreCache: { [string]: typeof(defaultStoreData) } = {}
local storeDataStore = DataStoreService:GetDataStore(STORE_DATASTORE_NAME)

local function deepCopy<T>(source: { [any]: T }): { [any]: T }
	local target = {}
	for key, value in source do
		if typeof(value) == "table" then
			target[key] = deepCopy(value)
		else
			target[key] = value
		end
	end
	return target
end

local function sanitizeBoosts(boosts: any): { [string]: number }
	local sanitized: { [string]: number } = {}
	if typeof(boosts) ~= "table" then
		return sanitized
	end

	local now = os.time()
	for boostName, expiration in boosts do
		if typeof(boostName) == "string" and typeof(expiration) == "number" and expiration > now then
			sanitized[boostName] = expiration
		end
	end

	return sanitized
end

local function sanitizePasses(passes: any): { [string]: boolean }
	local sanitized: { [string]: boolean } = {}
	if typeof(passes) ~= "table" then
		return sanitized
	end

	for passId, owned in pairs(passes) do
		if typeof(passId) == "string" and typeof(owned) == "boolean" then
			sanitized[passId] = owned
		elseif typeof(passId) == "number" and typeof(owned) == "boolean" then
			sanitized[tostring(passId)] = owned
		end
	end

	return sanitized
end

local function sanitizeProcessed(receipts: any): { [string]: boolean }
	local sanitized: { [string]: boolean } = {}
	if typeof(receipts) ~= "table" then
		return sanitized
	end

	for receiptId, processed in pairs(receipts) do
		if typeof(receiptId) == "string" and processed == true then
			sanitized[receiptId] = true
		end
	end

	return sanitized
end

local function sanitizeStoreData(payload: any)
	local sanitized = deepCopy(defaultStoreData)

	if typeof(payload) ~= "table" then
		return sanitized
	end

	if typeof(payload.Currency) == "number" then
		sanitized.Currency = math.max(0, payload.Currency)
	end

	sanitized.ActiveBoosts = sanitizeBoosts(payload.ActiveBoosts)
	sanitized.OwnedPasses = sanitizePasses(payload.OwnedPasses)
	sanitized.ProcessedReceipts = sanitizeProcessed(payload.ProcessedReceipts)

	return sanitized
end

local function getPlayerKey(player: Player): string
	return tostring(player.UserId)
end

local function loadStoreData(userId: string)
	local attempts = 0
	repeat
		attempts += 1
		local success, result = pcall(function()
			return storeDataStore:GetAsync(userId)
		end)

		if success then
			return sanitizeStoreData(result)
		end

		warn("[StoreService] GetAsync failed for", userId, "attempt", attempts)
		if attempts < MAX_RETRIES then
			task.wait(RETRY_DELAY)
		end
	until attempts >= MAX_RETRIES

	return deepCopy(defaultStoreData)
end

local function saveStoreData(userId: string, payload)
	local attempts = 0
	repeat
		attempts += 1
		local success, err = pcall(function()
			storeDataStore:SetAsync(userId, payload)
		end)

		if success then
			return true
		end

		warn("[StoreService] SetAsync failed for", userId, err)
		if attempts < MAX_RETRIES then
			task.wait(RETRY_DELAY)
		end
	until attempts >= MAX_RETRIES

	return false
end

local function getPlayerStoreData(player: Player)
	local userId = getPlayerKey(player)
	if playerStoreCache[userId] then
		return playerStoreCache[userId]
	end

	local data = loadStoreData(userId)
	playerStoreCache[userId] = data
	return data
end

local function savePlayerStoreData(player: Player)
	local userId = getPlayerKey(player)
	local cached = playerStoreCache[userId]
	if not cached then
		return false
	end

	return saveStoreData(userId, cached)
end

local function releasePlayerStoreData(player: Player)
	playerStoreCache[getPlayerKey(player)] = nil
end

local function logIapGrant(player: Player, currencyCode: string, amount: number, source: string)
	if amount <= 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:FireInGameEconomyEvent(player, Enum.AnalyticsEconomyTransactionType.IAP, currencyCode, amount, source or "Store", nil)
		end)

		if not ok then
			warn("[StoreService] Failed to log economy event:", err)
		end
	end)
end

local function logStorePurchase(player: Player, productType: string, productId: number, itemName: string?)
	local platform = player:GetAttribute("StorePlatform") or "Unknown"
	local data = {
		ItemName = itemName or "",
		ProductType = productType or "",
		ProductId = productId or 0,
		Platform = platform,
		UserId = player.UserId,
	}

	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, "StorePurchaseCompleted", 1, data)
	end)

	if not ok then
		warn("[StoreService] Failed to log purchase analytics:", err)
	end
end

local function addCurrency(player: Player, dataTable, amount: number, source: string?)
	if amount <= 0 then
		return
	end

	local granted = DataGrantService.GrantData(player, amount, source or "DevProduct")
	if granted <= 0 then
		warn("[StoreService] Failed to grant currency for", player, source or "DevProduct", amount)
		return
	end

	dataTable.Currency = math.max(0, (dataTable.Currency or 0) + granted)
	logIapGrant(player, "DATA", granted, source or "DevProduct")
end

local function addBoost(player: Player, dataTable, boostName: string, duration: number)
	if duration <= 0 then
		return
	end

	local now = os.time()
	local existing = dataTable.ActiveBoosts[boostName]
	local startTime = math.max(now, typeof(existing) == "number" and existing or now)
	local expiration = startTime + duration
	dataTable.ActiveBoosts[boostName] = expiration
	player:SetAttribute(boostName .. "Expires", expiration)

	BoostManager.AddBoostDuration(player, boostName, duration)
end

local function markPassOwned(player: Player, dataTable, passId: number, config)
	local key = tostring(passId)
	if dataTable.OwnedPasses[key] then
		if config and config.attribute then
			player:SetAttribute(config.attribute, true)
		end
		return
	end

	dataTable.OwnedPasses[key] = true
	if config and config.attribute then
		player:SetAttribute(config.attribute, true)
	end
end

local function ensureStoredBoostAttributes(player: Player, dataTable)
	local now = os.time()
	for boostName, expiration in pairs(dataTable.ActiveBoosts) do
		if typeof(expiration) ~= "number" or expiration <= now then
			dataTable.ActiveBoosts[boostName] = nil
			player:SetAttribute(boostName .. "Expires", nil)
		else
			player:SetAttribute(boostName .. "Expires", expiration)
		end
	end
end

local function ensureStoredPassAttributes(player: Player, dataTable)
	for _, config in pairs(GAMEPASSES) do
		if config.attribute then
			player:SetAttribute(config.attribute, false)
		end
	end

	for passId, owned in pairs(dataTable.OwnedPasses) do
		if owned then
			local numericId = tonumber(passId)
			if numericId then
				local config = GAMEPASSES[numericId]
				if config and config.attribute then
					player:SetAttribute(config.attribute, true)
				end
			end
		end
	end
end

local function grantDevProduct(player: Player, productId: number, receiptId: string)
	local config = DEV_PRODUCTS[productId]
	if not config then
		warn("[StoreService] Unknown developer product:", productId)
		return true
	end

	local dataTable = getPlayerStoreData(player)

	if dataTable.ProcessedReceipts[receiptId] then
		return true
	end

	if config.currencyAmount then
		addCurrency(player, dataTable, config.currencyAmount, config.name)
	end

	if config.boostName and config.boostDuration then
		addBoost(player, dataTable, config.boostName, config.boostDuration)
	end

	dataTable.ProcessedReceipts[receiptId] = true

	local saved = savePlayerStoreData(player)
	if not saved then
		warn("[StoreService] Failed to persist data for receipt", receiptId)
	else
		logStorePurchase(player, "DevProduct", productId, config.name)
	end

	return saved
end

local function checkGamepassOwnership(player: Player, passId: number, config)
	local dataTable = getPlayerStoreData(player)
	local key = tostring(passId)
	if dataTable.OwnedPasses[key] then
		if config and config.attribute then
			player:SetAttribute(config.attribute, true)
		end
		return
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)

	if not success then
		warn("[StoreService] Gamepass ownership check failed:", passId)
		return
	end

	if owns then
		markPassOwned(player, dataTable, passId, config)
		savePlayerStoreData(player)
	end
end

local function onPlayerAdded(player: Player)
	local dataTable = getPlayerStoreData(player)
	ensureStoredBoostAttributes(player, dataTable)
	ensureStoredPassAttributes(player, dataTable)

	for passId, config in pairs(GAMEPASSES) do
		checkGamepassOwnership(player, passId, config)
	end
end

local function onPlayerRemoving(player: Player)
	savePlayerStoreData(player)
	releasePlayerStoreData(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if not wasPurchased then
		return
	end

	local config = GAMEPASSES[passId]
	if not config then
		return
	end

	local dataTable = getPlayerStoreData(player)
	markPassOwned(player, dataTable, passId, config)
	if savePlayerStoreData(player) then
		logStorePurchase(player, "Gamepass", passId, config.name)
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptId = tostring(receiptInfo.PurchaseId)
	local dataTable = getPlayerStoreData(player)
	if dataTable.ProcessedReceipts[receiptId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local granted = grantDevProduct(player, receiptInfo.ProductId, receiptId)
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerRemoving(player)
	end
end)

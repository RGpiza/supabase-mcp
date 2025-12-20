local GamePassService = game:GetService("GamePassService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local MonetizationService = {}

MonetizationService.PASS_IDS = {
	FasterAuto = 1635120464,
	TwoXData = 1635206515,
}

MonetizationService.PRODUCT_IDS = {
	Boost1h = 3481392653,
	Boost5m = 3481392368,
}

local passCache = {}

local function getPlayerKey(player)
	return player and tostring(player.UserId) or nil
end

local function ownsPass(player, passId)
	if not player then
		return false
	end
	local key = getPlayerKey(player)
	passCache[key] = passCache[key] or {}
	if passCache[key][passId] ~= nil then
		return passCache[key][passId]
	end
	local ok, owns = pcall(function()
		return GamePassService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	passCache[key][passId] = ok and owns or false
	return passCache[key][passId]
end

function MonetizationService.Has2xData(player)
	return ownsPass(player, MonetizationService.PASS_IDS.TwoXData)
end

function MonetizationService.HasFasterAuto(player)
	return ownsPass(player, MonetizationService.PASS_IDS.FasterAuto)
end

function MonetizationService.ApplyPasses(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	local owns2x = MonetizationService.Has2xData(player)
	local ownsFast = MonetizationService.HasFasterAuto(player)
	data.owns2xData = owns2x
	data.ownsFasterAuto = ownsFast
	data.passes = typeof(data.passes) == "table" and data.passes or {}
	data.passes.x2Data = owns2x
	data.passes.fasterAuto = ownsFast
	PlayerDataService.Set(player, data)
	return data
end

function MonetizationService.GrantBoostSeconds(player, seconds)
	if not player or typeof(seconds) ~= "number" then
		return false
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false
	end
	local now = os.time()
	local expires = typeof(data.boostExpiresAt) == "number" and data.boostExpiresAt or 0
	if expires < now then
		expires = now
	end
	local newExpires = expires + seconds
	data.boostExpiresAt = newExpires
	data.boostEnd = newExpires
	PlayerDataService.Set(player, data)
	return true
end

function MonetizationService.IsBoostActive(playerData)
	if typeof(playerData) ~= "table" then
		return false
	end
	local expires = typeof(playerData.boostEnd) == "number" and playerData.boostEnd or 0
	if expires <= 0 and typeof(playerData.boostExpiresAt) == "number" then
		expires = playerData.boostExpiresAt
	end
	return os.time() < expires
end

local function hasReceipt(playerData, receiptId)
	local list = playerData.receiptIds
	if typeof(list) ~= "table" then
		return false
	end
	for _, id in ipairs(list) do
		if id == receiptId then
			return true
		end
	end
	return false
end

local function addReceipt(playerData, receiptId)
	playerData.receiptIds = typeof(playerData.receiptIds) == "table" and playerData.receiptIds or {}
	table.insert(playerData.receiptIds, receiptId)
	if #playerData.receiptIds > 50 then
		local overflow = #playerData.receiptIds - 50
		for _ = 1, overflow do
			table.remove(playerData.receiptIds, 1)
		end
	end
end

function MonetizationService.ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if hasReceipt(data, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId
	if productId == MonetizationService.PRODUCT_IDS.Boost1h then
		MonetizationService.GrantBoostSeconds(player, 3600)
	elseif productId == MonetizationService.PRODUCT_IDS.Boost5m then
		MonetizationService.GrantBoostSeconds(player, 300)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	addReceipt(data, receiptInfo.PurchaseId)
	PlayerDataService.Set(player, data)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt

return MonetizationService

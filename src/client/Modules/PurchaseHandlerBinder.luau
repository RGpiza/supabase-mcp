local PurchaseHandlerBinder = {}

local ctx = nil
local bindings = {} -- map button -> state table
local connections = {} -- map button -> list of connections

local function safeDisconnectList(list)
	if not list then return end
	for _, con in ipairs(list) do
		if con and type(con.Disconnect) == "function" then
			con:Disconnect()
		end
	end
end

function PurchaseHandlerBinder.Init(context)
	ctx = context or {}
	bindings = {}
	connections = {}

	-- Resolve remotes defensively
	local remotes = ctx._remotes or ctx.remotes
	if not remotes then
		local ok, rs = pcall(function()
			return game:GetService("ReplicatedStorage")
		end)
		remotes = ok and rs and rs:FindFirstChild("Remotes") or nil
	end
	ctx._resolvedRemotes = ctx._resolvedRemotes or {}
	local required = { "PurchaseUpgrade", "BuyMax", "AutoBuy" }
	local optional = { "SomeOptionalRemote" } -- Define optional remotes here
	local missingAny = false
	for _, name in ipairs(required) do
		local found = remotes and remotes:FindFirstChild(name)
		if found then
			ctx._resolvedRemotes[name] = found
		else
			missingAny = true
		end
	end
	if missingAny then
		warn("[PurchaseHandlerBinder] Some required remotes are missing; binder will operate defensively")
	end

	-- Only warn about missing optional remotes, do not stop initialization
	for _, name in ipairs(optional) do
		local found = remotes and remotes:FindFirstChild(name)
		if not found then
			warn("[PurchaseHandlerBinder] Optional remote " .. name .. " is missing")
		end
	end
end

function PurchaseHandlerBinder.Attach(storeUI, remotes)
	-- storeUI and remotes can be stored for future use; not required for per-button binds
	ctx._storeUI = storeUI
	ctx._remotes = remotes
end

local function handleBuy(upgradeId)
	if not ctx or not ctx.purchaseUpgradeEvent then
		return
	end
	local now = os.clock()
	local cd = ctx.purchaseCooldowns or {}
	local last = cd[upgradeId]
	if last and now - last < (ctx.PURCHASE_SETTINGS and ctx.PURCHASE_SETTINGS.debounce or 0.2) then
		return
	end
	cd[upgradeId] = now
	ctx.purchaseCooldowns = cd

	if ctx.triggerHaptic then
		pcall(ctx.triggerHaptic, "medium")
	end

	pcall(function()
		ctx.purchaseUpgradeEvent:FireServer({ upgradeId = upgradeId, mode = "single" })
	end)

	if ctx.syncState then
		task.defer(function()
			pcall(ctx.syncState)
		end)
	end
end

function PurchaseHandlerBinder.Bind(button, upgradeId)
	if not button or not upgradeId then return end
	if not button:IsA("GuiButton") then return end
	if bindings[button] then return end

	local state = {
		activeTouch = nil,
		touchLongPressTriggered = false,
		lastHandledTime = 0,
	}
	bindings[button] = state

	local function markHandled()
		state.lastHandledTime = os.clock()
	end

	local function firePurchase(mode, suppressActivation)
		-- mode currently supported: "single" | "max"
		if mode == "max" then
			-- send max mode
			if ctx and ctx.purchaseUpgradeEvent then
				pcall(function()
					ctx.purchaseUpgradeEvent:FireServer({ upgradeId = upgradeId, mode = "max" })
				end)
			end
			if ctx and ctx.triggerHaptic then pcall(ctx.triggerHaptic, "medium") end
			if ctx and ctx.syncState then task.defer(function() pcall(ctx.syncState) end) end
		else
			handleBuy(upgradeId)
		end
		if suppressActivation then
			markHandled()
		end
	end

	local conList = {}

	local con1 = button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			firePurchase("max", true)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local isShift = false
			if input and typeof(input.IsModifierKeyDown) == "function" then
				isShift = input:IsModifierKeyDown(Enum.KeyCode.LeftShift) or input:IsModifierKeyDown(Enum.KeyCode.RightShift)
			else
				local uis = game:GetService("UserInputService")
				isShift = uis:IsKeyDown(Enum.KeyCode.LeftShift) or uis:IsKeyDown(Enum.KeyCode.RightShift)
			end
			if isShift then
				firePurchase("max", true)
			else
				firePurchase("single", true)
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			state.activeTouch = input
			state.touchLongPressTriggered = false
			local captured = input
			task.delay((ctx.PURCHASE_SETTINGS and ctx.PURCHASE_SETTINGS.longPressDuration) or 0.5, function()
				if state.activeTouch == captured and not state.touchLongPressTriggered then
					state.touchLongPressTriggered = true
					firePurchase("max", true)
				end
			end)
		end
	end)
	table.insert(conList, con1)

	local con2 = button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and state.activeTouch == input then
			state.activeTouch = nil
			if not state.touchLongPressTriggered then
				firePurchase("single", true)
			end
		end
	end)
	table.insert(conList, con2)

	local con3 = button.Activated:Connect(function()
		if os.clock() - state.lastHandledTime < ((ctx.PURCHASE_SETTINGS and ctx.PURCHASE_SETTINGS.activationSuppress) or 0.1) then
			return
		end
		firePurchase("single", false)
	end)
	table.insert(conList, con3)

	connections[button] = conList
end

function PurchaseHandlerBinder.Detach()
	for btn, conList in pairs(connections) do
		safeDisconnectList(conList)
	end
	bindings = {}
	connections = {}
	ctx = nil
end

function PurchaseHandlerBinder.Cleanup()
	PurchaseHandlerBinder.Detach()
end

return PurchaseHandlerBinder

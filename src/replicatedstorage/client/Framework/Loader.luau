local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(script.Parent:FindFirstChild("Signal"))

local Loader = {}
local started = false

local function resolveRequestSync()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("RequestSync")
end

local function setupPayloadSource(signals)
	local connected = false
	local invoked = false

	local function hook(remote)
		if connected or not remote then
			return
		end
		if remote:IsA("RemoteEvent") then
			connected = true
			remote.OnClientEvent:Connect(function(payload)
				signals.PayloadReceived:Fire(payload)
			end)
		elseif remote:IsA("RemoteFunction") then
			connected = true
			signals.UIReady:Connect(function()
				if invoked then
					return
				end
				invoked = true
				local ok, payload = pcall(function()
					return remote:InvokeServer()
				end)
				if ok then
					signals.PayloadReceived:Fire(payload)
				end
			end)
		end
	end

	hook(resolveRequestSync())

	ReplicatedStorage.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "RequestSync" then
			hook(descendant)
		end
	end)
end

function Loader.Start()
	if started then
		return
	end
	started = true

	local clientRoot = ReplicatedStorage:FindFirstChild("Client")
	if not clientRoot then
		return
	end
	clientRoot:SetAttribute("FrameworkEnabled", true)

	local signals = {
		UIReady = Signal.new(),
		PayloadReceived = Signal.new(),
		UpgradesRendered = Signal.new(),
	}

	local controllers = {
		require(clientRoot.Controllers:FindFirstChild("UIController")),
		require(clientRoot.Controllers:FindFirstChild("UpgradeController")),
		require(clientRoot.Controllers:FindFirstChild("WeeklyController")),
		require(clientRoot.Controllers:FindFirstChild("AutoBuyController")),
	}

	local context = {
		Signals = signals,
		ReplicatedStorage = ReplicatedStorage,
	}

	for _, controller in ipairs(controllers) do
		if type(controller.Init) == "function" then
			controller.Init(context)
		end
	end

	for _, controller in ipairs(controllers) do
		if type(controller.Start) == "function" then
			controller.Start()
		end
	end

	setupPayloadSource(signals)
end

return Loader

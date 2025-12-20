local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RequestSyncController = {}

local connected = false
local dataFlowConnected = false
local dataFlowValue = 0
local dataFlowLabel = nil

local function resolveDataLabel(ui)
	if not ui then
		return nil
	end
	local root = ui:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local topBar = safeArea and safeArea:FindFirstChild("TopBar")
	local dataValue = topBar and topBar:FindFirstChild("DataValue")
	if dataValue and dataValue:IsA("TextLabel") then
		return dataValue
	end
	return nil
end

function RequestSyncController.Init(terminalUi)
	if connected then
		return true
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local requestSync = remotes and remotes:FindFirstChild("RequestSync")
	if not requestSync then
		warn("[RequestSyncController] RequestSync missing")
		return false
	end

	local upgradeRendererModule = script.Parent:FindFirstChild("UpgradeRenderer")
	local upgradeRenderer = upgradeRendererModule and require(upgradeRendererModule)
	if not (upgradeRenderer and type(upgradeRenderer.Render) == "function") then
		warn("[RequestSyncController] UpgradeRenderer missing")
		return false
	end
	local requestSyncClientModule = script.Parent:FindFirstChild("RequestSyncClient")
	local requestSyncClient = requestSyncClientModule and require(requestSyncClientModule)

	local function handlePayload(payload)
		if requestSyncClient and type(requestSyncClient.ProcessPayload) == "function" then
			requestSyncClient.ProcessPayload(payload)
		else
			upgradeRenderer.Render(payload)
		end
		if not dataFlowConnected then
			dataFlowLabel = resolveDataLabel(terminalUi)
			if dataFlowLabel then
				dataFlowLabel.Text = "DEBUG: DATA FLOWING"
				dataFlowConnected = true
				local accumulator = 0
				RunService.Heartbeat:Connect(function(dt)
					accumulator += dt
					if accumulator >= 1 then
						accumulator -= 1
						dataFlowValue += 1
						dataFlowLabel.Text = ("DEBUG: DATA FLOWING %d"):format(dataFlowValue)
					end
				end)
			else
				warn("[RequestSyncController] DataValue label missing; cannot prove data flow")
			end
		end
	end

	if requestSync:IsA("RemoteEvent") then
		requestSync.OnClientEvent:Connect(handlePayload)
	elseif requestSync:IsA("RemoteFunction") then
		requestSync.OnClientInvoke = function(payload)
			handlePayload(payload)
		end
	else
		warn("[RequestSyncController] RequestSync is not a RemoteEvent or RemoteFunction")
		return false
	end

	connected = true
	return true
end

return RequestSyncController

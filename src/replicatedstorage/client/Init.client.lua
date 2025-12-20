local ReplicatedStorage = game:GetService("ReplicatedStorage")

local started = false

local function tryStart()
	if started then
		return
	end
	local clientRoot = ReplicatedStorage:FindFirstChild("Client")
	local framework = clientRoot and clientRoot:FindFirstChild("Framework")
	local loaderModule = framework and framework:FindFirstChild("Loader")
	if not loaderModule then
		return
	end
	started = true
	local loader = require(loaderModule)
	loader.Start()
end

ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "Client" then
		tryStart()
	end
end)

tryStart()

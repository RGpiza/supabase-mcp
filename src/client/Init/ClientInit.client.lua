local initModule = nil
if script.Parent then
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child.Name == "ClientInit" and child:IsA("ModuleScript") then
			initModule = child
			break
		end
	end
end

if not initModule then
	error("[ClientInit] ClientInit module missing")
end

require(initModule)

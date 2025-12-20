local StarterGui = game:GetService("StarterGui")

local UIPaths = {}

local terminalUiRef = nil
local templateRef = nil

local function assertUi()
	if not terminalUiRef then
		error("[UIPaths] Init() was not called before GetTerminalUI()")
	end
	if not terminalUiRef:IsA("ScreenGui") then
		error("[UIPaths] TerminalUI reference is not a ScreenGui")
	end
	return terminalUiRef
end

function UIPaths.Init(terminalUi)
	if terminalUiRef then
		error("[UIPaths] Init() already called")
	end
	if not (terminalUi and terminalUi:IsA("ScreenGui")) then
		error("[UIPaths] Init() requires TerminalUI ScreenGui")
	end
	terminalUiRef = terminalUi
	print("[UIPaths] TerminalUI:", terminalUiRef:GetFullName())
	templateRef = StarterGui:FindFirstChild("UpgradeCardTemplate")
	return true
end

UIPaths.init = UIPaths.Init

function UIPaths.get()
	return assertUi()
end

UIPaths.Init = UIPaths.init
UIPaths.GetTerminalUI = function(_playerGui)
	return UIPaths.get()
end

local function resolveColumns(terminalUi)
	local root = terminalUi and terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	return columns
end

function UIPaths.GetCardsCPU(terminalUi)
	terminalUi = terminalUi or assertUi()
	local columns = resolveColumns(terminalUi)
	local cpu = columns and columns:FindFirstChild("CPUColumn")
	local cards = cpu and cpu:FindFirstChild("Cards_CPU")
	if not cards then
		error("[UIPaths] Missing Cards_CPU")
	end
	print("[UIPaths] Cards_CPU:", cards:GetFullName())
	return cards
end

function UIPaths.GetCardsRAM(terminalUi)
	terminalUi = terminalUi or assertUi()
	local columns = resolveColumns(terminalUi)
	local ram = columns and columns:FindFirstChild("RAMColumn")
	local cards = ram and ram:FindFirstChild("Cards_RAM")
	if not cards then
		error("[UIPaths] Missing Cards_RAM")
	end
	print("[UIPaths] Cards_RAM:", cards:GetFullName())
	return cards
end

function UIPaths.GetCardsSTO(terminalUi)
	terminalUi = terminalUi or assertUi()
	local columns = resolveColumns(terminalUi)
	local sto = columns and columns:FindFirstChild("STOColumn")
	local cards = sto and sto:FindFirstChild("Cards_STORAGE")
	if not cards then
		error("[UIPaths] Missing Cards_STORAGE")
	end
	print("[UIPaths] Cards_STORAGE:", cards:GetFullName())
	return cards
end

function UIPaths.GetAutoBuyButtons(terminalUi)
	terminalUi = terminalUi or assertUi()
	local columns = resolveColumns(terminalUi)
	local cpu = columns and columns:FindFirstChild("CPUColumn")
	local ram = columns and columns:FindFirstChild("RAMColumn")
	local sto = columns and columns:FindFirstChild("STOColumn")
	local buttons = {
		CPU = cpu and cpu:FindFirstChild("AutoBuyButton"),
		RAM = ram and ram:FindFirstChild("AutoBuyButton"),
		STO = sto and sto:FindFirstChild("AutoBuyButton"),
	}
	if not (buttons.CPU and buttons.RAM and buttons.STO) then
		error("[UIPaths] Missing AutoBuyButton(s)")
	end
	return buttons
end

function UIPaths.GetWeeklyPage(terminalUi)
	terminalUi = terminalUi or assertUi()
	local root = terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	local pages = rightPanel and rightPanel:FindFirstChild("Pages")
	local page = pages and pages:FindFirstChild("WeeklyLeaderboardPage")
	if not page then
		error("[UIPaths] Missing WeeklyLeaderboardPage")
	end
	return page
end

function UIPaths.GetLeaderboardPage(terminalUi)
	terminalUi = terminalUi or assertUi()
	local root = terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	local pages = rightPanel and rightPanel:FindFirstChild("Pages")
	local page = pages and pages:FindFirstChild("LeaderboardPage")
	if not page then
		error("[UIPaths] Missing LeaderboardPage")
	end
	return page
end

function UIPaths.IsReady(terminalUi)
	terminalUi = terminalUi or terminalUiRef
	if not (terminalUi and terminalUi:IsA("ScreenGui")) then
		return false
	end
	local ok = pcall(function()
		UIPaths.GetCardsCPU(terminalUi)
		UIPaths.GetCardsRAM(terminalUi)
		UIPaths.GetCardsSTO(terminalUi)
	end)
	return ok
end

function UIPaths.GetTemplate()
	return templateRef
end

return UIPaths

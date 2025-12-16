local TerminalUIBinder = {}
local initialized = false

function TerminalUIBinder.Init(context)
	if initialized then
		return context.ui ~= nil
	end

	local playerGui = context.playerGui
	if not playerGui then
		warn("[TerminalClient] PlayerGui missing")
		return false
	end

	local screenGui = playerGui:WaitForChild("TerminalUI", 5)
	if not screenGui then
		warn("[TerminalClient] TerminalUI failed to load")
		return false
	end

	local safeFind = context.safeFind

	local root = safeFind(screenGui, "Root")
	local safeArea = root and safeFind(root, "SafeArea")
	local topBar = safeArea and safeFind(safeArea, "TopBar")
	local main = safeArea and safeFind(safeArea, "Main")
	local columns = main and safeFind(main, "Columns")
	local cpuColumn = columns and safeFind(columns, "CPUColumn")
	local ramColumn = columns and safeFind(columns, "RAMColumn")
	local stoColumn = columns and safeFind(columns, "STOColumn")
	local cpuCards = cpuColumn and safeFind(cpuColumn, "Cards_CPU")
	local ramCards = ramColumn and safeFind(ramColumn, "Cards_RAM")
	local stoCards = stoColumn and safeFind(stoColumn, "Cards_STORAGE")
	local rightPanel = main and safeFind(main, "RightPanel")
	local statsBox = rightPanel and safeFind(rightPanel, "StatsBox")
	local prestigeBox = rightPanel and safeFind(rightPanel, "PrestigeBox")
	local toastArea = safeArea and safeFind(safeArea, "ToastArea")

	if not (root and safeArea and topBar and main and columns and cpuCards and ramCards and stoCards and statsBox and prestigeBox and toastArea) then
		warn("[TerminalClient] UI hierarchy incomplete")
		return false
	end

	context.ui = {
		screenGui = screenGui,
		root = root,
		safeArea = safeArea,
		topBar = topBar,
		main = main,
		columns = columns,
		cpuColumn = cpuColumn,
		ramColumn = ramColumn,
		stoColumn = stoColumn,
		cpuCards = cpuCards,
		ramCards = ramCards,
		stoCards = stoCards,
		rightPanel = rightPanel,
		statsBox = statsBox,
		prestigeBox = prestigeBox,
		toastArea = toastArea,
	}

	initialized = true
	return true
end

return TerminalUIBinder

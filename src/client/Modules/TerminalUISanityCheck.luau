local StarterGui = game:GetService("StarterGui")

local TerminalUISanityCheck = {}

local function assertChild(parent, name)
	if not parent then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function fail(message)
	error("[TerminalUISanityCheck] " .. message)
end

function TerminalUISanityCheck.Assert()
	local terminalUi = StarterGui:FindFirstChild("TerminalUI")
	if not terminalUi then
		fail("StarterGui.TerminalUI is missing")
	end
	if not terminalUi:IsA("ScreenGui") then
		fail("StarterGui.TerminalUI is not a ScreenGui")
	end

	local root = assertChild(terminalUi, "Root")
	if not root then
		fail("TerminalUI.Root is missing")
	end
	local safeArea = assertChild(root, "SafeArea")
	if not safeArea then
		fail("TerminalUI.Root.SafeArea is missing")
	end
	local main = assertChild(safeArea, "Main")
	if not main then
		fail("TerminalUI.Root.SafeArea.Main is missing")
	end
	local columns = assertChild(main, "Columns")
	if not columns then
		fail("TerminalUI.Root.SafeArea.Main.Columns is missing")
	end
	local rightPanel = assertChild(main, "RightPanel")
	if not rightPanel then
		fail("TerminalUI.Root.SafeArea.Main.RightPanel is missing")
	end

	local cpu = assertChild(columns, "CPUColumn")
	if not cpu then
		fail("TerminalUI.Root.SafeArea.Main.Columns.CPUColumn is missing")
	end
	local ram = assertChild(columns, "RAMColumn")
	if not ram then
		fail("TerminalUI.Root.SafeArea.Main.Columns.RAMColumn is missing")
	end
	local sto = assertChild(columns, "STOColumn")
	if not sto then
		fail("TerminalUI.Root.SafeArea.Main.Columns.STOColumn is missing")
	end

	local cpuCards = assertChild(cpu, "Cards_CPU")
	if not cpuCards then
		fail("TerminalUI.Root.SafeArea.Main.Columns.CPUColumn.Cards_CPU is missing")
	end
	local ramCards = assertChild(ram, "Cards_RAM")
	if not ramCards then
		fail("TerminalUI.Root.SafeArea.Main.Columns.RAMColumn.Cards_RAM is missing")
	end
	local stoCards = assertChild(sto, "Cards_STORAGE")
	if not stoCards then
		fail("TerminalUI.Root.SafeArea.Main.Columns.STOColumn.Cards_STORAGE is missing")
	end
end

return TerminalUISanityCheck

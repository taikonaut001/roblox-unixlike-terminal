local UserInputService = game:GetService("UserInputService")
local Signal = require(game.ReplicatedStorage.Common.signal)

local keyboard = {}
keyboard.textadded = Signal.new()
keyboard.arrowpressed = Signal.new()
keyboard.backspaced = Signal.new()

local screengui = Instance.new("ScreenGui")
screengui.Name = "Keyboard"
screengui.Parent = game.Players.LocalPlayer.PlayerGui

local textbox = Instance.new("TextBox")
textbox.Position = UDim2.new(-10000, 0, 0, 0)
textbox.ClearTextOnFocus = false
textbox.Parent = screengui

local function reset()
	textbox.Text = ""
	textbox:CaptureFocus()
end

local function changed()
	local newtext = textbox.Text:gsub(string.char(13), "\n")
	if newtext ~= "" then
		keyboard.textadded:invoke(newtext)
		reset()
	end
end

textbox.FocusLost:Connect(reset)
textbox:GetPropertyChangedSignal("Text"):Connect(changed)

reset()

local holdkey
local holdablekeys = {
	Enum.KeyCode.Backspace,
	Enum.KeyCode.Left,
    Enum.KeyCode.Right,
    Enum.KeyCode.Up,
    Enum.KeyCode.Down,
}
local arrowkeys = {
	Enum.KeyCode.Left,
    Enum.KeyCode.Right,
    Enum.KeyCode.Up,
    Enum.KeyCode.Down,
}

local function doholdkey(key)
	if key == Enum.KeyCode.Backspace then
		keyboard.backspaced:invoke()
	elseif table.find(arrowkeys, key) then
		keyboard.arrowpressed:invoke(key)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if table.find(holdablekeys, input.KeyCode) then
			holdkey = input.KeyCode
			doholdkey(holdkey)
			local start = tick()
			while tick() - start < 0.4 and input.KeyCode == holdkey and UserInputService:IsKeyDown(holdkey) do
				task.wait()
			end
			while holdkey == input.KeyCode do
				doholdkey(holdkey)
				for _ = 1, 3 do task.wait() end
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		holdkey = nil
	end
end)

return keyboard

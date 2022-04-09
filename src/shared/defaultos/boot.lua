return [[
use("instance")
use("math")
use("table")
use("string")
use("keyboard")
use("lua")
use("luau")
use("luauclass")
use("debug")
use("luavm")
use("disks")
use("namespaces")

local SPACEBYTE = 32
local SOLIDBYTE = 219

local CELLWIDTH = 9
local CELHEIGHT = 16
local DISPWIDTH = 128 -- TODO size based on screen
local DISPHEIGHT = 48
local DEFAULTFONTCOLOR = Color3.fromRGB(168, 168, 168)

local function createcell()
	local cell = Instance.new("ImageLabel")
	cell.BackgroundTransparency = 1
	cell.BorderSizePixel = 0
	cell.Image = "rbxassetid://9254773953"
	cell.ImageRectSize = Vector2.new(CELLWIDTH, CELHEIGHT)
	cell.Size = UDim2.new(0, CELLWIDTH, 0, CELHEIGHT)
	cell.ImageColor3 = DEFAULTFONTCOLOR
	return cell
end

local function setcellchar(cell, charbyte)
	local x = charbyte % 32
	local y = math.floor(charbyte / 32)
	cell.ImageRectOffset = Vector2.new(x * CELLWIDTH + 8, y * CELHEIGHT + 8)
	cell:SetAttribute("charbyte", charbyte)
end

local function setcellcolor(cell, color)
	cell.ImageColor3 = color
end

local function getcellchar(cell)
	return cell:GetAttribute("charbyte") or SPACEBYTE
end

local function getcellcolor(cell)
	return cell.ImageColor3
end

local function createdisplay(parent, w, h)
	local display = table.create(h)
	for y = 1, h do
		display[y] = table.create(w)
		for x = 1, w do
			local label = createcell()
			setcellchar(label, SPACEBYTE)
			label.Position = UDim2.new(0, x * CELLWIDTH, 0, y * CELHEIGHT)
			label.Parent = parent
			display[y][x] = label
		end
	end
	return display
end

local function cleardisplay(display)
	for y = 1, #display do
		for x = 1, #display[y] do
			setcellchar(display[y][x], SPACEBYTE)
			setcellcolor(display[y][x], DEFAULTFONTCOLOR)
		end
	end
end

local displayfolder
do
    local termscreen = Instance.new("ScreenGui")
    termscreen.Name = "Terminal"
    termscreen.Parent = game.Players.LocalPlayer.PlayerGui

    displayfolder = Instance.new("Folder")
    displayfolder.Name = "Display"
    displayfolder.Parent = termscreen

    local background = Instance.new("Frame")
    background.Size = UDim2.new(100, 0, 100, 0)
    background.Position = UDim2.new(0.5, 0, 0.5, 0)
    background.AnchorPoint = Vector2.new(0.5, 0.5)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.ZIndex = -10
    background.Parent = termscreen
end
-- terminal environment
local display = createdisplay(displayfolder, DISPWIDTH, DISPHEIGHT)
local cursorx = 1
local cursory = 1
local user = "root"
local directory = "/"
local rootfs = bootdevice.parts[2] -- TODO
local cmdhistory = {}

local function scroll(amount)
	assert(amount >= 1)
	for y = 1, DISPHEIGHT do
		for x = 1, DISPWIDTH do
			local newchar, newcolor
			if y + amount > DISPHEIGHT then
				newchar = SPACEBYTE
				newcolor = DEFAULTFONTCOLOR
			else
				newchar = getcellchar(display[y + amount][x])
				newcolor = getcellcolor(display[y + amount][x])
			end
			setcellchar(display[y][x], newchar)
			setcellcolor(display[y][x], newcolor)
		end
	end
end

local function clear()
	cleardisplay(display)
	cursory = 1
	cursorx = 1
end

local function newline()
	if cursory == DISPHEIGHT then
		scroll(1)
	else
		cursory = cursory + 1
	end
	cursorx = 1
end

local function puttext(text)
	text = text:gsub("\t", "    ")
	for i = 1, #text do
		local char = text:sub(i, i)
		if cursorx + 1 > DISPWIDTH then
			break
		end
		setcellchar(display[cursory][cursorx], char:byte())
		cursorx = cursorx + 1
	end
end

local function wraptext(text, maxlength)
	assert(maxlength ~= nil)
	text = text:gsub("\t", "    ")
	local lines = text:split("\n")
	for i = 1, #lines do
		local line = lines[i]
		local new = ""
		for i = 1, #line, maxlength do
			new = new .. line:sub(i, i + maxlength) .. "\n"
		end
		new = new:sub(1, -2)
		lines[i] = new
	end
	return table.concat(lines, "\n")
end

local COLORCODES = {
	["0"] = DEFAULTFONTCOLOR,
	["30"] = Color3.fromRGB(0, 0, 0), -- BLACK
	["31"] = Color3.fromRGB(255, 62, 62), -- RED
	["32"] = Color3.fromRGB(62, 255, 62), -- GREEN
	["33"] = Color3.fromRGB(255, 255, 90), -- YELLOW
	["34"] = Color3.fromRGB(95, 95, 255), -- BLUE
	["35"] = Color3.fromRGB(128, 0, 128), -- PURPLE
	["36"] = Color3.fromRGB(0, 255, 255), -- CYAN
	["97"] = Color3.fromRGB(255, 255, 255), -- WHITE
}

local function wraptext(text)
	local wrapped = ""
	for i, line in ipairs(text:split("\n")) do
		-- start at 0 for new line characters splits
		for i = 0, #line, DISPWIDTH do
			wrapped = wrapped .. line:sub(i, i + DISPWIDTH - 1) .. "\n"
		end
	end
	return wrapped:sub(1, -2)
end

local function echo(text)
	text = wraptext(text:gsub("\t", "    "))
	local color = DEFAULTFONTCOLOR
	local index = 1

	-- TODO wrap text
	local linecount = #text - #text:gsub("\n", "") + 1
	if linecount > DISPHEIGHT then
		local lines = text:split("\n")
		lines = table.move(lines, linecount - DISPHEIGHT + 1, linecount, 1, {})
		text = table.concat(lines, "\n")
		linecount = DISPHEIGHT
	end
	if linecount + cursory > DISPHEIGHT then
		local scrollby = cursory + linecount - DISPHEIGHT
		scroll(scrollby)
		cursory = math.max(1, cursory - scrollby)
	end
	
	while index <= #text do
		local putchar
		if text:sub(index, index + 1) == "\\\\" then
			-- put \
			index = index + 1 -- add 1 again later
			putchar = "\\"
		elseif text:sub(index, index + 1) == "\\[" then
			-- put [
			index = index + 1 -- add 1 again later
			putchar = "["
		elseif text:sub(index, index) == "[" then
			-- color %b[]
			local capture = text:match("%b[]", index)
			if capture == nil then
				warn("no capture")
				break
			end
			local code = capture:sub(2, -2)
			color = COLORCODES[code] or color
			index = index + #capture
		else
			putchar = text:sub(index, index)
		end
		
		if putchar ~= nil then
			if putchar == "\n" then
				cursory = cursory + 1
				cursorx = 1
			else
				local cell = display[cursory][cursorx]
				setcellcolor(cell, color)
				setcellchar(cell, putchar:byte())
				cursorx = cursorx + 1
			end
			index = index + 1
		end
	end
end

local function esc(text)
	return text
end

local BYTEUNITS = {
	{0, "B"},
	{10, "KiB"},
	{20, "MiB"},
	{30, "GiB"},
	{40, "TiB"},
	{50, "PiB"},
	{60, "EiB"},
}

local function formatbytesize(size)
	if size == 0 then return "0B" end
	assert(math.floor(size) == size)
	assert(size >= 1)
	local magnitude = math.floor(math.log(size, 2))
	for i = 2, #BYTEUNITS do
		if magnitude < BYTEUNITS[i][1] then
			local unit = BYTEUNITS[i - 1]
			if i == 2 then return size .. "B" end
			return string.format("%.1f%s", size / 2 ^ unit[1], unit[2])
		end
	end
	error()
end

local function parentchild(path)
	--assert(path ~= "/")
	if path == "/" then return "/", "" end
	local parent = path:split("/")
	if path:sub(-1, -1) == "/" then
		parent[#parent] = nil
	end
	local child = parent[#parent]
	parent[#parent] = nil
	parent = table.concat(parent, "/") .. "/"
	return parent, child
end

local function parsedir(dir)
	--if dir == "/" then return dir end
	if dir:sub(1, 1) == "." then
		dir = directory .. dir:sub(3)
	end
	if dir:sub(1, 1) == "/" then
		return dir
	elseif directory:sub(-1, -1) == "/" then
		return directory .. dir
	else
		return directory .. "/" .. dir
	end
end

local function splitbash(str)
	local separators = {">>", ">"} -- must be ordered from longest to shortest
	local parts = {}
	local index = 1
	
	local function skipwhitespace()
		index = str:find("[^%s]", index)
	end
	
	local function captureliteral()
		assert(str:sub(index, index) == "\"")
		index = index + 1
		local capture = ""
		while index <= #str do
			local char = str:sub(index, index)
			if char == "\"" then
				index = index + 1
				return capture
			elseif char == "\\" and str:sub(index + 1, index + 1) == "\"" then
				capture = capture .. "\""
				index = index + 2
			else
				capture = capture .. char
				index = index + 1
			end
		end
		error("malformed string literal")
	end
	
	local function capturepart()
		for _, separator in ipairs(separators) do
			if str:sub(index, index + #separator - 1) == separator then
				index = index + #separator
				return separator
			end
		end
		local part = ""
		while index <= #str do
			local char = str:sub(index, index)
			local isliteral = char == "\""
			if char == "\"" then
				part = part .. captureliteral()
			elseif char == "\\" then
				part = part .. str:sub(index + 1, index + 1)
				index = index + 2
			elseif table.find(separators, char) or char:match("%s") ~= nil then
				return part
			else
				part = part .. str:sub(index, index)
				index = index + 1
			end
		end
		return part
	end
	
	while index <= #str do
		skipwhitespace()
		parts[#parts + 1] = capturepart()
	end
	return parts
end

local osnamespaces = {
	log = {
		echo = echo,
		esc = esc,
		clear = clear,
	},
	filesys = {
		parsedir = parsedir,
		parentchild = parentchild,
		formatbytesize = formatbytesize,
		getdirectory = function()
			return directory
		end,
		setdirectory = function(dir)
			directory = dir
		end,
		getrootfs = function()
			return rootfs
		end,
	}
}

local function bcenv()
	local env = {
		print = print, -- debug
	}
	
	env.use = function(name)
		local namespace = osnamespaces[name]
			or namespaces[name]
			or error("namespace '" .. name .. "' does not exist")
		for k, v in pairs(namespace) do
			env[k] = v
		end
	end
	
	return env
end

local function execute(argv, envoverride)
	local bc, bcdir
	do
		local identifier = argv[1]
		local firstchar = identifier:sub(1, 1)
		if firstchar == "/" or firstchar == "." or firstchar == ".." or firstchar == "~" then
			bcdir = parsedir(identifier)
			local success, result = pcall(function()
				return rootfs:get(bcdir)
			end)
			if not success or result == nil then
				echo(identifier .. ": no such file or directory\n")
				return
			end
			bc = result
		else
			bcdir = "/bin/" .. identifier
			bc = rootfs:get(bcdir)
			if bc == nil then
				echo(identifier .. ": command not found\n")
				return
			end
		end
	end
	
	local success, result = pcall(function()
		return lbi:interpret(bc, envoverride or bcenv())
	end)
	
	if not success then
		echo(bcdir .. ": error while executing lua bytecode\n[31]" .. result .. "\n")
		return
	end
	
	local cmdfunc = result
	assert(type(cmdfunc) == "function")
	local argvcopy = table.move(argv, 1, #argv, 1, {})
	success, result = pcall(cmdfunc, argvcopy)
	
	if not success then
		echo("lua error while executing command\n" .. "[31]" .. esc(result) .. "\n")
	end
end

local function collectoutput(argv)
	local env = bcenv()
	local olduse = env.use
	local output = ""
	
	local pipenamespace = {}
	pipenamespace.log = {
		echo = function(text)
			output = output .. text
		end,
		esc = esc,
		clear = function()end,
	}
	setmetatable(pipenamespace, {__index = osnamespace})
	
	env.use = function(name)
		local namespace
		if name == "log" then
			namespace = {
				--display = display, -- TODO
				echo = function(text)
					output = output .. text
				end,
				esc = esc,
				clear = function()
					-- TODO ??
				end,
			}
		else
			namespace = namespaces[name]
				or error("namespace does not exist: " .. name)
		end
		for k, v in pairs(namespace) do
			env[k] = v
		end
	end
	
	execute(argv, env)
	assert(output:sub(-1, -1) == "\n")
	output = output:sub(1, -2)
	return output
end

local function runcmd(command)
	local success, result = pcall(splitbash, command)
	local argv
	if success then
		argv = result
	else
		echo("error while parsing command '" .. command .. "': " .. result)
		return
	end
	if #argv == 0 then return end
	local redirection = table.find(argv, ">") or table.find(argv, ">>")
	if redirection ~= nil then
		local sender = table.move(argv, 1, redirection - 1, 1, {})
		local receiver = table.move(argv, redirection + 1, #argv, 1, {})
		local path = parsedir(receiver[1])
		
		local success, result = pcall(function()
			rootfs:get(path)
		end)
		
		if not success then
			echo(receiver[1] .. ": no such file or directory\n")
			return
		end
		
		local parent, child = parentchild(path)
		local sent = collectoutput(sender)
		
		if argv[redirection] == ">" then
			rootfs:get(parent)[child] = sent
		elseif argv[redirection] == ">>" then
			local existing = rootfs:get(path)
			if existing == nil then
				rootfs:get(parent)[child] = sent
			else
				rootfs:get(parent)[child] = existing .. "\n" .. sent
			end
		else
			error()
		end
		return
	end
	execute(argv)
end

local function readline(history)
    -- TODO cursorx should not be allowed to go off screen
	history = history or {}
	local historyindex = 1
	table.insert(history, 1, "")
	local waiting = true
	local startcursorx = cursorx
	local cmd = ""

	local function hidecursor()
		local index = cursorx - startcursorx + 1
		setcellchar(display[cursory][cursorx], cmd:byte(index, index) or SPACEBYTE)
	end

	local function showcursor()
		setcellchar(display[cursory][cursorx], SOLIDBYTE)
	end
	
	local function updatecmd()
		for i = 1, DISPWIDTH - startcursorx do
			local charbyte = cmd:byte(i, i) or SPACEBYTE
			local x = i - 1 + startcursorx
			local cell = display[cursory][x]
			setcellchar(cell, charbyte)
			--setcellcolor(cell, DEFAULTFONTCOLOR)
		end
		showcursor()
	end
	
	local backspacedconnection = keyboard.backspaced:connect(function()
		if cursorx <= startcursorx then return end
		local relativex = cursorx - startcursorx + 1
		cmd = cmd:sub(1, relativex - 2) .. cmd:sub(relativex)
		updatecmd()
		hidecursor()
		cursorx = cursorx - 1
		showcursor()
	end)
	
	local function insert(str)
		local relativex = cursorx - startcursorx + 1
		cmd = cmd:sub(1, relativex - 1) .. str .. cmd:sub(relativex)
		updatecmd()
		hidecursor()
		cursorx = cursorx + #str
		showcursor()
	end
	
	local function uphistory()
		hidecursor()
		history[historyindex] = cmd
		historyindex = math.clamp(historyindex + 1, 1, #history)
		cmd = history[historyindex]
		cursorx = startcursorx + #cmd
		updatecmd()
	end
	
	local function downhistory()
		hidecursor()
		history[historyindex] = cmd
		historyindex = math.clamp(historyindex - 1, 1, #history)
		cmd = history[historyindex]
		cursorx = startcursorx + #cmd
		updatecmd()
	end

	local textaddedconnection = keyboard.textadded:connect(function(text)
		if text == "\n" then
			waiting = false
		elseif text == "\t" then
			local dir
			for i = cursorx - startcursorx, 0, -1 do
				if i == 0 or cmd:sub(i, i) == " " then
					dir = cmd:sub(i + 1, cursorx - startcursorx)
					break
				end
			end
			dir = parsedir(dir)
			local inputparent, inputname = parentchild(dir)
			local possible = {}
			for name, file in pairs(rootfs:get(inputparent)) do
				if name == inputname then
					table.clear(possible)
					break
				elseif name:sub(1, #inputname) == inputname then
					possible[#possible + 1] = name
				end
			end
			if #possible == 1 then
				-- autocomplete
				local choice = possible[1]
				local choicefile = rootfs:get(inputparent .. choice)
				insert(choice:sub(#inputname + 1))
				if type(choicefile) == "table" then
					insert("/")
				end
			elseif false and #possible > 0 then
				-- print possible dirs
				local text = ""
				for _, choice in ipairs(possible) do
					text = text .. choice .. " "
				end
				text = text:sub(1, DISPWIDTH)
				if cursory == DISPHEIGHT then
					scroll(1)
					cursory = cursory - 1
				end
				for i = 1, #text do
					setcellchar(display[cursory + 1][i], text:byte(i, i))
				end
			end
		else
			insert(text)
		end
	end)

	local arrowpressedconnection = keyboard.arrowpressed:connect(function(key)
		if key == Enum.KeyCode.Up then
			uphistory()
			return
		elseif key == Enum.KeyCode.Down then
			downhistory()
			return
		end
		hidecursor()
		if key == Enum.KeyCode.Left then
			cursorx = cursorx - 1
		elseif key == Enum.KeyCode.Right then
			cursorx = cursorx + 1
		end
		cursorx = math.clamp(cursorx, startcursorx, startcursorx + #cmd)
		showcursor()
	end)
	
	while waiting do
		if tick() % 1 < 0.5 then
			showcursor()
		else
			hidecursor()
		end
		local start = tick()
		while tick() - start < 0.5 and waiting do
			task.wait()
		end
	end
	
	backspacedconnection:disconnect()
	textaddedconnection:disconnect()
	arrowpressedconnection:disconnect()
	
	hidecursor()
	newline()
	if history[2] == cmd then
		table.remove(history, 1)
	else
		history[1] = cmd
	end
	
	return cmd
end

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local function getprefix(username, hostname, dir)
	local template = "[33]\\[%s@%s [36]%s[33]" .. "]$ " -- avoid double square bracket
	local displaydir
	if directory == "/" then
		displaydir = directory
	else
		_, displaydir = parentchild(dir)
	end
	return template:format(username, hostname, displaydir)
end

--local colsize = 8 -- 5 + 3 space
--for col = 1, math.floor(DISPWIDTH / colsize) do
--	for row = 1, math.ceil(256 / math.floor(DISPWIDTH / colsize)) do
--		local i = (col - 1) + (row - 1) * math.floor(DISPWIDTH / colsize)
--		local n = tostring(i)
--		n = string.rep("0", 3 - #n) .. n
--		setcellchar(display[row * 2][(col - 1) * colsize + 1], n:byte(1, 1))
--		setcellchar(display[row * 2][(col - 1) * colsize + 2], n:byte(2, 2))
--		setcellchar(display[row * 2][(col - 1) * colsize + 3], n:byte(3, 3))
--		setcellchar(display[row * 2][(col - 1) * colsize + 5], i)
--	end
--end

while true do
	echo(getprefix(user, "host", directory))
	local cmd = readline(cmdhistory)
	runcmd(cmd)
end
]]

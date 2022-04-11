return [[
use("lua")
use("luau")
use("luauclass")
use("instance")
use("math")
use("table")
use("string")
use("keyboard")
use("filesys") -- use with caution
use("debug")

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

local display = table.create(DISPHEIGHT)
for y = 1, DISPHEIGHT do
    display[y] = table.create(DISPWIDTH)
    for x = 1, DISPWIDTH do
        local label = createcell()
        setcellchar(label, SPACEBYTE)
        label.Position = UDim2.new(0, x * CELLWIDTH, 0, y * CELHEIGHT)
        label.Parent = displayfolder
        display[y][x] = label
    end
end

local cursorx = 1
local cursory = 1
local user = "root"
local directory = "/"
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
    for y = 1, #display do
        for x = 1, #display[y] do
            setcellchar(display[y][x], SPACEBYTE)
            setcellcolor(display[y][x], DEFAULTFONTCOLOR)
        end
    end
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

local function parsedir(dir)
    if dir:sub(1, 2) == ".." then
		local parent, child = parentchild(directory)
		dir = parent .. dir:sub(4)
	elseif dir:sub(1, 1) == "." then
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

local function echo(text)
    text = wraptext(text:gsub("\t", "    "))
    local color = DEFAULTFONTCOLOR
    local index = 1

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
            color = COLORCODES[code] or error("invalid color code '" .. code .. "'")
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
            for name, file in pairs(getrootfs():get(inputparent)) do
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
                local choicefile = getrootfs():get(inputparent .. choice)
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

local function getprefix()
    local template = "[33]\\[%s@%s [36]%s[33]" .. "]$ " -- avoid double square bracket
    local displaydir
    if directory == "/" then
        displaydir = directory
    else
        _, displaydir = parentchild(directory)
    end
    return template:format(user, "host", displaydir)
end

return {
    echo = function(self, text)
        echo(text)
    end,
    clear = function(self)
        clear()
    end,
    readline = function(self)
        return readline()
    end,
    esc = function(self, text)
        return text:gsub("\\", "\\\\"):gsub("%[", "\\[")
    end,
    readcommand = function(self)
        echo(getprefix())
        return readline(cmdhistory)
    end,
    getdirectory = function(self)
        return directory
    end,
    setdirectory = function(self, dir)
        directory = dir
    end,
    parsedir = function(self, dir)
        return parsedir(dir)
    end,
    getheight = function(self)
        return DISPHEIGHT
    end,
    getwidth = function(self)
        return DISPWIDTH
    end
}
]]
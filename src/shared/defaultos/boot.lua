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

local rootfs = bootdevice.parts[2] -- TODO

local function bcenv(usenamespaces)
	local env = {
		print = print, -- debug
	}
	env.use = function(name)
		local namespace = usenamespaces[name]
		local libmodule = rootfs:pathto("/lib/" .. name)
		if namespace == nil and type(libmodule) == "string" then
			-- TODO circular imports
			local module = lbi:interpret(libmodule, bcenv(usenamespaces))
			namespace = {[name] = module}
		end
		assert(namespace ~= nil, "namespace '" .. name .. "' does not exist")
		for k, v in pairs(namespace) do
			env[k] = v
		end
	end
	return env
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

local terminal

local osnamespaces = {
	filesys = {
		parsedir = function(dir)
            return terminal:parsedir(dir) 
        end,
		parentchild = parentchild,
		formatbytesize = formatbytesize,
		getdirectory = function()
			return terminal:getdirectory()
		end,
		setdirectory = function(dir)
			terminal:setdirectory(dir)
		end,
		getrootfs = function()
			return rootfs -- future plans: chroot command
		end,
	}
}
setmetatable(osnamespaces, {__index = namespaces})

do
    local bc = rootfs:get("/lib/terminal")
    terminal = lbi:interpret(bc, bcenv(osnamespaces))
end

osnamespaces.log = {
	getdispwidth = function()
		return terminal:getwidth()
	end,
	getdispheight = function()
		return terminal:getheight()
	end,
    echo = function(text)
        terminal:echo(text)
    end,
    readline = function()
        return terminal:readline()
    end,
    clear = function()
        terminal:clear()
    end,
    esc = function(text)
        return terminal:esc(text)
    end,
}

local function execute(argv, envoverride)
	local bc, bcdir
	do
		local identifier = argv[1]
		local firstchar = identifier:sub(1, 1)
		if firstchar == "/" or firstchar == "." or firstchar == ".." or firstchar == "~" then
			bcdir = terminal:parsedir(identifier)
			bc = rootfs:pathto(bcdir)
			if not bc then
				terminal:echo(identifier .. ": no such file or directory\n")
				return
			end
		else
			bcdir = "/bin/" .. identifier
			bc = rootfs:pathto(bcdir)
			if not bc then
				terminal:echo(identifier .. ": command not found\n")
				return
			end
		end
	end
	local success, result = pcall(function()
		return lbi:interpret(bc, envoverride or bcenv(osnamespaces))
	end)
	if not success then
		terminal:echo(bcdir .. ": error while executing lua bytecode\n[31]" .. result .. "\n")
		return
	end
	local cmdfunc = result
	assert(type(cmdfunc) == "function")
	local argvcopy = table.move(argv, 1, #argv, 1, {})
	success, result = pcall(cmdfunc, argvcopy)
	if not success then
		terminal:echo("lua error while executing command\n" .. "[31]" .. terminal:esc(result) .. "\n")
	end
end

local function collectoutput(argv)
	local output = ""
	local pipenamespaces = {
		log = {
			echo = function(text)
				output = output .. text
			end,
			esc = function(s)return s end,
			clear = function()end,
			getdispwidth = osnamespaces.getdispwidth,
			getdispheight = osnamespaces.getdispheight,
			-- no support for readline yet.
		}
	}
	setmetatable(pipenamespaces, {__index = osnamespaces})
	local env = bcenv(pipenamespaces)
	execute(argv, env)
	if output:sub(-1, -1) == "\n" then
		output = output:sub(1, -2)
	end
	return output
end

local function runcmd(command)
	local success, result = pcall(splitbash, command)
	local argv
	if success then
		argv = result
	else
		terminal:echo("error while parsing command '" .. command .. "': " .. result)
		return
	end
	if #argv == 0 then return end
	local redirection = table.find(argv, ">") or table.find(argv, ">>")
	if redirection ~= nil then
		local sender = table.move(argv, 1, redirection - 1, 1, {})
		local receiver = table.move(argv, redirection + 1, #argv, 1, {})
		local path = terminal:parsedir(receiver[1])
		local sendto = rootfs:pathto(path)
		if sendto == false then
			terminal:echo(receiver[1] .. ": no such file or directory\n")
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

while true do
	local cmd = terminal:readcommand()
	runcmd(cmd)
end
]]

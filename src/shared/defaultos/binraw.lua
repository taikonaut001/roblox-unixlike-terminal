return{
	lsblk = [[
use("log")
use("filesys")
use("disks")
use("lua")
use("math")
use("string")
use("table")
return function(argv)
	local items = {{"NAME", "SIZE", "TYPE"}}
	for _, disk in ipairs(disks) do
		local diskname = disk.name
		local disksize = formatbytesize(disk:size())
		items[#items + 1] = {diskname, disksize, "disk"}
		-- TODO mountpoint
		for i, part in ipairs(disk.parts) do
			local partname = diskname .. i
			local partsize = formatbytesize(part:size())
			partname = string.char(196) .. partname -- ─
			if i == #disk.parts then
				partname = string.char(192) .. partname -- └
			else
				partname = string.char(195) .. partname -- ├
			end
			items[#items + 1] = {partname, partsize, "part"}
		end
	end
	for col = 1, #items[1] do
		local longest = 0
		for row = 1, #items do
			longest = math.max(longest, #items[row][col])
		end
		for row = 1, #items do
			local padding = string.rep(" ", longest - #items[row][col])
			if col == 2 then
				items[row][col] = padding .. items[row][col] .. " "
			else
				items[row][col] = items[row][col] .. padding .. " "
			end
		end
	end
	for row = 1, #items do
		items[row] = table.concat(items[row])
	end
	echo(esc(table.concat(items, "\n")) .. "\n")
end]],
	echo = [[
use("log")
use("table")
return function(argv)
	table.remove(argv, 1)
	local option_e = false
	if argv[1] == "-e" then
		option_e = true
		table.remove(argv, 1)
	end
	local text = table.concat(argv, " ")
	if option_e then
		echo(text .. "\n")
	else
		echo(esc(text) .. "\n")
	end
end]],
	cd = [[
use("lua")
use("log")
use("filesys")
return function(argv)
	if #argv > 2 then
		echo("cd: too many arguments\n")
		return
	elseif #argv == 1 then
		return
	end
	local dir = parsedir(argv[2])
	local success, result = pcall(function()
		return getrootfs():get(dir)
	end)
	if not success or result == nil then
		echo("cd: " .. esc(dir) .. ": No such file or directory\n")
		return
	end
	setdirectory(dir)
end]],
	pwd = [[
use("log")
use("filesys")
return function(argv)
	echo(esc(getdirectory()) .. "\n")
end]],
	clear = [[
use("log")
return function(argv)
	clear()
end]],
	ls = [[
use("lua")
use("log")
use("filesys")
return function(argv)
	local dir = parsedir(argv[2] or getdirectory())
	local file = getrootfs():pathto(dir)
	if not file then
		echo("ls: " .. esc(argv[2]) .. ": No such file or directory\n")
	elseif type(file) == "string" then
		echo(esc(dir) .. "\n")
	else
		for name, childfile in pairs(file) do
			if type(childfile) == "table" then
				echo("[36]" .. esc(name) .. "\n")
			else
				echo(esc(name) .. "\n")
			end
		end
	end
end]],
	cat = [[
use("lua")
use("log")
use("filesys")
return function(argv)
	if #argv > 2 then
		echo("cat: too many arguments\n")
		return
	elseif #argv == 1 then
		echo("cat: missing argument\n")
		return
	end
	local dir = parsedir(argv[2])
	local file = getrootfs():pathto(dir)
	if not file then
		echo("cat: " .. esc(argv[2]) .. ": No such file or directory\n")
	elseif type(file) == "table" then
		echo(echo "cat: " .. esc(argv[2]) .. " is a directory\n")
	else
		echo(esc(file) .. "\n")
	end
end]],
	lbc = [[
use("filesys")
use("table")
use("lua")
use("luavm")
use("log")
return function(argv)
	local option_o = table.find(argv, "-o") or table.find(argv, "--output")
	local outdir, outfile
	if option_o then
		outdir = parsedir(argv[option_o + 1])
		outfile = getrootfs():pathto(outdir)
		if outfile == false then
			echo("lbc: unable to modify output file\n")
			return
		end
		table.remove(argv, option_o)
		table.remove(argv, option_o)
	else
		echo("lbc: missing option -o or --output\n")
		return
	end
	local indir = parsedir(argv[2])
	local infile = getrootfs():pathto(indir)
	if type(infile) == "table" then
		echo("lbc: " .. esc(argv[2]) .. " is a directory\n")
		return
	elseif not infile then
		echo("lbc: '" .. esc(argv[2]) .. "': No such file or directory\n")
		return
	end
	if outfile == nil or type(outfile) == "string" then
		local outdirparent, outname = parentchild(outdir)
		local success, result = pcall(function()
			return lbc:compile(infile)
		end)
		if success then
			getrootfs():get(outdirparent)[outname] = result
		else
			echo("lbc: compilation error\n[31]" .. esc(result) .. "\n")
		end
	elseif type(outfile) == "table" then
		echo("lbc: '" .. esc(outdir) .. "' is a directory\n")
	else
		echo("lbc: unexpected error occured while parsing command\n")
	end
end]],
	rm = [[
use("filesys")
use("lua")
use("table")
use("log")
return function(argv)
	if #argv == 1 then
		echo("rm: missing operand\n")
		return
	end
	local option_rf = table.find(argv, "-rf")
	if option_rf then
		table.remove(argv, option_rf)
	end
	local path = parsedir(argv[2])
	local file = getrootfs():pathto(path)
	if not file then
		echo("rm: cannot remove '" .. argv[2] .. "': No Such file or directory\n")
	elseif type(file) == "table" and option_rf == nil then
		echo("rm: cannot remove '" .. argv[2] .. "': Is a directory\n")
	else
		local parent, child = parentchild(path)
		getrootfs():get(parent)[child] = nil
	end
end]],
	mkdir = [[
use("filesys")
use("log")
use("lua")
return function(argv)
	local path = parsedir(argv[2])
	local file = getrootfs():pathto(path)
	if file == false then
		echo("mkdir: cannot create directory '" .. argv[2] .. "': No such file or directory\n")
		return
	end
	if file == nil then
		local parent, child = parentchild(path)
		getrootfs():get(parent)[child] = {}
	else
		echo("mkdir: cannot create directory '" .. argv[2] .. "': File exists\n")
	end
end]],
	touch = [[
use("filesys")
return function(argv)
	local dir = parsedir(argv[2])
	local name = argv[3]
	if name ~= nil then
		if dir:sub(-1, -1) ~= "/" then
			dir = dir .. "/"
		end
		dir = dir .. name
	end
	local file = getrootfs():pathto(dir)
	if file == false then
		echo("touch: cannot touch '" .. argv[2] .. "': No such file or directory")
	elseif file == nil then
		local parent, child = parentchild(dir)
		getrootfs():get(parent)[child] = ""
	end
end]],
}

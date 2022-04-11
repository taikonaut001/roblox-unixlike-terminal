return{
	pkg = [[
use("log")
use("lua")
use("filesys")
use("instance")
use("table")
use("luau")
use("pkgmanager")
local remotefolder = game.ReplicatedStorage.Remotes
return function(argv)
	if getrootfs().fs.etc.pkg == nil then
		getrootfs().fs.etc.pkg = {installed = ""}
	end
	if argv[2] == "install" then
		local packagename = argv[3]
		if packagename == nil then
			echo("pkg: Missing package name")
			return
		elseif pkgmanager:isinstalled(packagename) then
			echo("Package '" .. packagename .. "' is already installed.\n")
			return
		end
		pkgmanager:choose(packagename)
		echo("Fetching package metadata...\n")
		pkgmanager:fetchmeta()
		if not pkgmanager:exists() then
			echo("Package '" .. packagename .. "' not found.\n")
			pkgmanager:done()
			return
		end
		echo(("Found '%s' version %.1f\n"):format(
			pkgmanager:name(),
			pkgmanager:version()
		))
		-- TODO check dependencies
		echo("Begin installation? \\[Y/n] ")
		local answer = readline()
		if answer:lower() ~= "y" and answer ~= "" then
			echo("Abort.\n")
			pkgmanager:done()
			return
		end
		echo("Fetching package source...\n")
		pkgmanager:fetchsrc()
		echo("Received " .. formatbytesize(#pkgmanager:src()) .. "\nInstalling package...\n")
		pkgmanager:install()
		echo("Installed " .. packagename .. "\n")
		pkgmanager:done()
	elseif argv[2] == "uninstall" then
		local pkgdir = getrootfs().fs.etc.pkg
		local packagename = argv[3]
		if packagename == nil then
			echo("pkg: Missing package name")
			return
		elseif not pkgmanager:isinstalled(packagename) then
			echo("Package '" .. packagename .. "' is not installed.\n")
			return
		end
		pkgmanager:choose(packagename)
		local size = formatbytesize(#pkgmanager:bin())
		echo(size .. " will be freed.\nUninstall package? \\[Y/n] ")
		local answer = readline()
		if answer:lower() ~= "y" and answer ~= "" then
			echo("Abort.\n")
			pkgmanager:done()
			return
		end
		pkgmanager:uninstall()
		pkgmanager:done()
		echo("Uninstalled " .. packagename .. "\n")
	elseif argv[2] == "update" then
		local packagename = argv[3]
		if packagename == nil then
			echo("pkg: Missing package name")
			return
		elseif not pkgmanager:isinstalled(packagename) then
			echo("Package '" .. packagename .. "' is not installed.\n")
			return
		end
		pkgmanager:choose(packagename)
		local currentversion = pkgmanager:currentversion()
		echo(("Current version is %.1f\nFetching package metadata...\n"):format(currentversion))
		pkgmanager:fetchmeta()
		local latestversion = pkgmanager:version()
		if latestversion == currentversion then
			echo("Already up to date\n")
			pkgmanager:done()
			return
		elseif latestversion < currentversion then
			error()
		end
		echo(("Found version %.1f\nUpdate to new version? \\[Y/n]"):format(latestversion))
		local answer = readline()
		if answer:lower() ~= "y" and answer ~= "" then
			echo("Abort.\n")
			pkgmanager:done()
			return
		end
		echo("Fetching source...\n")
		pkgmanager:fetchsrc()
		echo("Installing new version...\n")
		pkgmanager:update()
		echo("Updated " .. pkgmanager:name() .. "\n")
		pkgmanager:done()
	elseif argv[2] == "list-installed" then
		local list = pkgmanager:installedpackages()
		echo(esc(table.concat(list, "\n")) .. "\n")
	elseif argv[2] == "list" then
		local list = pkgmanager:allpackages()
		echo(esc(table.concat(list, "\n")) .. "\n")
	else
		local msg = "pkg\n"
			.. "  list - list all available packages\n"
			.. "  list-installed - list all installed packages\n"
			.. "  install [package] - install package\n"
			.. "  update - update old packages\n"
			.. "  uninstall [package] - uninstall package\n"
		echo(esc(msg) .. "\n")
	end
end]],
	lsblk = [[
use("log")
use("filesys")
use("disks")
use("lua")
use("string")
use("table")
use("formatcolumns")
return function(argv)
	local items = {{"NAME", "SIZE", "TYPE", "MOUNTPOINT"}}
	for _, disk in ipairs(disks) do
		local diskname = disk.name
		local disksize = formatbytesize(disk:size())
		items[#items + 1] = {diskname, disksize, "disk", ""}
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
			local mounts = getrootfs():get("/etc/mounts")
			local mountpoint = ""
			if getrootfs() == part then
				mountpoint = "/"
			elseif mounts ~= nil then
				for _, line in ipairs(mounts:split("\n")) do
					local a, b = table.unpack(line:split("    "))
					if a == part.uuid then
						mountpoint = b
						break
					end
				end
			end
			items[#items + 1] = {partname, partsize, "part", mountpoint}
		end
	end
	echo(esc(formatcolumns(items)) .. "\n")
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
use("math")
use("formatcolumns")
return function(argv)
	local dir = parsedir(argv[2] or getdirectory())
	local file = getrootfs():pathto(dir)
	if not file then
		echo("ls: " .. esc(argv[2]) .. ": No such file or directory\n")
	elseif type(file) == "string" then
		echo(esc(dir) .. "\n")
	else
		local files = {}
		local longest = -1
		for name, childfile in pairs(file) do
			if type(childfile) == "table" then
				files[#files + 1] = "[36]" .. name .. "[0]"
			else
				files[#files + 1] = name
			end
			longest = math.max(longest, #name)
		end
		local namesperrow = math.floor(getdispwidth() / (longest + 1))
		local rowcount = math.ceil(#files / namesperrow)
		local rows = {}
		for row = 1, rowcount do
			rows[row] = {}
			for i = 1, namesperrow do
				local index = (row - 1) * namesperrow + i
				rows[row][i] = files[index] or ""
			end
		end
		local grid = formatcolumns(rows)
		echo(grid .. "\n")
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
		echo("cat: " .. esc(argv[2]) .. " is a directory\n")
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
		echo("touch: cannot touch '" .. argv[2] .. "': No such file or directory\n")
	elseif file == nil then
		local parent, child = parentchild(dir)
		getrootfs():get(parent)[child] = ""
	end
end]],
	mount = [[
use("log")
use("filesys")
use("disks")
use("lua")
use("table")
return function(argv)
	if #argv < 3 then
		echo("mount: wrong number of arguments (2 required)\n")
		return
	end
	local devicedir = parsedir(argv[2])
	local mountpointdir = parsedir(argv[3])
	local device = getrootfs():pathto(devicedir)
	local mountpoint = getrootfs():pathto(mountpointdir)
	if not device then
		echo("mount: " .. esc(argv[2]) .. ": No such file or directory\n")
		return
	elseif not mountpoint then
		echo("mount: " .. esc(argv[3]) .. ": No such file or directory\n")
		return
	elseif type(device) == "table" then
		echo("mount: '" .. esc(devicedir) .. "' is a directory\n")
		return
	elseif type(mountpoint) == "string" then
		echo("mount: '" .. esc(mountpointdir) .. "' is not a directory\n")
		return
	end
	do
		local mounts = getrootfs():get("/etc/mounts")
		if mounts ~= nil then
			local mp
			for _, line in ipairs(mounts:split("\n")) do
				local a, b = table.unpack(line:split("    "))
				if a == device then
					mp = b
					break
				end
			end
			if mp then
				echo("mount: device is already mounted to " .. esc(mp) .. "\n")
				return
			end
		end
	end
	for _ in pairs(mountpoint) do
		echo("mount: '" .. esc(mountpointdir) .. "' is not empty\n")
		return
	end
	local mountdevice
	for _, disk in ipairs(disks) do
		for _, part in ipairs(disk.parts) do
			if part.uuid == device then
				-- if part.type ~= "fs" then
				-- 	echo("mount: unable to mount device of type " .. part.type .. "\n")
				-- 	return
				-- end
				local etc = getrootfs():get("/etc/")
				local parent, child = parentchild(mountpointdir)
				getrootfs():get(parent)[child] = part.fs
				etc.mounts = (etc.mounts or "") .. part.uuid .. "    " .. mountpointdir .. "\n"
				mountdevice = part
				return
			end
		end
	end
	echo("no mountable device found\n")
end]],
	umount = [[
use("log")
use("filesys")
use("disks")
use("lua")
use("table")
return function(argv)
	local umountdir = parsedir(argv[2])
	local dir = getrootfs():pathto(umountdir)
	if not dir then
		echo("umount: " .. argv[2] .. ": No such file or directory\n")
		return
	end
	local mounts = getrootfs():get("/etc/mounts")
	local uuid
	if mounts ~= nil then
		for _, line in ipairs(mounts:split("\n")) do
			local a, b = table.unpack(line:split("    "))
			if b == umountdir then
				uuid = a
				break
			end
		end
	end
	if uuid ~= nil then
		local parent, child = parentchild(umountdir)
		getrootfs():get(parent)[child] = {}
		local i, j = mounts:find(uuid .. "    " .. esc(umountdir) .. "\n", nil, true)
		getrootfs():get("/etc/").mounts = mounts:sub(1, i - 1) .. mounts:sub(j + 1)
	else
		echo("umount: No device currently mounted to " .. umountdir)
	end
end]],
}

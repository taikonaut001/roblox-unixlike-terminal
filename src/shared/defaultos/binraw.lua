return{
	lsblk = [[
use("log")
use("filesys")
use("disks")
use("lua")
use("string")
use("table")
import("formatcolumns")
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
return function(argv)
	local dir = parsedir(argv[2] or getdirectory())
	local file = getrootfs():pathto(dir)
	if not file then
		echo("ls: " .. esc(argv[2]) .. ": No such file or directory\n")
	elseif type(file) == "string" then
		echo(esc(dir) .. "\n")
	else
		local output = ""
		for name, childfile in pairs(file) do
			if type(childfile) == "table" then
				output = output .. "[36]" .. esc(name) .. "\n"
			else
				output = output .. "[0]" .. esc(name) .. "\n"
			end
		end
		echo(output)
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
				if part.type ~= "fs" then
					echo("mount: unable to mount device of type " .. part.type .. "\n")
					return
				end
				local etc = getrootfs():get("/etc/")
				local parent, child = parentchild(mountpointdir)
				getrootfs():get(parent)[child] = part.fs
				etc.mounts = (etc.mounts or "") .. part.uuid .. "    " .. mountpointdir .. "\n"
				mountdevice = part
				break
			end
		end
		if mountdevice then break end
	end
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
	fdisk = [[
use("filesys")
use("disks")
use("lua")
use("log")
use("table")
use("instance")
import("formatcolumns")
local StorageDevice = require(game.ReplicatedStorage.Common.storagedevice)
local DiskDevice = require(game.ReplicatedStorage.Common.diskdevice)

local function diskinfo(disk)
	local items = {{"Device", "Size", "Type"}}
	for _, part in ipairs(disk.parts) do
		local devicename = "/dev/" .. part.name
		local size = formatbytesize(part:size())
		items[#items + 1] = {devicename, size, part.type}
	end
	local columns = ""
	if #items > 1 then
		columns = formatcolumns(items)
		local _, firstlineend = columns:find(".-\n")
		firstlineend = firstlineend or #columns
		-- first line is white, rest is default grey
		columns = "[97]" .. columns:sub(1, firstlineend) .. "[0]" .. columns:sub(firstlineend + 1)
		columns = "\n\n" .. columns
	end
	local msgtemplate = "[97]Disk %s: %s[0]\n"
		.. "Disk identifier: " .. esc(disk.uuid) .. "%s"
	return msgtemplate:format(
		esc("/dev/" .. disk.name),
		formatbytesize(disk:size()),
		columns
	)
end

local function doactions(disk, actions)
	for _, action in ipairs(actions) do
		if action[1] == "newpart" then
			disk.parts[#disk.parts + 1] = action[2]
		end
	end
	for _, action in ipairs(actions) do
		if action[1] == "deletepart" then
			for i, part in ipairs(disk.parts) do
				if part.uuid == action[2] then
					table.remove(disk.parts, i)
					break
				end
			end
		end
	end
end

local function createfakedisk(disk)
	local fakedisk = DiskDevice.new(1)
	fakedisk.name = disk.name
	fakedisk.uuid = disk.uuid
	for i, part in ipairs(disk.parts) do
		local fakepart = StorageDevice.empty()
		-- fakepart.uuid = part.uuid
		fakepart.type = part.type
		fakepart.name = part.name
		fakepart.size = function() return part:size() end
		fakedisk.parts[i] = fakepart
	end
	return fakedisk
end

return function(argv)
	if #argv == 1 then
		echo("fdisk: bad usage\n")
		return
	elseif argv[2] == "-l" then
		local diskinfos = {}
		for i, disk in ipairs(disks) do
			diskinfos[i] = diskinfo(disk)
		end
		echo(table.concat(diskinfos, "\n\n") .. "\n")
		return
	end
	local devicedir = parsedir(argv[2])
	local deviceid = getrootfs():pathto(devicedir)
	if not deviceid then
		echo("fdisk: " .. esc(argv[2]) .. ": No such file or directory\n")
		return
	end
	local selecteddisk
	for _, disk in ipairs(disks) do
		if disk.uuid == deviceid then
			selecteddisk = disk
		end
		for _, part in ipairs(disk.parts) do
			if part.uuid == deviceid then
				echo("fdisk: " .. esc(argv[2]) .. " is a partition\n")
				return
			end	
		end
	end
	if selecteddisk == nil then
		echo("fdisk: not a disk\n")
		return
	end
	local welcome = "\n[32]Welcome to fdisk[0]\n"
		.. "Changes will remain in memory only, until you decide to write them.\n"
		.. "Be careful before using the write command.\n\n\n"
	echo(welcome)
	local help = "\nHelp:\n\n"
		.. " m  print this menu\n"
		.. " n  add a new partition\n"
		.. " p  print the partition table\n"
		.. " q  quit without saving changes\n"
		.. " w  write table to disk and exit\n\n\n"
	local actions = {}
	local fakedisk = createfakedisk(selecteddisk)
	doactions(fakedisk, actions)
	while true do
		echo("Command (m for help): ")
		local cmd = readline()
		if cmd == "d" then
			local n
			if #fakedisk.parts == 1 then
				n = 1
			elseif #fakedisk.parts == 0 then
				echo("[31]No partition is defined yet!\n\n")
			else
				while n == nil do
					echo(("Partition number (1,%s, default %s): "):format(
						#fakedisk.parts, #fakedisk.parts
					))
					n = tonumber(readline())
					if n > #fakedisk.parts or n < 1 or n % 1 ~= 0 then
						n = nil
						echo("[31]Value out of range.\n\n")
					end
				end
			end
			if n ~= nil then
				actions[#actions + 1] = {"deletepart", fakedisk.parts[n].uuid}
				fakedisk = createfakedisk(selecteddisk)
				doactions(fakedisk, actions)
			end
		elseif cmd == "m" then
			echo(help)
		elseif cmd == "p" then
			echo(diskinfo(fakedisk) .. "\n")
		elseif cmd == "n" then
			local part = StorageDevice.empty()
			part.name = fakedisk.name .. (#fakedisk.parts + 1)
			echo("Partition type: ")
			while true do
				local parttype = readline()
				if parttype ~= "fs" and parttype ~= "boot" then
					echo(esc(parttype) .. ": invalid partition type\n")
				end
				part.type = parttype
				if part.type == "fs" then
					part.fs = {}
				elseif part.type == "boot" then
					part.program = ""
				end
				break
			end
			echo(("Created a new partition %s of type '%s'.\n\n"):format(
				#fakedisk.parts + 1, part.type
			))
			actions[#actions + 1] = {"newpart", part}
			fakedisk = createfakedisk(selecteddisk)
			doactions(fakedisk, actions)
		elseif cmd == "q" then
			break
		elseif cmd == "w" then
			for _, part in ipairs(fakedisk.parts) do
				if getrootfs():get("/dev/" .. part.name) == nil then
					getrootfs():get("/dev/")[part.name] = part.uuid
				end
			end
			doactions(selecteddisk, actions)
			break
		else
			echo("[31]" .. esc(cmd) .. ": unknown command\n\n")
		end
	end
end]],
	test = [[
local test = import("testlib")
use("log")
return function(argv)
	echo(test() .. "\n")
end]]
}

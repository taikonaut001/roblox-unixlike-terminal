use("filesys")
use("disks")
use("lua")
use("log")
use("table")
use("instance")
use("formatcolumns")
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
            local part = StorageDevice.empty()
            part.name = disk.name .. (#disk.parts + 1)
            part.type = action[2]
            part.uuid = action[3]
            part.fs = {}
            disk.parts[#disk.parts + 1] = part
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
        .. " d  delete a partition\n"
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
                    local nraw = readline()
                    if nraw == "" then
                        n = #fakedisk.parts
                    else
                        n = tonumber(nraw)
                    end
                    if n ~= nil and (n > #fakedisk.parts or n < 1 or n % 1 ~= 0) then
                        n = nil
                        echo("[31]Value out of range.\n\n")
                    end
                end
            end
            if n ~= nil then
                local uuid = fakedisk.parts[n].uuid
                local deletedaction = false
                for i, action in ipairs(actions) do
                    if action[1] == "newpart" and action[3] == uuid then
                        deletedaction = true
                        table.remove(actions, i)
                        break
                    end
                end
                if not deletedaction then
                    actions[#actions + 1] = {"deletepart", uuid}
                end
                fakedisk = createfakedisk(selecteddisk)
                doactions(fakedisk, actions)
            end
        elseif cmd == "m" then
            echo(help)
        elseif cmd == "p" then
            echo(diskinfo(fakedisk) .. "\n")
        elseif cmd == "n" then
            local parttype
            -- part.name = fakedisk.name .. (#fakedisk.parts + 1)
            while true do
                echo("Partition type: ")
                parttype = readline()
                if parttype == "fs" or parttype == "boot" then
                    break
                else
                    echo(esc(part.type) .. ": invalid partition type\n")
                end
            end
            echo(("Created a new partition %s of type '%s'.\n\n"):format(
                #fakedisk.parts + 1, parttype
            ))
            local part = StorageDevice.empty()
            actions[#actions + 1] = {"newpart", parttype, part.uuid}
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
end
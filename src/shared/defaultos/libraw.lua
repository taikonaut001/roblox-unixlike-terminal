return {
    pkgmanager = [[
use("filesys")
use("lua")
use("instance")
use("debug")
use("table")
use("luavm")
local remotefolder = game.ReplicatedStorage.Remotes
local manager = {}
local meta, src, packagename
function manager:done()
    meta = nil
    src = nil
    packagename = nil
end
function manager:choose(name)
    if packagename then manager:done() end
    packagename = name
end
function manager:fetchmeta()
    -- false <--> meta does not exist
    -- table <--> meta exists
    meta = remotefolder.pkggetmeta:InvokeServer(packagename) or false
end
function manager:fetchsrc()
    src = remotefolder.pkgget:InvokeServer(packagename)
end
function manager:allpackages()
    return remotefolder.pkglist:InvokeServer()
end
function manager:installedpackages()
    local list = {}
    for _, line in ipairs(getrootfs().fs.etc.pkg.installed:split("\n")) do
        local parts = line:split(" ")
        local name = parts[1]
        -- local version = tonumber(parts[2])
        if name ~= nil and #name > 0 then
            list[#list + 1] = name
        end
    end
    return list
end
function manager:isinstalled(name)
    return getrootfs().fs.etc.pkg.installed:find(name, nil, true) ~= nil
end
function manager:exists()
    assert(meta == false or type(meta) == "table")
    return meta ~= false
end
function manager:version()
    return meta.version
end
function manager:currentversion()
    assert(manager:isinstalled(packagename))
    for _, line in ipairs(getrootfs().fs.etc.pkg.installed:split("\n")) do
        local parts = line:split(" ")
        local name = parts[1]
        if name == packagename then
            return tonumber(parts[2])
        end
    end
    error()
end
function manager:name()
    return packagename 
end
function manager:src()
    return src
end
function manager:bin()
    return getrootfs().fs.bin[packagename]
end
function manager:install()
    assert(not manager:isinstalled(packagename))
    local bc = lbc:compile(src, packagename)
    getrootfs().fs.bin[packagename] = bc
    local pkgdir = getrootfs().fs.etc.pkg
    pkgdir.installed = pkgdir.installed .. ("%s %.1f\n"):format(packagename, meta.version)
end
function manager:uninstall()
    getrootfs().fs.bin[packagename] = nil
    local pkgdir = getrootfs().fs.etc.pkg
    local found = false
    local lines = pkgdir.installed:split("\n")
    for i, line in ipairs(lines) do
        if line:find(packagename, nil, true) then
            table.remove(lines, i)
            found = true
            break
        end
    end
    pkgdir.installed = table.concat(lines, "\n")
    if found == false then
        error("couldn't find package")
    end
end
function manager:update()
    manager:uninstall()
    manager:install()
end
return manager]],
    unformat = [[
return function(str)
    local index = 1
    local result = ""
    while index <= #str do
        local char = str:sub(index, index)
        if char == "\\" then
            result = result .. str:sub(index + 1, index + 1)
            index = index + 2
        elseif char == "[" then
            local capture = str:match("%b[]", index)
            index = index + #capture
        else
            result = result .. char
            index = index + 1
        end
    end
    return result
end]],
    formatcolumns = [[
use("table")
use("math")
use("string")
use("unformat")
return function(grid)
    do
        local copy = table.create(#grid)
        for i = 1, #grid do
            copy[i] = table.create(#grid[i])
            for j = 1, #grid[i] do
                copy[i][j] = grid[i][j]
            end
        end
        grid = copy
    end
    for col = 1, #grid[1] do
		local longest = 0
		for row = 1, #grid do
			longest = math.max(longest, #unformat(grid[row][col]))
		end
		for row = 1, #grid do
			local padding = string.rep(" ", longest - #unformat(grid[row][col]))
			grid[row][col] = grid[row][col] .. padding .. " "
		end
	end
	for row = 1, #grid do
		grid[row] = table.concat(grid[row])
	end
    return table.concat(grid, "\n")
end]],
    terminal = require(game.ReplicatedStorage.Common.defaultos.terminal),
}
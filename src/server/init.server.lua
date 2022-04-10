local PKGURL = "https://api.github.com/repos/taikonaut001/roblox-unixlike-terminal/git/trees/a588bae638b8b830fbccb7c31f1bda0a231b8471?recursive=1"
local PKGSRCURL = "https://raw.githubusercontent.com/taikonaut001/roblox-unixlike-terminal/main/packages/%s/"

local remotesfolder = Instance.new("Folder")
remotesfolder.Name = "Remotes"
remotesfolder.Parent = game.ReplicatedStorage

local remotenames = {"pkglist", "pkggetmeta", "pkgget"}
for _, name in ipairs(remotenames) do
    local remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = remotesfolder
end

local function getpackagelist()
    local list = game.HttpService:GetAsync(PKGURL)
    list = game.HttpService:JSONDecode(list)
    local packages = {}
    for i, fileinfo in ipairs(list.tree) do
        packages[i] = fileinfo.path:sub(1, -5)
    end
    return packages
end

local function getsrc(packagename)
    return game.HttpService:GetAsync(PKGSRCURL:format(packagename) .. "bin.lua")
end

local packagelistcache = getpackagelist()
local packagelistcacheupdated = tick()

local function getmeta(packagename)
    if table.find(packagelistcache, packagename) == nil then return nil end
    local raw = game.HttpService:GetAsync(PKGSRCURL:format(packagename) .. "meta.json")
    return game.HttpService:JSONDecode(raw)
end

remotesfolder.pkglist.OnServerInvoke = function(player)
    if tick() - packagelistcacheupdated > 30 then
        packagelistcache = getpackagelist()
    end
    return packagelistcache
end

remotesfolder.pkggetmeta.OnServerInvoke = function(player, packagename)
    return getmeta(packagename)
end

remotesfolder.pkgget.OnServerInvoke = function(player, packagename)
    return getsrc(packagename)
end

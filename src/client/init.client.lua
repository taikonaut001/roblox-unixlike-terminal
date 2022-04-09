local lbc = require(game.ReplicatedStorage.Common.lbc)
local lbi = require(game.ReplicatedStorage.Common.lbi)
local keyboard = require(game.ReplicatedStorage.Common.keyboard)
local DiskDevice = require(game.ReplicatedStorage.Common.diskdevice)
local StorageDevice = require(game.ReplicatedStorage.Common.storagedevice)

local disks
do
	local disk1 = DiskDevice.new()
	local bootpart = StorageDevice.empty()
	bootpart.type = "boot"
    local bootprogram = require(game.ReplicatedStorage.Common.defaultos.boot)
	bootpart.program = lbc:compile(bootprogram, "boot")
	local rootpart = StorageDevice.empty()
    rootpart.type = "fs"
    rootpart.fs = {
		etc = {hostname = "host"},
		bin = {},
		tmp = {},
		root = {},
		home = {},
		--lib = {},
		--dev = {},
		--mnt = {},
	}
	-- initialize /bin
    local binraw = require(game.ReplicatedStorage.Common.defaultos.binraw)
    rootpart.fs.root.binraw = {}
    for name, file in pairs(binraw) do
        rootpart.fs.bin[name] = lbc:compile(file, name)
        rootpart.fs.root.binraw[name .. ".lua"] = file
    end
	disk1.parts[1] = bootpart
	disk1.parts[2] = rootpart
	local disk2 = DiskDevice.new()
	disks = {disk1, disk2}
end

local bootoptions = {}
for _, disk in ipairs(disks) do
	local part = disk.parts[1]
	if part.type == "boot" then
		bootoptions[#bootoptions + 1] = disk
		break
	end
end
local bootdevice = bootoptions[1]
assert(bootdevice ~= nil, "no bootable device found")

local namespaces = {
	math = {math = math},
	string = {string = string},
	table = {table = table},
	bit32 = {bit32 = bit32},
	keyboard = {keyboard = keyboard},
	instance = {
		game = game,
		Instance = Instance,
		require = require,
	},
	disks = {
		disks = disks,
		bootdevice = bootdevice,
	},
	lua = {
		pairs = pairs,
		ipairs = ipairs,
		pcall = pcall,
		tonumber = tonumber,
		tostring = tostring,
		rawget = rawget,
		rawset = rawset,
		getmetatable = getmetatable,
		setmetatable = setmetatable,
		select = select,
		--getfenv = getfenv,
		next = next,
		type = type,
	},
	luau = {
		tick = tick,
		task = task,
		wait = task.wait,
	},
	luauclass = {
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		UDim2 = UDim2,
		UDim = UDim,
		Color3 = Color3,
		Enum = Enum,
	},
	debug = {
		print = print,
		warn = warn,
		assert = assert,
		error = error,
	},
	luavm = {
		lbc = lbc,
		lbi = lbi,
	},
}
namespaces.namespaces = {namespaces = namespaces} -- this might be an issue

local function bcenv()
	local env = {}
	
	env.use = function(name)
		local namespace = namespaces[name] or error("namespace does not exist: " .. name)
		for k, v in pairs(namespace) do
			assert(env[k] == nil)
			env[k] = v
		end
	end
	
	return env
end

local bootprogram = bootdevice.parts[1].program
-- local bc = lbc:compile(bootprogram)
lbi:interpret(bootprogram, bcenv())

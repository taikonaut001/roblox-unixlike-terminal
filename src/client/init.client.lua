local lbc = require(game.ReplicatedStorage.Common.lbc)
local lbi = require(game.ReplicatedStorage.Common.lbi)
local keyboard = require(game.ReplicatedStorage.Common.keyboard)
local DiskDevice = require(game.ReplicatedStorage.Common.diskdevice)
local StorageDevice = require(game.ReplicatedStorage.Common.storagedevice)

local PlayerGui = game.Players.LocalPlayer.PlayerGui

task.wait(1)
local defaultgui = PlayerGui:GetChildren()

local disks
do
	local disk1 = DiskDevice.new(0)

	local bootpart = StorageDevice.empty()
	bootpart.name = disk1.name .. "1"
	bootpart.fs = {}
	bootpart.type = "boot"
    local bootprogram = require(game.ReplicatedStorage.Common.defaultos.boot)
	bootpart.fs.program = lbc:compile(bootprogram, "boot")

	local rootpart = StorageDevice.empty()
	rootpart.name = disk1.name .. "2"
    rootpart.type = "fs"
    rootpart.fs = {
		etc = {hostname = "host"},
		bin = {},
		tmp = {},
		root = {},
		home = {},
		lib = {},
		dev = {},
		mnt = {},
	}
	-- initialize /bin and /lib
    local binraw = require(game.ReplicatedStorage.Common.defaultos.binraw)
    rootpart.fs.root.binraw = {}
    for name, file in pairs(binraw) do
        rootpart.fs.bin[name] = lbc:compile(file, name)
        rootpart.fs.root.binraw[name .. ".lua"] = file
    end
	local libraw = require(game.ReplicatedStorage.Common.defaultos.libraw)
	rootpart.fs.root.libraw = {}
	for name, file in pairs(libraw) do
		rootpart.fs.lib[name] = lbc:compile(file, name)
        rootpart.fs.root.libraw[name .. ".lua"] = file
	end
	disk1.parts[1] = bootpart
	disk1.parts[2] = rootpart
	local disk2 = DiskDevice.new(1)
	disks = {disk1, disk2}
end
	
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

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local function boot()
	local bootmenu = Instance.new("ScreenGui")
	bootmenu.Name = "BootMenu"
	bootmenu.Parent = PlayerGui
	
	local background = Instance.new("Frame")
	background.Size = UDim2.new(100, 0, 100, 0)
	background.Position = UDim2.new(0.5, 0, 0.5, 0)
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.ZIndex = -10
	background.Parent = bootmenu
	
	local bootoptions = {}
	for _, disk in ipairs(disks) do
		if disk.parts[1] and disk.parts[1].type == "boot" then
			bootoptions[#bootoptions + 1] = disk
		end
	end
	if #bootoptions == 0 then
		local message = Instance.new("TextLabel")
		message.Size = UDim2.new(0, 200, 0, 25)
		message.TextSize = 16
		message.Text = "No bootable medium found"
		message.TextColor3 = Color3.fromRGB(255, 255, 255)
		message.Position = UDim2.new(0, 10, 0, 10)
		message.BackgroundTransparency = 1
		message.Parent = bootmenu
		return
	end
	
	local buttonheight = 25
	local bootdevice
	for i, option in ipairs(bootoptions) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 200, 0, buttonheight)
		button.Position = UDim2.new(0, 10, 0, 10 + buttonheight * (i - 1))
		button.Text = option.name
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.BackgroundTransparency = 1
		button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		button.BorderSizePixel = 0
		button.Parent = bootmenu
	
		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 0
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
		end)
		button.Activated:Connect(function()
			bootdevice = option
		end)
	end
	while bootdevice == nil do
		task.wait()
	end
	bootmenu:Destroy()

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

	local running = true

	local function endprocess()
		running = false
		for _, v in ipairs(PlayerGui:GetChildren()) do
			if not table.find(defaultgui, v) then
				v:Destroy()
			end
		end
		boot()
	end

	namespaces.disks.bootdevice = bootdevice
	namespaces.reboot = {}
	namespaces.reboot.reboot = function()
		endprocess()
	end

	local bootprogram = bootdevice.parts[1].fs.program
	local success, result = pcall(function()
		lbi:interpret(bootprogram, bcenv(), function() return running end)
	end)
	if not success then
		coroutine.wrap(function()
			error(result)
		end)()
		endprocess()
	else
		endprocess()
	end
end

boot()

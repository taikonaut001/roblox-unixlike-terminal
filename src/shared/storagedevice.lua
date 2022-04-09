local namecounter = 0

local StorageDevice = {}
StorageDevice.__index = StorageDevice

function StorageDevice.empty()
	local self = setmetatable({}, StorageDevice)
	self.uuid = game.HttpService:GenerateGUID(false)
	
	return self
end

function StorageDevice.new()
	local self = StorageDevice.empty()
	self.type = "stfs"
	self.fs = {
		etc = {
			hostname = "host",
		},
		bin = {},
		tmp = {},
		root = {},
		home = {},
		--lib = {},
		--dev = {},
		--mnt = {}, -- TODO
	}
	
	return self
end

function StorageDevice:get(directory)
	assert(directory:sub(1, 1) == "/")
	directory = directory:sub(2)
	local slashend = #directory > 1 and directory:sub(-1, -1) == "/"
	if slashend then
		directory = directory:sub(1, -2)
	end
	if #directory == 0 then return self.fs end
	local current = self.fs
	for _, name in ipairs(directory:split("/")) do
		assert(current ~= nil, "No such file or directory")
		current = current[name]
	end
	if slashend then
		assert(typeof(current) == "table")
	end
	return current
end

-- unreachable: false
-- reachable but not existing: nil
-- exists: table/string
function StorageDevice:pathto(path)
	local success, result = pcall(function()
		return self:get(path)
	end)
	return success and result
end

function StorageDevice:size(dir)
	if self.type == "boot" then return #self.program end
	dir = dir or self.fs or self.program
	local size = 0
	for k, v in pairs(dir) do
		size = size + #k
		if typeof(v) == "table" then
			size = size + self:size(v)
		else
			assert(typeof(v) == "string")
			size = size + #v
		end
	end
	return size
end

-- TODO
function StorageDevice.fromSerial()

end

function StorageDevice:serialize()

end

return StorageDevice

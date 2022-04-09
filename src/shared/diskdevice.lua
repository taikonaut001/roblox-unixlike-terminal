local namecounter = 0

local DiskDevice = {}
DiskDevice.__index = DiskDevice

function DiskDevice.new()
	local self = setmetatable({}, DiskDevice)
	self.parts = {}
	self.name = "sd" .. string.char(97 + namecounter)
	namecounter = namecounter + 1
	assert(namecounter <= 25)
	
	return self
end

function DiskDevice:size()
	local size = 0
	for _, part in ipairs(self.parts) do
		size = size + part:size()
	end
	return size
end

-- TODO
function DiskDevice.fromSerial()

end

function DiskDevice:serialize()

end

return DiskDevice

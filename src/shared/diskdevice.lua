local DiskDevice = {}
DiskDevice.__index = DiskDevice

function DiskDevice.new(n)
	local self = setmetatable({}, DiskDevice)
	self.parts = {}
	self.name = "sd" .. string.char(97 + n)
	self.uuid = game.HttpService:GenerateGUID(false)
	
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

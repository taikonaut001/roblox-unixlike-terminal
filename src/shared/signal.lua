local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self.callbacks = {}
	
	return self
end

function Signal:invoke(...)
	for _, callback in pairs(self.callbacks) do
		callback(...)
	end
end

function Signal:connect(callback)
	local id = game.HttpService:GenerateGUID()
	self.callbacks[id] = callback
	
	return {
		disconnect = function()
			self.callbacks[id] = nil
		end,
	}
end

function Signal:wait()
	local values = {}
	local fired = false
	local connection = self:connect(function(...)
		values = {...}
		fired = true
	end)
	while fired == false do
		task.wait()
	end
	connection:disconnect()
	return unpack(values)
end

return Signal

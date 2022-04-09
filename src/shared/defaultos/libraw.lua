return {
    formatcolumns = [[
use("table")
use("math")
use("string")
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
			longest = math.max(longest, #grid[row][col])
		end
		for row = 1, #grid do
			local padding = string.rep(" ", longest - #grid[row][col])
			grid[row][col] = grid[row][col] .. padding .. " "
		end
	end
	for row = 1, #grid do
		grid[row] = table.concat(grid[row])
	end
    return table.concat(grid, "\n")
end]],
    getdevicefromuuid = [[
use("disk")
return function(uuid)
    for _, disk in ipairs(disks) do
        if disk.uuid == uuid then return disk end
        for _, part in ipairs(parts) do
            if part.uuid == uuid then return part end
        end
    end
end]],
--     mountinfodecode = [[
-- use("lua")
-- use("table")
-- use("disks")
-- import("getdevicefromuuid")
-- return function(mounts)
--     local decode = {}
--     for _, line in ipairs(mounts:split("\n")) do
--         local a, b = table.unpack(line:split("    "))
--         decode[getdevicefromuuid(a)] = b
--     end
--     return decode
-- end]],
--     mountinfoencode = [[
-- return function()
-- end]]
}
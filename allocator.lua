local storage = minetest.get_mod_storage()

local function get_or_default(key, default)
	if storage:contains(key) then
		return storage:get_int(key)
	else
		storage:set_int(key, default)
		return default
	end
end

local y_level = get_or_default("y_level", -1800 * 16)
local x_start = get_or_default("x_start", -1800 * 16)
local x_end = get_or_default("x_end", 1799 * 16)
local z_start = get_or_default("z_start", -1800 * 16)
local z_end = get_or_default("z_end", 1799 * 16)
local x_next = get_or_default("x_next", x_start)
local z_next = get_or_default("z_next", z_start)

function area_containers.allocate_inside_block()
	if z_next <= z_end then
		local allocation = vector.new(x_next, y_level, z_next)
		x_next = x_next + 16
		if x_next > x_end then
			x_next = x_start
			z_next = z_next + 16
		end
		storage:set_int("x_next", x_next)
		storage:set_int("z_next", z_next)
		return allocation
	else
		return nil
	end
end

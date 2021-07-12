local function set_up_exit(pos, container_pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("area_containers:container_pos",
		minetest.pos_to_string(container_pos))
	meta:set_string("infotext", "Exit")
end

local function construct_inside(container_pos, inside_pos)
	local min_pos = inside_pos
	local max_pos = vector.offset(min_pos, 15, 15, 15)
	local exit_pos = vector.offset(min_pos, 0, 2, 1)

	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{
		MinEdge = min_edge,
		MaxEdge = max_edge,
	}

	local data = vm:get_data()
	local c_air = minetest.get_content_id("air")
	local c_wall = minetest.get_content_id("area_containers:wall")
	local c_exit = minetest.get_content_id("area_containers:exit")
	for z = min_pos.z, max_pos.z do
		for y = min_pos.y, max_pos.y do
			for x = min_pos.x, max_pos.x do
				local content_id = c_air
				if x == min_pos.x or x == max_pos.x or
				   y == min_pos.y or y == max_pos.y or
				   z == min_pos.z or z == max_pos.z then
					content_id = c_wall
				end
				data[area:index(x, y, z)] = content_id
			end
		end
	end
	data[area:index(exit_pos.x, exit_pos.y, exit_pos.z)] = c_exit
	vm:set_data(data)
	vm:write_to_map(true)

	set_up_exit(exit_pos, container_pos)
end

area_containers.container = {}

function area_containers.container.on_construct(pos)
	local meta = minetest.get_meta(pos)
	local inside_pos = area_containers.allocate_inside_block()
	if inside_pos then
		construct_inside(pos, inside_pos)
		meta:set_string("area_containers:inside_pos",
			minetest.pos_to_string(inside_pos))
	end
	meta:set_string("infotext", "Area container")
end

function area_containers.container.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local meta = minetest.get_meta(pos)
		local inside_pos = minetest.string_to_pos(
			meta:get_string("area_containers:inside_pos"))
		if inside_pos then
			local dest = vector.offset(inside_pos, 1, 1, 1)
			clicker:set_pos(dest)
		end
	end
end

function area_containers.container.can_dig(pos)
	local meta = minetest.get_meta(pos)
	local inside_pos = minetest.string_to_pos(
		meta:get_string("area_containers:inside_pos"))
	if not inside_pos then return true end
	-- These represent the area of the inner chamber (inclusive):
	local min_pos = vector.offset(inside_pos, 1, 1, 1)
	local max_pos = vector.offset(inside_pos, 14, 14, 14)

	-- Detect nodes left inside.
	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{
		MinEdge = min_edge,
		MaxEdge = max_edge,
	}
	local data = vm:get_data()
	local c_air = minetest.get_content_id("air")
	for z = min_pos.z, max_pos.z do
		for y = min_pos.y, max_pos.y do
			for x = min_pos.x, max_pos.x do
				if data[area:index(x, y, z)] ~= c_air then
					return false
				end
			end
		end
	end

	-- Detect players inside.
	-- (Detecting all objects would probably cause problems.)
	local objects_inside = minetest.get_objects_in_area(min_pos, max_pos)
	for _, object in ipairs(objects_inside) do
		if minetest.is_player(object) then return false end
	end

	return true
end

area_containers.exit = {}

function area_containers.exit.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local meta = minetest.get_meta(pos)
		local container_pos = minetest.string_to_pos(
			meta:get_string("area_containers:container_pos"))
		if container_pos then
			local dest = vector.offset(container_pos, 0, 1, 0)
			clicker:set_pos(dest)
		end
	end
end

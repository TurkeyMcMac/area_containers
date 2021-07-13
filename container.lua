local exit_offset = vector.new(0, 2, 1)
local digiline_offset = vector.new(3, 0, 3)
local pipe_offsets = {
	px = vector.new(0, 3, 4),
	nx = vector.new(0, 3, 6),
	pz = vector.new(0, 3, 8),
	nz = vector.new(0, 3, 10),
	py = vector.new(0, 3, 12),
	ny = vector.new(0, 3, 14),
}
local inside_offsets = { exit_offset, digiline_offset }
for _, offset in pairs(pipe_offsets) do
	inside_offsets[#inside_offsets + 1] = offset
end

local function set_up_exit(inside_pos)
	local pos = vector.add(inside_pos, exit_offset)
	minetest.set_node(pos, {
		name = "area_containers:exit",
		param1 = 0, param2 = 0,
	})
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", "Exit")
end

local function set_up_digiline(inside_pos)
	local pos = vector.add(inside_pos, digiline_offset)
	minetest.set_node(pos, {
		name = "area_containers:digiline",
		param1 = 0, param2 = 0,
	})
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", "Digiline I/O")
end

local function set_up_pipes(inside_pos)
	local labels = {
		px = "+X pipe I/O", nx = "-X pipe I/O",
		pz = "+Z pipe I/O", nz = "-Z pipe I/O",
		py = "+Y pipe I/O", ny = "-Y pipe I/O",
	}
	local param2s = { -- param2 encodes pipe direction
		px = minetest.dir_to_facedir(vector.new(1, 0, 0), true),
		nx = minetest.dir_to_facedir(vector.new(-1, 0, 0), true),
		pz = minetest.dir_to_facedir(vector.new(0, 0, 1), true),
		nz = minetest.dir_to_facedir(vector.new(0, 0, -1), true),
		py = minetest.dir_to_facedir(vector.new(0, 1, 0), true),
		ny = minetest.dir_to_facedir(vector.new(0, -1, 0), true),
	}
	for id, offset in ipairs(pipe_offsets) do
		local pos = vector.add(inside_pos, offset)
		minetest.set_node(pos, {
			name = "area_containers:pipe",
			param1 = 0, param2 = param2s[id],
		})
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", labels[id])
	end
end

local function link_inside_special_nodes(inside_pos, container_pos)
	local container_pos_string = minetest.pos_to_string(container_pos)
	for _, offset in ipairs(inside_offsets) do
		local pos = vector.add(inside_pos, offset)
		local meta = minetest.get_meta(pos)
		meta:set_string("area_containers:container_pos",
			container_pos_string)
	end
end

local function construct_inside(container_pos, inside_pos)
	local min_pos = inside_pos
	local max_pos = vector.offset(min_pos, 15, 15, 15)

	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{
		MinEdge = min_edge,
		MaxEdge = max_edge,
	}

	local data = vm:get_data()
	local c_air = minetest.get_content_id("air")
	local c_wall = minetest.get_content_id("area_containers:wall")
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
	vm:set_data(data)
	vm:write_to_map(true)

	set_up_exit(inside_pos)
	set_up_digiline(inside_pos)
	set_up_pipes(inside_pos)
	link_inside_special_nodes(inside_pos, container_pos)
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

function area_containers.container_is_empty(pos, meta)
	meta = meta or minetest.get_meta(pos)
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
	local objects_inside = minetest.get_objects_in_area(
		vector.subtract(min_pos, 1), vector.add(max_pos, 1))
	for _, object in ipairs(objects_inside) do
		if minetest.is_player(object) then return false end
	end

	return true
end

function area_containers.container.can_dig(pos)
	return area_containers.container_is_empty(pos)
end

function area_containers.container.on_blast()
	-- The simplest way to preserve the inside is just to do nothing.
end

area_containers.container.digiline = {
	effector = {},
	receptor = {},
}

function area_containers.container.digiline.effector.action(pos, node,
		channel, msg)
	local meta = minetest.get_meta(pos)
	local inside_pos = minetest.string_to_pos(
		meta:get_string("area_containers:inside_pos"))
	if not inside_pos then return end
	local digiline_pos = vector.add(inside_pos, digiline_offset)
	digiline:receptor_send(digiline_pos, digiline.rules.default,
		channel, msg)
end

area_containers.container.tube = {
	connect_sides = {
		left = 1, right = 1,
		back = 1, front = 1,
		bottom = 1, top = 1,
	},
}

function area_containers.container.tube.can_insert(pos)
	local meta = minetest.get_meta(pos)
	local inside_pos = minetest.string_to_pos(
		meta:get_string("area_containers:inside_pos"))
	return inside_pos ~= nil
end

function area_containers.container.tube.insert_object(pos, node, stack, dir,
		owner)
	local meta = minetest.get_meta(pos)
	local inside_pos = minetest.string_to_pos(
		meta:get_string("area_containers:inside_pos"))
	if not inside_pos then return stack end
	local pipe_id = "nx"
	if dir.x < 0 then
		pipe_id = "px"
	elseif dir.z > 0 then
		pipe_id = "nz"
	elseif dir.z < 0 then
		pipe_id = "pz"
	elseif dir.y > 0 then
		pipe_id = "ny"
	elseif dir.y < 0 then
		pipe_id = "py"
	end
	local pipe_pos = vector.add(inside_pos, pipe_offsets[pipe_id])
	local out_dir = vector.new(1, 0, 0)
	-- The 1.4 is copied from pipeworks' filter-injector code:
	local out_pos = vector.add(pipe_pos, vector.multiply(out_dir, 1.4))
	local start_pos = pipe_pos
	local out_speed = vector.length(dir)
	if out_speed == 0 then out_speed = 0.1 end
	local out_vel = vector.multiply(out_dir, out_speed)
	pipeworks.tube_inject_item(out_pos, start_pos, out_vel, stack, owner)
	return ItemStack() -- All was inserted.
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

area_containers.digiline = {
	digiline = {
		effector = {},
		receptor = {},
	}
}

function area_containers.digiline.digiline.effector.action(pos, node,
		channel, msg)
	local meta = minetest.get_meta(pos)
	local container_pos = minetest.string_to_pos(
		meta:get_string("area_containers:container_pos"))
	if not container_pos then return end
	digiline:receptor_send(container_pos, digiline.rules.default,
		channel, msg)
end

area_containers.pipe = {
	tube = {
		connect_sides = {
			left = 1, right = 1,
			back = 1, front = 1,
			bottom = 1, top = 1,
		},
	},
}

function area_containers.pipe.tube.can_insert(pos)
	local meta = minetest.get_meta(pos)
	local container_pos = minetest.string_to_pos(
		meta:get_string("area_containers:container_pos"))
	return container_pos ~= nil
end

function area_containers.pipe.tube.insert_object(pos, node, stack, dir, owner)
	local meta = minetest.get_meta(pos)
	local container_pos = minetest.string_to_pos(
		meta:get_string("area_containers:container_pos"))
	if not container_pos then return stack end
	local out_dir = minetest.facedir_to_dir(node.param2)
	-- The 1.4 is copied from pipeworks' filter-injector code:
	local out_pos = vector.add(container_pos, vector.multiply(out_dir, 1.4))
	local start_pos = container_pos
	local out_speed = vector.length(dir)
	if out_speed == 0 then out_speed = 0.1 end
	local out_vel = vector.multiply(out_dir, out_speed)
	pipeworks.tube_inject_item(out_pos, start_pos, out_vel, stack, owner)
	return ItemStack() -- All was inserted.
end

local function get_node_force(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then return node end
	-- Try to load the block:
	local vm = minetest.get_voxel_manip()
	vm:read_from_map(pos, pos)
	node = minetest.get_node_or_nil(pos)
	assert(node)
	return node
end

local exit_offset = vector.new(0, 2, 1)
local digiline_offset = vector.new(3, 0, 3)

local pipe_labels = {
	px = "+X pipe I/O", nx = "-X pipe I/O",
	pz = "+Z pipe I/O", nz = "-Z pipe I/O",
	py = "+Y pipe I/O", ny = "-Y pipe I/O",
}
local pipe_offsets = {
	px = vector.new(0, 3, 4), nx = vector.new(0, 3, 6),
	pz = vector.new(0, 3, 8), nz = vector.new(0, 3, 10),
	py = vector.new(0, 3, 12), ny = vector.new(0, 3, 14),
}
local pipe_dirs = {
	px = vector.new(1, 0, 0), nx = vector.new(-1, 0, 0),
	pz = vector.new(0, 0, 1), nz = vector.new(0, 0, -1),
	py = vector.new(0, 1, 0), ny = vector.new(0, -1, 0),
}
local pipe_ordered_ids = {"px", "nx", "pz", "nz", "py", "ny"}

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
	local param2_ids = table.key_value_swap(pipe_ordered_ids)
	for id, offset in pairs(pipe_offsets) do
		local pos = vector.add(inside_pos, offset)
		local param2 = param2_ids[id] * 32 +
			minetest.dir_to_facedir(pipe_dirs[id], true)
		minetest.set_node(pos, {
			name = "area_containers:pipe",
			param1 = 0, param2 = param2,
		})
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", pipe_labels[id])
	end
end

local function construct_inside(container_pos, param1, param2)
	local inside_pos = area_containers.get_related_inside(param1, param2)
	local min_pos = inside_pos
	local max_pos = vector.add(min_pos, 15)

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

	area_containers.set_related_container(param1, param2, container_pos)
	set_up_exit(inside_pos)
	set_up_digiline(inside_pos)
	set_up_pipes(inside_pos)
end

local function get_pipe_container_pos(pos, node)
	local offset_id = pipe_ordered_ids[math.floor(node.param2 / 32)]
	if not offset_id then return nil end
	local inside_pos = vector.subtract(pos, pipe_offsets[offset_id])
	local inside_meta = minetest.get_meta(inside_pos)
	return minetest.string_to_pos(
		inside_meta:get_string("area_containers:container_pos"))
end

area_containers.container = {}

function area_containers.container.on_construct(pos)
	local node = get_node_force(pos)
	local param1 = node.param1
	local param2 = node.param2
	if not area_containers.params_are_null(param1, param2) then
		-- The node probably moved.
		if area_containers.reclaim_relation(param1, param2) then
			area_containers.set_related_container(param1, param2,
				pos)
			return
		end
	end
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", "Area container")
	param1, param2 = area_containers.alloc_relation()
	if param1 then
		construct_inside(pos, param1, param2)
		minetest.swap_node(pos, {
			name = "area_containers:container",
			param1 = param1, param2 = param2,
		})
	end
end

function area_containers.container.on_destruct(pos)
	-- Only free properly allocated containers:
	local node = get_node_force(pos)
	if not area_containers.params_are_null(node.param1, node.param2) then
		area_containers.free_relation(node.param1, node.param2)
	end
end

function area_containers.container.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local inside_pos = area_containers.get_related_inside(
			node.param1, node.param2)
		local inside_meta = minetest.get_meta(inside_pos)
		-- Make sure the player will be able to get back:
		local container_pos = minetest.string_to_pos(
			inside_meta:get_string("area_containers:container_pos"))
		if container_pos and vector.equals(pos, container_pos) then
			local dest = vector.add(inside_pos, 1)
			clicker:set_pos(dest)
		end
	end
end

function area_containers.container_is_empty(pos, node)
	node = node or get_node_force(pos)
	if node.name ~= "area_containers:container" then
		return true
	end
	local inside_pos = area_containers.get_related_inside(
		node.param1, node.param2)
	-- These represent the area of the inner chamber (inclusive):
	local min_pos = vector.add(inside_pos, 1)
	local max_pos = vector.add(inside_pos, 14)

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
	local inside_pos = area_containers.get_related_inside(
		node.param1, node.param2)
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

function area_containers.container.tube.can_insert()
	return true
end

function area_containers.container.tube.insert_object(pos, node, stack, dir,
		owner)
	local inside_pos = area_containers.get_related_inside(
		node.param1, node.param2)
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
	local out_speed = math.max(vector.length(dir), 0.1)
	local out_vel = vector.new(out_speed, 0, 0)
	pipeworks.tube_inject_item(pipe_pos, pipe_pos, out_vel, stack, owner)
	return ItemStack() -- All inserted.
end

area_containers.exit = {}

function area_containers.exit.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local inside_pos = vector.subtract(pos, exit_offset)
		local inside_meta = minetest.get_meta(inside_pos)
		local container_pos = minetest.string_to_pos(
			inside_meta:get_string("area_containers:container_pos"))
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
	local inside_pos = vector.subtract(pos, digiline_offset)
	local inside_meta = minetest.get_meta(inside_pos)
	local container_pos = minetest.string_to_pos(
		inside_meta:get_string("area_containers:container_pos"))
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

function area_containers.pipe.tube.can_insert(pos, node)
	return get_pipe_container_pos(pos, node) ~= nil
end

function area_containers.pipe.tube.insert_object(pos, node, stack, dir, owner)
	local container_pos = get_pipe_container_pos(pos, node)
	if not container_pos then return stack end
	local out_dir = minetest.facedir_to_dir(node.param2 % 32)
	local out_speed = math.max(vector.length(dir), 0.1)
	local out_vel = vector.multiply(out_dir, out_speed)
	pipeworks.tube_inject_item(container_pos, container_pos, out_vel, stack,
		owner)
	return ItemStack() -- All inserted.
end

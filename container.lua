--[[
    Copyright (C) 2021  Jude Melton-Houghton

    This file is part of area_containers. It implements node functionality.

    area_containers is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    area_containers is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with area_containers. If not, see <https://www.gnu.org/licenses/>.
]]

--[[
   OVERVIEW

   A container node is associated with an inside chamber through its param1 and
   param2. The active nodes in the chamber have the same params to map back to
   the container. This relation is managed by relation.lua.

   The container lets players teleport into its inside chamber. They can leave
   similarly with the inside exit node.

   Port nodes inside the chamber correspond to faces of the container. Pipeworks
   tubes can pass items through the ports. A mesecons signal can conduct between
   the horizontal container faces and the ports.

   Digilines messages can pass unaltered between the container and the digiline
   node inside.

   The container cannot be broken until it is empty of nodes and objects. While
   the inside's block is active, a special object counter node continuously
   tallies the objects so that the number can be checked when one attempts to
   break the container.

   This file sets various things in the mod namespace to communicate with
   nodes.lua. For example, area_containers.<node-name> will be merged into the
   definition of <node-name>, where <node-name> is e.g. "container".
]]

-- Name the private namespace:
local area_containers = ...

-- Gets a node. If get_node fails because the position is not loaded, the
-- position is loaded and get_node is again tried. If this fails, a table is
-- returned with name = "ignore".
local function get_node_maybe_load(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then return node end
	-- Try to load the block:
	local vm = minetest.get_voxel_manip()
	vm:read_from_map(pos, pos)
	return minetest.get_node(pos) -- Might be "ignore"
end

-- Updates the stored count of non-player objects associated with the inside.
-- If the block is not active, the objects can't be counted, and nil is
-- returned. Otherwise, the number of non-player objects is returned.
local function update_non_player_object_count(inside_pos)
	if minetest.compare_block_status(inside_pos, "active") then
		local object_count = 0
		local objects_inside = minetest.get_objects_in_area(
			inside_pos, vector.add(inside_pos, 15))
		for _, object in ipairs(objects_inside) do
			if not object:is_player() then
				object_count = object_count + 1
			end
		end
		local inside_meta = minetest.get_meta(inside_pos)
		inside_meta:set_int("area_containers:object_count",
			object_count)
		return object_count
	end
	return nil
end

-- Gets the stored count of non-player objects associated with the inside.
local function get_non_player_object_count(inside_pos)
	local inside_meta = minetest.get_meta(inside_pos)
	return inside_meta:get_int("area_containers:object_count")
end

-- The longest common prefix of all container node names.
local container_name_prefix = "area_containers:container_"

-- The offsets of the exit and digiline nodes from the inside position
-- (the chamber wall position with the lowest x, y, and z.)
local exit_offset = vector.new(0, 2, 1)
local digiline_offset = vector.new(3, 0, 3)

-- A mapping from port IDs to offsets from the inside position.
local port_offsets = {
	nx = vector.new(0, 2, 4), pz = vector.new(0, 2, 6),
	px = vector.new(0, 2, 8), nz = vector.new(0, 2, 10),
	py = vector.new(0, 2, 12), ny = vector.new(0, 2, 14),
}
-- A mapping from port IDs to unit vectors encoding the directions the
-- corresponding outside ports face.
local port_dirs = {
	nx = vector.new(-1, 0, 0), pz = vector.new(0, 0, 1),
	px = vector.new(1, 0, 0), nz = vector.new(0, 0, -1),
	py = vector.new(0, 1, 0), ny = vector.new(0, -1, 0),
}
-- The list of horizontal port IDs in the order they appear inside,
-- left to right.
local port_ids_horiz = {"nx", "pz", "px", "nz"}

-- The longest common prefix of all port node names.
local port_name_prefix = "area_containers:port_"

-- Maps a port node name to the corresponding port ID.
local function get_port_id_from_name(node_name)
	return string.sub(node_name,
		#port_name_prefix + 1, #port_name_prefix + 2)
end

-- Sets up the non-player object counter node at inside_pos. The params encode
-- the relation.
local function set_up_object_counter(param1, param2, inside_pos)
	-- Swap the node to keep the relation metadata:
	minetest.swap_node(inside_pos, {
		name = "area_containers:object_counter",
		param1 = param1, param2 = param2,
	})
	-- Reset the count, just in case:
	local meta = minetest.get_meta(inside_pos)
	meta:set_int("area_containers:object_count", 0)
	-- The node checks for objects periodically when active:
	local timer = minetest.get_node_timer(inside_pos)
	timer:start(1)
end

-- Sets up the exit node near inside_pos. The params encode the relation.
local function set_up_exit(param1, param2, inside_pos)
	local pos = vector.add(inside_pos, exit_offset)
	minetest.set_node(pos, {
		name = "area_containers:exit",
		param1 = param1, param2 = param2,
	})
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", "Exit")
end

-- Sets up the digiline node near inside_pos. The params encode the relation.
local function set_up_digiline(param1, param2, inside_pos)
	local pos = vector.add(inside_pos, digiline_offset)
	minetest.set_node(pos, {
		name = "area_containers:digiline",
		param1 = param1, param2 = param2,
	})
end

-- Sets up the port nodes near inside_pos. The params encode the relation.
local function set_up_ports(param1, param2, inside_pos)
	for id, offset in pairs(port_offsets) do
		local pos = vector.add(inside_pos, offset)
		minetest.set_node(pos, {
			name = port_name_prefix .. id .. "_off",
			param1 = param1, param2 = param2,
		})
	end
end

-- Creats a chamber with all the necessary nodes related to container_pos
-- through param1 and param2.
local function construct_inside(container_pos, param1, param2)
	local inside_pos = area_containers.get_related_inside(param1, param2)
	-- The min and max provide the guidelines for the walls:
	local min_pos = inside_pos
	local max_pos = vector.add(min_pos, 15)

	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{
		MinEdge = min_edge,
		MaxEdge = max_edge,
	}

	-- Make the walls:
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

	-- Relate the container position:
	area_containers.set_related_container(param1, param2, container_pos)
	-- Set up the special nodes:
	set_up_object_counter(param1, param2, inside_pos)
	set_up_exit(param1, param2, inside_pos)
	set_up_digiline(param1, param2, inside_pos)
	set_up_ports(param1, param2, inside_pos)
end

area_containers.container = {}

-- The 16 container node names counting up from off to on in binary. The bits
-- from most to least significant are: +X, -X, +Z, -Z.
area_containers.all_container_states = {}
local all_container_variants = {
	"off", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
	"1000", "1001", "1010", "1011", "1100", "1101", "1110", "on",
}
for i, variant in ipairs(all_container_variants) do
	area_containers.all_container_states[i] =
		container_name_prefix .. variant
end

-- Relates an inside to the container and sets up the inside.
function area_containers.container.on_construct(pos)
	local node = get_node_maybe_load(pos)
	local param1 = node.param1
	local param2 = node.param2
	if param1 ~= 0 or param2 ~= 0 then
		-- If the relation is set, the container was probably moved by
		-- a piston or something.
		if area_containers.reclaim_relation(param1, param2) then
			area_containers.set_related_container(param1, param2,
				pos)
			return
		else
			minetest.log("error", "Could not reclaim the inside " ..
				"of the area container now located at " ..
				minetest.pos_to_string(pos) .. " with " ..
				"param1 = " .. param1 .. " and param2 = " ..
				param2 .. "; allocating a new inside instead")
		end
	end
	param1, param2 = area_containers.alloc_relation()
	local meta = minetest.get_meta(pos)
	if param1 then
		meta:set_string("infotext", "Area container")
		construct_inside(pos, param1, param2)
		minetest.swap_node(pos, {
			name = node.name,
			param1 = param1, param2 = param2,
		})
	else
		minetest.log("error", "Could not allocate an inside when " ..
			"constructing an area container at " ..
			minetest.pos_to_string(pos))
		meta:set_string("infotext", "Broken area container")
		minetest.swap_node(pos, {
			name = node.name,
			param1 = 0, param2 = 0,
		})
	end
end

-- Frees the inside related to the container.
function area_containers.container.on_destruct(pos)
	-- Only free properly allocated containers (with relation set):
	local node = get_node_maybe_load(pos)
	if node.param1 ~= 0 or node.param2 ~= 0 then
		area_containers.free_relation(node.param1, node.param2)
	end
end

-- Teleports the player into the container.
function area_containers.container.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local inside_pos = area_containers.get_related_inside(
			node.param1, node.param2)
		local self_pos = area_containers.get_related_container(
			node.param1, node.param2)
		-- Make sure the player will be able to get back:
		if self_pos and vector.equals(pos, self_pos) then
			local dest = vector.add(inside_pos, 1)
			clicker:set_pos(dest)
		end
	end
end

-- Returns whether there are any nodes or objects in the container.
-- The object count might not be 100% accurate if the container is unloaded.
function area_containers.container_is_empty(pos, node)
	node = node or get_node_maybe_load(pos)
	local name_prefix = string.sub(node.name, 1, #container_name_prefix)
	if name_prefix ~= container_name_prefix then return true end
	-- Invalid containers are empty:
	if node.param1 == 0 and node.param2 == 0 then return true end
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

	-- Detect objects inside.
	local objects_inside = minetest.get_objects_in_area(
		vector.subtract(min_pos, 1), vector.add(max_pos, 1))
	if #objects_inside > 0 then return false end
	-- Detect non-player objects in unloaded inside chambers:
	if get_non_player_object_count(inside_pos) > 0 then return false end

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

-- Forwards messages to the inside.
function area_containers.container.digiline.effector.action(pos, node,
		channel, msg)
	local inside_pos = area_containers.get_related_inside(
		node.param1, node.param2)
	local digiline_pos = vector.add(inside_pos, digiline_offset)
	digiline:receptor_send(digiline_pos, digiline.rules.default,
		channel, msg)
end

area_containers.container.groups = {
	tubedevice = 1,
	tubedevice_receiver = 1,
}

area_containers.container.tube = {
	connect_sides = {
		left = 1, right = 1,
		back = 1, front = 1,
		bottom = 1, top = 1,
	},
}

function area_containers.container.tube.can_insert(pos, node)
	return node.param1 ~= 0 or node.param2 ~= 0
end

function area_containers.container.tube.insert_object(pos, node, stack, dir,
		owner)
	local inside_pos = area_containers.get_related_inside(
		node.param1, node.param2)
	-- The incoming direction is opposite to the direction the port faces:
	local port_id = "nx"
	if dir.x < 0 then
		port_id = "px"
	elseif dir.z > 0 then
		port_id = "nz"
	elseif dir.z < 0 then
		port_id = "pz"
	elseif dir.y > 0 then
		port_id = "ny"
	elseif dir.y < 0 then
		port_id = "py"
	end
	local port_pos = vector.add(inside_pos, port_offsets[port_id])
	local out_speed = math.max(vector.length(dir), 0.1)
	local out_vel = vector.new(out_speed, 0, 0)
	pipeworks.tube_inject_item(port_pos, port_pos, out_vel, stack, owner)
	return ItemStack() -- All inserted.
end

if minetest.global_exists("pipeworks") then
	-- For updating tube connections.
	area_containers.container.after_place_node = pipeworks.after_place
	area_containers.container.after_dig_node = pipeworks.after_dig
end

-- A container is a conductor to its insides. The position of its insides can
-- be determined from param1 and param2.
area_containers.container.mesecons = {conductor = {
	states = area_containers.all_container_states,
}}
local function container_rules_add_port(rules, port_id, self_pos, inside_pos)
	local port_pos = vector.add(inside_pos, port_offsets[port_id])
	local offset_to_port = vector.subtract(port_pos, self_pos)
	rules[#rules + 1] = offset_to_port
end
function area_containers.container.mesecons.conductor.rules(node)
	local rules = {
		{
			{x = 1, y = 1, z = 0},
			{x = 1, y = 0, z = 0},
			{x = 1, y = -1, z = 0},
		},
		{
			{x = -1, y = 1, z = 0},
			{x = -1, y = 0, z = 0},
			{x = -1, y = -1, z = 0},
		},
		{
			{x = 0, y = 1, z = 1},
			{x = 0, y = 0, z = 1},
			{x = 0, y = -1, z = 1},
		},
		{
			{x = 0, y = 1, z = -1},
			{x = 0, y = 0, z = -1},
			{x = 0, y = -1, z = -1},
		},
	}
	local self_pos = area_containers.get_related_container(
		node.param1, node.param2)
	if self_pos then
		local inside_pos = area_containers.get_related_inside(
			node.param1, node.param2)
		container_rules_add_port(rules[1], "px", self_pos, inside_pos)
		container_rules_add_port(rules[2], "nx", self_pos, inside_pos)
		container_rules_add_port(rules[3], "pz", self_pos, inside_pos)
		container_rules_add_port(rules[4], "nz", self_pos, inside_pos)
	end
	return rules
end

area_containers.exit = {}

-- Teleports the player out of the container.
function area_containers.exit.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local container_pos = area_containers.get_related_container(
			node.param1, node.param2)
		if container_pos then
			local dest = vector.offset(container_pos, 0, 1, 0)
			clicker:set_pos(dest)
		end

		-- Update the count before the block is deactivated:
		local inside_pos = area_containers.get_related_inside(
			node.param1, node.param2)
		update_non_player_object_count(inside_pos)
	end
end

area_containers.digiline = {
	digiline = {
		effector = {},
		receptor = {},
	}
}

-- Forwards digiline messages to the container.
function area_containers.digiline.digiline.effector.action(pos, node,
		channel, msg)
	local container_pos =
		area_containers.get_related_container(node.param1, node.param2)
	if not container_pos then return end
	digiline:receptor_send(container_pos, digiline.rules.default,
		channel, msg)
end

area_containers.port = {
	groups = {
		tubedevice = 1,
		tubedevice_receiver = 1,
	},
	tube = {
		connect_sides = {
			left = 1, right = 1,
			back = 1, front = 1,
			bottom = 1, top = 1,
		},
	},
}


function area_containers.port.tube.can_insert(pos, node)
	return area_containers.get_related_container(node.param1, node.param2)
		~= nil
end

function area_containers.port.tube.insert_object(pos, node, stack, dir, owner)
	local container_pos = area_containers.get_related_container(
		node.param1, node.param2)
	if not container_pos then return stack end
	local id = get_port_id_from_name(node.name)
	local out_dir = port_dirs[id]
	local out_speed = math.max(vector.length(dir), 0.1)
	local out_vel = vector.multiply(out_dir, out_speed)
	pipeworks.tube_inject_item(container_pos, container_pos, out_vel, stack,
		owner)
	return ItemStack() -- All inserted.
end

-- The ports conduct in a similar way to the container, using param1 and param2.
local function get_port_rules(node)
	local rules = {
		{x = 1, y = -1, z = 0},
		{x = 1, y = 0, z = 0},
		{x = 1, y = 1, z = 0},
	}
	local container_pos = area_containers.get_related_container(
		node.param1, node.param2)
	if container_pos then
		local id = get_port_id_from_name(node.name)
		local inside_pos = area_containers.get_related_inside(
			node.param1, node.param2)
		local self_pos = vector.add(inside_pos, port_offsets[id])
		local container_offset =
			vector.subtract(container_pos, self_pos)
		rules[#rules + 1] = container_offset
	end
	return rules
end

-- The vertical faces don't get mesecons since it wasn't working with them.
area_containers.all_port_variants = {
	py_off = {},
	ny_off = {},
}
for _, id in ipairs(port_ids_horiz) do
	local on_state = id .. "_on"
	local off_state = id .. "_off"
	area_containers.all_port_variants[on_state] = {
		mesecons = {conductor = {
			state = "on",
			offstate = port_name_prefix .. off_state,
			rules = get_port_rules,
		}},
	}
	area_containers.all_port_variants[off_state] = {
		mesecons = {conductor = {
			state = "off",
			onstate = port_name_prefix .. on_state,
			rules = get_port_rules,
		}},
	}
end

area_containers.object_counter = {}

function area_containers.object_counter.on_timer(pos, timer)
	-- The counter's position is also the inside_pos:
	update_non_player_object_count(pos)
	return true
end

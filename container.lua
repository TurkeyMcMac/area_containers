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

local function get_node_maybe_load(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then return node end
	-- Try to load the block:
	local vm = minetest.get_voxel_manip()
	vm:read_from_map(pos, pos)
	return minetest.get_node(pos) -- Might be "ignore"
end

local container_name_prefix = "area_containers:container_"

local exit_offset = vector.new(0, 2, 1)
local digiline_offset = vector.new(3, 0, 3)

local port_offsets = {
	nx = vector.new(0, 2, 4), pz = vector.new(0, 2, 6),
	px = vector.new(0, 2, 8), nz = vector.new(0, 2, 10),
	py = vector.new(0, 2, 12), ny = vector.new(0, 2, 14),
}
local port_dirs = {
	nx = vector.new(-1, 0, 0), pz = vector.new(0, 0, 1),
	px = vector.new(1, 0, 0), nz = vector.new(0, 0, -1),
	py = vector.new(0, 1, 0), ny = vector.new(0, -1, 0),
}
local port_ids_horiz = {"nx", "pz", "px", "nz"}

local port_name_prefix = "area_containers:port_"

local function get_port_id_from_name(node_name)
	return string.sub(node_name,
		#port_name_prefix + 1, #port_name_prefix + 2)
end

local function set_up_exit(param1, param2, inside_pos)
	local pos = vector.add(inside_pos, exit_offset)
	minetest.set_node(pos, {
		name = "area_containers:exit",
		param1 = param1, param2 = param2,
	})
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", "Exit")
end

local function set_up_digiline(param1, param2, inside_pos)
	local pos = vector.add(inside_pos, digiline_offset)
	minetest.set_node(pos, {
		name = "area_containers:digiline",
		param1 = param1, param2 = param2,
	})
end

local function set_up_ports(param1, param2, inside_pos)
	for id, offset in pairs(port_offsets) do
		local pos = vector.add(inside_pos, offset)
		minetest.set_node(pos, {
			name = port_name_prefix .. id .. "_off",
			param1 = param1, param2 = param2,
		})
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
	set_up_exit(param1, param2, inside_pos)
	set_up_digiline(param1, param2, inside_pos)
	set_up_ports(param1, param2, inside_pos)
end

area_containers.container = {}

-- There are 16 combinations of the horizontal sides, each with its own name:
area_containers.all_container_states = {}
local all_container_variants = {
	"off", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
	"1000", "1001", "1010", "1011", "1100", "1101", "1110", "on",
}
for i, variant in ipairs(all_container_variants) do
	area_containers.all_container_states[i] =
		container_name_prefix .. variant
end

function area_containers.container.on_construct(pos)
	local node = get_node_maybe_load(pos)
	local param1 = node.param1
	local param2 = node.param2
	if param1 ~= 0 or param2 ~= 0 then
		-- The node probably moved.
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

function area_containers.container.on_destruct(pos)
	-- Only free properly allocated containers:
	local node = get_node_maybe_load(pos)
	if node.param1 ~= 0 or node.param2 ~= 0 then
		area_containers.free_relation(node.param1, node.param2)
	end
end

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
	area_containers.container.after_place_node = pipeworks.after_place
	area_containers.container.after_dig_node = pipeworks.after_dig
end

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

function area_containers.exit.on_rightclick(pos, node, clicker)
	if clicker and minetest.is_player(clicker) then
		local container_pos = area_containers.get_related_container(
			node.param1, node.param2)
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

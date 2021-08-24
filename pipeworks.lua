--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements pipeworks functionality.

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

   Port nodes inside the chamber correspond to faces of the container.
   Pipeworks tubes can pass items through the ports. NOTE: Port nodes are
   assumed to be on the -X side of the chamber.

   See also container.lua and nodes.lua.
]]

local use = ...
local null_func, get_node_maybe_load, port_offsets, port_dirs,
      get_port_id_from_direction, get_port_id_from_name = use("misc", {
	"null_func", "get_node_maybe_load", "port_offsets", "port_dirs",
	"get_port_id_from_direction", "get_port_id_from_name",
})
local get_related_container, get_related_inside = use("relation", {
	"get_related_container", "get_related_inside",
})

local exports = {}

exports.container = {}

exports.port = {}

local pipeworks_maybe = minetest.global_exists("pipeworks") and pipeworks or {}

-- Determines whether a tube item can be inserted at the position going in the
-- direction by checking if there's a receptacle in that direction. This works
-- pretty much like the filter injector in Pipeworks does.
local function can_insert(to_pos, dir)
	local toward_pos = vector.round(vector.add(to_pos, dir))
	local toward_node = get_node_maybe_load(toward_pos)
	if not toward_node or
	   not minetest.registered_nodes[toward_node.name] then
		return false
	end
	return minetest.get_item_group(toward_node.name, "tube") == 1 or
		minetest.get_item_group(toward_node.name, "tubedevice") == 1 or
		minetest.get_item_group(toward_node.name, "tubedevice_receiver")
			== 1
end

exports.container.after_place_node = pipeworks_maybe.after_place or null_func
exports.container.after_dig_node = pipeworks_maybe.after_dig or null_func

-- These must be callable with just the position; see container.lua.
exports.port.after_place_node = pipeworks_maybe.after_place or null_func
exports.port.after_dig_node = pipeworks_maybe.after_dig or null_func

exports.container.groups = {
	tubedevice = 1,
	tubedevice_receiver = 1,
}

exports.container.tube = {
	connect_sides = {
		left = 1, right = 1,
		back = 1, front = 1,
		bottom = 1, top = 1,
	},
}

function exports.container.tube.can_insert(pos, node, _stack, dir)
	local self_pos = get_related_container(node.param1, node.param2)
	if not self_pos or not vector.equals(pos, self_pos) then
		return false
	end
	if node.param1 == 0 and node.param2 == 0 then return false end
	local inside_pos = get_related_inside(node.param1, node.param2)
	local port_id = get_port_id_from_direction(vector.multiply(dir, -1))
	local port_pos = vector.add(inside_pos, port_offsets[port_id])
	return can_insert(port_pos, vector.new(1, 0, 0))
end

function exports.container.tube.insert_object(pos, node, stack, dir, owner)
	local self_pos = get_related_container(node.param1, node.param2)
	if not self_pos or not vector.equals(pos, self_pos) then
		return stack
	end
	local inside_pos = get_related_inside(node.param1, node.param2)
	local port_id = get_port_id_from_direction(vector.multiply(dir, -1))
	local port_pos = vector.add(inside_pos, port_offsets[port_id])
	local out_speed = math.max(vector.length(dir), 0.1)
	local out_vel = vector.new(out_speed, 0, 0)
	pipeworks.tube_inject_item(port_pos, port_pos, out_vel, stack, owner)
	return ItemStack() -- All inserted.
end

exports.port.groups = {
	tubedevice = 1,
	tubedevice_receiver = 1,
}

exports.port.tube = {
	connect_sides = {
		right = 1, -- Connect to +X.
	},
}

function exports.port.tube.can_insert(_pos, node)
	local container_pos = get_related_container(node.param1, node.param2)
	if not container_pos then return false end
	local id = get_port_id_from_name(node.name)
	return can_insert(container_pos, port_dirs[id])
end

function exports.port.tube.insert_object(_pos, node, stack, dir, owner)
	local container_pos = get_related_container(node.param1, node.param2)
	if not container_pos then return stack end
	local id = get_port_id_from_name(node.name)
	local out_dir = port_dirs[id]
	local out_speed = math.max(vector.length(dir), 0.1)
	local out_vel = vector.multiply(out_dir, out_speed)
	pipeworks.tube_inject_item(container_pos, container_pos, out_vel, stack,
		owner)
	return ItemStack() -- All inserted.
end

return exports

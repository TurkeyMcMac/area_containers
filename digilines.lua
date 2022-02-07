--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements digiline functionality.

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

   Digilines messages can pass unaltered between the container and the digiline
   node inside. Forwarding takes one game step. The digiline node is assumed to
   be on the floor. Digiline messages are assumed to be serializable. This
   assumption seems completely reasonable, since digilines are a simulation of
   serial communication lines.

   See also container.lua and nodes.lua.
]]

local use = ...
local storage, get_node_maybe_load,
      CONTAINER_NAME_PREFIX, DIGILINE_OFFSET = use("misc", {
	"storage", "get_node_maybe_load",
	"CONTAINER_NAME_PREFIX", "DIGILINE_OFFSET"
})
local get_related_container, get_related_inside,
      get_params_from_inside = use("relation", {
	"get_related_container", "get_related_inside",
	"get_params_from_inside",
})

local exports = {}

exports.container = {}

exports.digiline = {}

if not minetest.global_exists("digilines") then return exports end

assert(minetest.global_exists("mesecon"),
	"mesecons is now required to use use digilines with area_containers")

-- The connection rules (relative positions to link to) for the digiline node.
local DIGILINE_NODE_RULES = {
	{x = 1, y = 1, z = 0},
	{x = 0, y = 1, z = 1},
	{x = -1, y = 1, z = 0},
	{x = 0, y = 1, z = -1},
}

-- Returns the digiline ID of a container. This is a number unique among other
-- IDs that exist in the past, present, or future. If the node at the position
-- is not a container, nil is returned.
local function get_digiline_id(container_pos)
	local meta = minetest.get_meta(container_pos)
	local id = tonumber((meta:get("area_containers:digiline_id")))
	if not id then
		local node = get_node_maybe_load(container_pos)
		local prefix = string.sub(node.name, 1, #CONTAINER_NAME_PREFIX)
		if prefix == CONTAINER_NAME_PREFIX then
			-- It's a container; allocate the ID for the first use.
			id = storage:get_int("next_digiline_id")
			storage:set_int("next_digiline_id", id + 1)
			meta:set_int("area_containers:digiline_id", id)
		end
	end
	return id
end

-- Sends a message into a container given its position and ID.
local function send_in(pos, id, channel, msg)
	if get_digiline_id(pos) ~= id then return end
	local node = get_node_maybe_load(pos)
	local inside_pos = get_related_inside(node.param1, node.param2)
	local digiline_pos = vector.add(inside_pos, DIGILINE_OFFSET)
	digilines.receptor_send(digiline_pos, DIGILINE_NODE_RULES, channel, msg)
end
mesecon.queue:add_function("area_containers:digiline_in", send_in)

-- Sends a message out of a container given its position and ID.
local function send_out(pos, id, channel, msg)
	if get_digiline_id(pos) ~= id then return end
	digilines.receptor_send(pos, digilines.rules.default, channel, msg)
end
mesecon.queue:add_function("area_containers:digiline_out", send_out)

exports.container.digilines = {
	effector = {},
	receptor = {},
}

-- Forwards messages to the inside.
function exports.container.digilines.effector.action(pos, _node, channel, msg)
	local id = get_digiline_id(pos)
	if not id then return end
	mesecon.queue:add_action(pos, "area_containers:digiline_in",
		{id, channel, msg})
end

exports.digiline.digilines = {
	effector = {rules = DIGILINE_NODE_RULES},
	receptor = {rules = DIGILINE_NODE_RULES},
}

-- Forwards digiline messages to the container.
function exports.digiline.digilines.effector.action(pos, _node, channel, msg)
	local inside_pos = vector.subtract(pos, DIGILINE_OFFSET)
	local param1, param2 = get_params_from_inside(inside_pos)
	if not param1 then return end
	local container_pos = get_related_container(param1, param2)
	if not container_pos then return end
	local id = get_digiline_id(container_pos)
	if not id then return end
	mesecon.queue:add_action(container_pos, "area_containers:digiline_out",
		{id, channel, msg})
end

return exports

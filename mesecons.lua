--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements mesecons functionality.

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
   A Mesecons signal can conduct between the horizontal container faces and
   the ports. The port nodes have the same param1 and param2 as the container
   node for the purpose of conductance. NOTE: Port nodes are assumed to be on
   the -X side of the chamber.

   See also container.lua and nodes.lua.
]]

local use = ...
local ALL_CONTAINER_STATES, PORT_NAME_PREFIX,
      PORT_OFFSETS, PORT_IDS_HORIZ, get_port_id_from_name,
      MESECON_STATE_ON, MESECON_STATE_OFF, vec2table = use("misc", {
	"ALL_CONTAINER_STATES", "PORT_NAME_PREFIX",
	"PORT_OFFSETS", "PORT_IDS_HORIZ", "get_port_id_from_name",
	"MESECON_STATE_ON", "MESECON_STATE_OFF", "vec2table",
})
local get_related_container, get_related_inside = use("relation", {
	"get_related_container", "get_related_inside"
})

local exports = {}

exports.container = {}

exports.ports = {}

-- A container is a conductor to its insides. The position of its insides can
-- be determined from param1 and param2.
exports.container.mesecons = {conductor = {
	states = ALL_CONTAINER_STATES,
}}
local function container_rules_add_port(rules, port_id, self_pos, inside_pos)
	local port_pos = vector.add(inside_pos, PORT_OFFSETS[port_id])
	local offset_to_port = vector.subtract(port_pos, self_pos)
	rules[#rules + 1] = vec2table(offset_to_port)
end
function exports.container.mesecons.conductor.rules(node)
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
	local self_pos = get_related_container(node.param1, node.param2)
	if self_pos then
		local inside_pos = get_related_inside(node.param1, node.param2)
		container_rules_add_port(rules[1], "px", self_pos, inside_pos)
		container_rules_add_port(rules[2], "nx", self_pos, inside_pos)
		container_rules_add_port(rules[3], "pz", self_pos, inside_pos)
		container_rules_add_port(rules[4], "nz", self_pos, inside_pos)
	end
	return rules
end

-- The ports conduct in a similar way to the container, using param1 and param2.
local function get_port_rules(node)
	local rules = {
		{x = 1, y = -1, z = 0},
		{x = 1, y = 0, z = 0},
		{x = 1, y = 1, z = 0},
	}
	local container_pos = get_related_container(node.param1, node.param2)
	if container_pos then
		local id = get_port_id_from_name(node.name)
		local inside_pos = get_related_inside(node.param1, node.param2)
		local self_pos = vector.add(inside_pos, PORT_OFFSETS[id])
		local container_offset =
			vector.subtract(container_pos, self_pos)
		rules[#rules + 1] = vec2table(container_offset)
	end
	return rules
end

-- mesecons information for port nodes that have it, with node names as keys.
for _, id in ipairs(PORT_IDS_HORIZ) do
	local on_state = PORT_NAME_PREFIX .. id .. "_on"
	local off_state = PORT_NAME_PREFIX .. id .. "_off"
	exports.ports[on_state] = {
		mesecons = {conductor = {
			state = MESECON_STATE_ON,
			offstate = off_state,
			rules = get_port_rules,
		}},
	}
	exports.ports[off_state] = {
		mesecons = {conductor = {
			state = MESECON_STATE_OFF,
			onstate = on_state,
			rules = get_port_rules,
		}},
	}
end

return exports

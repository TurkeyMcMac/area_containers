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

local use = ...
local container_name_prefix, port_name_prefix, port_offsets,
      port_ids_horiz, get_port_id_from_name, vec2table = use("misc", {
	"container_name_prefix", "port_name_prefix", "port_offsets",
	"port_ids_horiz", "get_port_id_from_name", "vec2table",
})
local get_related_container, get_related_inside = use("relation", {
	"get_related_container", "get_related_inside"
})

local exports = {}

exports.container = {}

-- The 16 container node names counting up from off to on in binary. The bits
-- from most to least significant are: +X, -X, +Z, -Z.
exports.all_container_states = {}
local all_container_variants = {
	"off", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
	"1000", "1001", "1010", "1011", "1100", "1101", "1110", "on",
}
for i, variant in ipairs(all_container_variants) do
	exports.all_container_states[i] = container_name_prefix .. variant
end

-- A container is a conductor to its insides. The position of its insides can
-- be determined from param1 and param2.
exports.container.mesecons = {conductor = {
	states = exports.all_container_states,
}}
local function container_rules_add_port(rules, port_id, self_pos, inside_pos)
	local port_pos = vector.add(inside_pos, port_offsets[port_id])
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
		local self_pos = vector.add(inside_pos, port_offsets[id])
		local container_offset =
			vector.subtract(container_pos, self_pos)
		rules[#rules + 1] = vec2table(container_offset)
	end
	return rules
end

-- The vertical faces don't get mesecons since it wasn't working with them.
exports.all_port_variants = {
	py_off = {},
	ny_off = {},
}
for _, id in ipairs(port_ids_horiz) do
	local on_state = id .. "_on"
	local off_state = id .. "_off"
	exports.all_port_variants[on_state] = {
		mesecons = {conductor = {
			state = "on",
			offstate = port_name_prefix .. off_state,
			rules = get_port_rules,
		}},
	}
	exports.all_port_variants[off_state] = {
		mesecons = {conductor = {
			state = "off",
			onstate = port_name_prefix .. on_state,
			rules = get_port_rules,
		}},
	}
end

return exports

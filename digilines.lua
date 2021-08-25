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
   node inside. NOTE: The digiline node is assumed to be on the floor.

   See also container.lua and nodes.lua.
]]

local use = ...
local digiline_offset = use("misc", {"digiline_offset"})
local get_related_container, get_related_inside,
      get_params_from_inside = use("relation", {
	"get_related_container", "get_related_inside",
	"get_params_from_inside",
})

local exports = {}

exports.container = {}

exports.digiline = {}

-- The connection rules (relative positions to link to) for the digiline node.
local digiline_node_rules = {
	{x = 1, y = 1, z = 0},
	{x = 0, y = 1, z = 1},
	{x = -1, y = 1, z = 0},
	{x = 0, y = 1, z = -1},
}

exports.container.digiline = {
	effector = {},
	receptor = {},
}

-- Forwards messages to the inside.
function exports.container.digiline.effector.action(_pos, node, channel, msg)
	local inside_pos = get_related_inside(node.param1, node.param2)
	local digiline_pos = vector.add(inside_pos, digiline_offset)
	digiline:receptor_send(digiline_pos, digiline_node_rules, channel, msg)
end

exports.digiline.digiline = {
	effector = {rules = digiline_node_rules},
	receptor = {rules = digiline_node_rules},
}

-- Forwards digiline messages to the container.
function exports.digiline.digiline.effector.action(pos, _node, channel, msg)
	local inside_pos = vector.subtract(pos, digiline_offset)
	local param1, param2 = get_params_from_inside(inside_pos)
	if not param1 then return end
	local container_pos = get_related_container(param1, param2)
	if not container_pos then return end
	digiline:receptor_send(container_pos, digiline.rules.default,
		channel, msg)
end

return exports

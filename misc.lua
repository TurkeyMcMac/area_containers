--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements miscellaneous
   functionality that doesn't fit in the other files, much of which is
   shared between other files.

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

local exports = {}

local storage = minetest.get_mod_storage()
exports.storage = storage

exports.translate = minetest.get_translator("area_containers")

-- Converts a vector (with or without a metatable) into a plain table.
function exports.vec2table(v)
	return {x = v.x, y = v.y, z = v.z}
end

-- Makes a new table, a deep copy of a and b, with b's keys overriding a's.
function exports.merged_table(a, b)
	local merged = table.copy(a)
	for key, value in pairs(table.copy(b)) do
		merged[key] = value
	end
	return merged
end

-- Does and returns nothing.
function exports.null_func() end

-- Rounds the number down to the nearest multiple of the blocksize.
function exports.floor_blocksize(a)
	return math.floor(a / 16) * 16
end

-- If the key is present in storage, returns its integer value. Otherwise, sets
-- its integer value to the default and returns the default.
function exports.get_int_or_default(key, default)
	if storage:contains(key) then
		return storage:get_int(key)
	else
		storage:set_int(key, default)
		return default
	end
end

-- Gets a node. If get_node fails because the position is not loaded, the
-- position is loaded and get_node is again tried. If this fails, a table is
-- returned with name = "ignore".
function exports.get_node_maybe_load(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then return node end
	minetest.load_area(pos)
	return minetest.get_node(pos) -- Might be "ignore"
end

exports.MCL_BLAST_RESISTANCE_INDESTRUCTIBLE = 1000000

-- The longest common prefix of all container node names.
exports.container_name_prefix = "area_containers:container_"

-- The 16 container node names counting up from off to on in binary. The bits
-- from most to least significant are: +X, -X, +Z, -Z.
exports.all_container_states = {}
local all_container_variants = {
	"off", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
	"1000", "1001", "1010", "1011", "1100", "1101", "1110", "on",
}
for i, variant in ipairs(all_container_variants) do
	exports.all_container_states[i] =
		exports.container_name_prefix .. variant
end

-- The mesecons on and off states or nil if they could not be found.
if minetest.global_exists("mesecon") and mesecon.state then
	exports.mesecon_state_on = mesecon.state.on
	exports.mesecon_state_off = mesecon.state.off
end

-- The offsets of the exit and digiline nodes from the inside position
-- (the chamber wall position with the lowest x, y, and z.)
exports.exit_offset = vector.new(0, 2, 1)
exports.digiline_offset = vector.new(3, 0, 3)

-- A mapping from port IDs to offsets from the inside position.
exports.port_offsets = {
	nx = vector.new(0, 2, 4), pz = vector.new(0, 2, 6),
	px = vector.new(0, 2, 8), nz = vector.new(0, 2, 10),
	py = vector.new(0, 2, 12), ny = vector.new(0, 2, 14),
}

-- A mapping from port IDs to unit vectors encoding the directions the
-- corresponding outside ports face.
exports.port_dirs = {
	nx = vector.new(-1, 0, 0), pz = vector.new(0, 0, 1),
	px = vector.new(1, 0, 0), nz = vector.new(0, 0, -1),
	py = vector.new(0, 1, 0), ny = vector.new(0, -1, 0),
}

-- The list of horizontal port IDs in the order they appear inside,
-- left to right.
exports.port_ids_horiz = {"nx", "pz", "px", "nz"}

-- The longest common prefix of all port node names.
local port_name_prefix = "area_containers:port_"
exports.port_name_prefix = port_name_prefix

-- Maps a port node name to the corresponding port ID.
function exports.get_port_id_from_name(node_name)
	local prefix_length = #port_name_prefix
	return string.sub(node_name, prefix_length + 1, prefix_length + 2)
end

-- The names of all nodes that count as ports.
exports.all_port_states = {}
for _, id in ipairs(exports.port_ids_horiz) do
	table.insert(exports.all_port_states, port_name_prefix .. id .. "_on")
	table.insert(exports.all_port_states, port_name_prefix .. id .. "_off")
end
table.insert(exports.all_port_states, port_name_prefix .. "py_off")
table.insert(exports.all_port_states, port_name_prefix .. "ny_off")

-- Maps a tube output direction parallel to exactly one axis to the best guess
-- of the port ID.
function exports.get_port_id_from_direction(dir)
	if dir.x > 0 then
		return "px"
	elseif dir.x < 0 then
		return "nx"
	elseif dir.z > 0 then
		return "pz"
	elseif dir.z < 0 then
		return "nz"
	elseif dir.y > 0 then
		return "py"
	else
		return "ny"
	end
end

-- Gets the stored count of non-player objects associated with the inside from
-- the meta key "area_containers:object_count" at the inside position.
local function get_non_player_object_count(inside_pos)
	local inside_meta = minetest.get_meta(inside_pos)
	return inside_meta:get_int("area_containers:object_count")
end
exports.get_non_player_object_count = get_non_player_object_count

-- Updates the stored count of non-player objects associated with the inside.
-- The new count is returned. This should only be called for active blocks.
function exports.update_non_player_object_count(inside_pos)
	-- Try to limit updates to active blocks if possible:
	if not minetest.compare_block_status or
	   minetest.compare_block_status(inside_pos, "active") then
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
	return get_non_player_object_count(inside_pos)
end

return exports

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


   The code for determining the mapchunk position in blockpos_in_range is based
   on some code from the Minetest project itself, specifically
   EmergeManager::getContainingChunk in src/emerge.cpp and getContainerPos in
   src/util/numeric.h. Both these files are provided under the terms of the
   GNU Lesser General Public License version 2.1 or any later version.

   The relevant revision of src/emerge.cpp is copyrighted as follows:
   Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>
   Copyright (C) 2010-2013 kwolekr, Ryan Kwolek <kwolekr@minetest.net>

   The relevant revision of src/util/numeric.h is copyrighted as follows:
   Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>

   The source code of these files can be found at
   <https://github.com/minetest/minetest/>.
]]

local exports = {}

local MAPGEN_LIMIT =
	tonumber(minetest.get_mapgen_setting("mapgen_limit") or 31000)

local CHUNKSIZE = tonumber(minetest.get_mapgen_setting("chunksize") or 5)

exports.storage = minetest.get_mod_storage()

exports.translate = minetest.get_translator("area_containers")

-- Converts a vector (with or without a metatable) into a plain table.
function exports.vec2table(v)
	return {x = v.x, y = v.y, z = v.z}
end

-- Makes a new table containing the pairs of a and b, with b's overriding a's.
function exports.merged_table(a, b)
	local merged = {}
	for key, value in pairs(a) do
		merged[key] = value
	end
	for key, value in pairs(b) do
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

-- Gets a node. If get_node fails because the position is not loaded, the
-- position is loaded and get_node is again tried. If this fails, a table is
-- returned with name = "ignore".
function exports.get_node_maybe_load(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then return node end
	minetest.load_area(pos)
	return minetest.get_node(pos) -- Might be "ignore"
end

-- Returns whether the block position (NOT node position) is in-range of the
-- map generation.
function exports.blockpos_in_range(blockpos)
	local chunk_offset = -math.floor(CHUNKSIZE / 2)
	local chunkpos = vector.floor(
		vector.divide(
			vector.subtract(blockpos, chunk_offset),
			CHUNKSIZE))
	-- The chunk's minimum position minus the one-block padding:
	local min_pos = vector.multiply(
		vector.add(
			vector.multiply(chunkpos, CHUNKSIZE),
			chunk_offset - 1),
		16)
	if min_pos.x < -MAPGEN_LIMIT or min_pos.y < -MAPGEN_LIMIT or
	   min_pos.z < -MAPGEN_LIMIT then
		return false
	end
	-- One past chunk's maximum position:
	local max_extent = vector.add(min_pos, (CHUNKSIZE + 1) * 16)
	if max_extent.x > MAPGEN_LIMIT or max_extent.y > MAPGEN_LIMIT or
	   max_extent.z > MAPGEN_LIMIT then
		return false
	end
	return true
end

exports.MCL_BLAST_RESISTANCE_INDESTRUCTIBLE = 1000000

-- The longest common prefix of all container node names.
exports.CONTAINER_NAME_PREFIX = "area_containers:container_"

-- The 16 container node names counting up from off to on in binary. The bits
-- from most to least significant are: +X, -X, +Z, -Z.
exports.ALL_CONTAINER_STATES = {}
local all_container_variants = {
	"off", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
	"1000", "1001", "1010", "1011", "1100", "1101", "1110", "on",
}
for i, variant in ipairs(all_container_variants) do
	exports.ALL_CONTAINER_STATES[i] =
		exports.CONTAINER_NAME_PREFIX .. variant
end

-- The mesecons on and off states or nil if they could not be found.
if minetest.global_exists("mesecon") and mesecon.state then
	exports.MESECON_STATE_ON = mesecon.state.on
	exports.MESECON_STATE_OFF = mesecon.state.off
end

-- The offsets of the exit and digiline nodes from the inside position
-- (the chamber wall position with the lowest x, y, and z.)
exports.EXIT_OFFSET = vector.new(0, 2, 1)
exports.DIGILINE_OFFSET = vector.new(3, 0, 3)

-- A mapping from port IDs to offsets from the inside position.
exports.PORT_OFFSETS = {
	nx = vector.new(0, 2, 4), pz = vector.new(0, 2, 6),
	px = vector.new(0, 2, 8), nz = vector.new(0, 2, 10),
	py = vector.new(0, 2, 12), ny = vector.new(0, 2, 14),
}

-- A mapping from port IDs to unit vectors encoding the directions the
-- corresponding outside ports face.
exports.PORT_DIRS = {
	nx = vector.new(-1, 0, 0), pz = vector.new(0, 0, 1),
	px = vector.new(1, 0, 0), nz = vector.new(0, 0, -1),
	py = vector.new(0, 1, 0), ny = vector.new(0, -1, 0),
}

-- The list of horizontal port IDs in the order they appear inside,
-- left to right.
exports.PORT_IDS_HORIZ = {"nx", "pz", "px", "nz"}

-- The longest common prefix of all port node names.
local PORT_NAME_PREFIX = "area_containers:port_"
exports.PORT_NAME_PREFIX = PORT_NAME_PREFIX

-- Maps a port node name to the corresponding port ID.
function exports.get_port_id_from_name(node_name)
	local prefix_length = #PORT_NAME_PREFIX
	return string.sub(node_name, prefix_length + 1, prefix_length + 2)
end

-- The names of all nodes that count as ports.
exports.ALL_PORT_STATES = {}
for _, id in ipairs(exports.PORT_IDS_HORIZ) do
	table.insert(exports.ALL_PORT_STATES, PORT_NAME_PREFIX .. id .. "_on")
	table.insert(exports.ALL_PORT_STATES, PORT_NAME_PREFIX .. id .. "_off")
end
table.insert(exports.ALL_PORT_STATES, PORT_NAME_PREFIX .. "py_off")
table.insert(exports.ALL_PORT_STATES, PORT_NAME_PREFIX .. "ny_off")

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

return exports

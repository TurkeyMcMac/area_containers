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

-- Name the private namespace:
local AC = ...

AC.storage = minetest.get_mod_storage()

AC.S = minetest.get_translator("area_containers")

-- Converts a vector (with or without a metatable) into a plain table.
function AC.vec2table(v)
	return {x = v.x, y = v.y, z = v.z}
end

-- Makes a new table, a deep copy of a and b, with b's keys overriding a's.
function AC.merged_table(a, b)
	local merged = table.copy(a)
	for key, value in pairs(table.copy(b)) do
		merged[key] = value
	end
	return merged
end

-- Overrides the key in the table with the function. If the key already exists,
-- the new value calls that function then the new function. Both the old and the
-- new have their return values discarded.
function AC.extend_func(table, key, new_func)
	local old_func = table[key]
	if old_func then
		table[key] = function(...)
			old_func(...)
			new_func(...)
		end
	else
		table[key] = new_func
	end
end

-- Rounds the number down to the nearest multiple of the blocksize.
function AC.floor_blocksize(a)
	return math.floor(a / 16) * 16
end

function AC.get_int_or_default(key, default)
	if AC.storage:contains(key) then
		return AC.storage:get_int(key)
	else
		AC.storage:set_int(key, default)
		return default
	end
end

-- Gets a node. If get_node fails because the position is not loaded, the
-- position is loaded and get_node is again tried. If this fails, a table is
-- returned with name = "ignore".
function AC.get_node_maybe_load(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then return node end
	minetest.load_area(pos)
	return minetest.get_node(pos) -- Might be "ignore"
end

-- The longest common prefix of all container node names.
AC.container_name_prefix = "area_containers:container_"

-- The offsets of the exit and digiline nodes from the inside position
-- (the chamber wall position with the lowest x, y, and z.)
AC.exit_offset = vector.new(0, 2, 1)
AC.digiline_offset = vector.new(3, 0, 3)

-- A mapping from port IDs to offsets from the inside position.
AC.port_offsets = {
	nx = vector.new(0, 2, 4), pz = vector.new(0, 2, 6),
	px = vector.new(0, 2, 8), nz = vector.new(0, 2, 10),
	py = vector.new(0, 2, 12), ny = vector.new(0, 2, 14),
}
-- A mapping from port IDs to unit vectors encoding the directions the
-- corresponding outside ports face.
AC.port_dirs = {
	nx = vector.new(-1, 0, 0), pz = vector.new(0, 0, 1),
	px = vector.new(1, 0, 0), nz = vector.new(0, 0, -1),
	py = vector.new(0, 1, 0), ny = vector.new(0, -1, 0),
}
-- The list of horizontal port IDs in the order they appear inside,
-- left to right.
AC.port_ids_horiz = {"nx", "pz", "px", "nz"}

-- The longest common prefix of all port node names.
AC.port_name_prefix = "area_containers:port_"

-- Maps a port node name to the corresponding port ID.
function AC.get_port_id_from_name(node_name)
	local prefix_length = #AC.port_name_prefix
	return string.sub(node_name, prefix_length + 1, prefix_length + 2)
end

-- Maps a tube output direction parallel to exactly one axis to the best guess
-- of the port ID.
function AC.get_port_id_from_direction(dir)
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

-- Returns whether there are any nodes or objects in the container.
-- The object count might not be 100% accurate. The node parameter is optional.
function AC.container_is_empty(pos, node)
	node = node or AC.get_node_maybe_load(pos)
	local name_prefix = string.sub(node.name, 1, #AC.container_name_prefix)
	if name_prefix ~= AC.container_name_prefix then return true end
	-- Invalid containers are empty:
	if node.param1 == 0 and node.param2 == 0 then return true end
	local inside_pos = AC.get_related_inside(node.param1, node.param2)
	-- These represent the area of the inner chamber (inclusive):
	local min_pos = vector.add(inside_pos, 1)
	local max_pos = vector.add(inside_pos, 14)

	-- Detect nodes left inside.
	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{MinEdge = min_edge, MaxEdge = max_edge}
	local data = vm:get_data()
	local c_air = minetest.CONTENT_AIR
	for i in area:iterp(min_pos, max_pos) do
		if data[i] ~= c_air then return false end
	end

	-- Detect objects inside.
	local objects_inside = minetest.get_objects_in_area(
		vector.subtract(min_pos, 1), vector.add(max_pos, 1))
	if #objects_inside > 0 then return false end
	-- Detect non-player objects in unloaded inside chambers:
	if AC.get_non_player_object_count(inside_pos) > 0 then return false end

	return true
end

-- Gets the stored count of non-player objects associated with the inside.
function AC.get_non_player_object_count(inside_pos)
	local inside_meta = minetest.get_meta(inside_pos)
	return inside_meta:get_int("area_containers:object_count")
end

-- Updates the stored count of non-player objects associated with the inside.
-- The new count is returned. This should only be called for active blocks.
function AC.update_non_player_object_count(inside_pos)
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
	return AC.get_non_player_object_count(inside_pos)
end

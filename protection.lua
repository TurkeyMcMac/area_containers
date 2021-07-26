--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements the protection layer.

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

   The protection layer extends one block above and below the inside Y-level
   block. It excludes the insides (but walls are protected.)
]]

-- Name the private namespace:
local area_containers = ...

-- Rounds a vector component down to the nearest block size.
local function floor_blocksize(pos)
        return math.floor(pos / 16) * 16
end

-- Checks whether the position is protected only according to area_containers.
-- See the overview for this file.
local function is_area_containers_protected(pos, name)
	-- The minimum position of the block containing pos:
	local block_min_pos = vector.apply(pos, floor_blocksize)
	-- Check that the position is within one block of the inside Y-level:
	if block_min_pos.y - 16 <= area_containers.inside_y_level and
	   block_min_pos.y + 16 >= area_containers.inside_y_level then
		if area_containers.get_params_from_inside(block_min_pos) then
			-- The position is in an inside block.
			-- Protect the walls:
			local block_offset = vector.subtract(pos, block_min_pos)
			if block_offset.x == 0 or block_offset.x == 15 or
			   block_offset.y == 0 or block_offset.y == 15 or
			   block_offset.z == 0 or block_offset.z == 15 then
				return true
			end
		else
			-- Non-inside blocks in the layer are protected.
			return true
		end
	end
	return false
end

-- The old minetest.is_protected. This is set when is_protected is registered.
local old_is_protected = nil

-- The soon-to-be new value of minetest.is_protected.
function is_protected(pos, name)
	-- Apply our mod's protection unless the player can bypass it:
	if not minetest.check_player_privs(name, "protection_bypass") and
	   is_area_containers_protected(pos, name) then
		return true
	end
	return old_is_protected(pos, name)
end

-- Sets up the is_protected function.
function area_containers.register_is_protected()
        old_is_protected = minetest.is_protected
        minetest.is_protected = is_protected
end

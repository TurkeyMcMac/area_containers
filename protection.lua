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

local use = ...
local floor_blocksize = use("misc", {"floor_blocksize"})
local inside_y_level, get_params_from_inside = use("relation", {
	"inside_y_level", "get_params_from_inside"
})

-- The minimum and maximum layers at which the protection applies.
local min_applicable_y = inside_y_level - 16
local max_applicable_y = inside_y_level + 16 + 15

-- Checks whether the position is protected only according to area_containers.
-- See the overview for this file.
local function is_area_containers_protected(pos)
	-- Check that the position is within the protected level:
	local y = pos.y
	if y >= min_applicable_y and y <= max_applicable_y then
		-- The minimum position of the block containing pos:
		local block_min_pos = vector.apply(pos, floor_blocksize)
		if get_params_from_inside(block_min_pos) then
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

local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
	-- Apply our mod's protection unless the player can bypass it:
	if is_area_containers_protected(pos) and
	   not minetest.check_player_privs(name, "protection_bypass") then
		return true
	end
	return old_is_protected(pos, name)
end

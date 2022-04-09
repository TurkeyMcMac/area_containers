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
local PROTECTION_TYPE = use("settings", {"PROTECTION"})
local floor_blocksize = use("misc", {"floor_blocksize"})
local INSIDE_Y_LEVEL, get_params_from_inside = use("relation", {
	"INSIDE_Y_LEVEL", "get_params_from_inside",
})

if PROTECTION_TYPE == "none" then return end

-- Protection settings. PADDING indicates that blocks around inside blocks are
-- also protected.
local LAYER = PROTECTION_TYPE == "layer"
local AROUND = PROTECTION_TYPE == "around"
local PADDING = LAYER or AROUND

-- The minimum and maximum layers at which the protection applies.
local MIN_APPLICABLE_Y = PADDING and INSIDE_Y_LEVEL - 16 or INSIDE_Y_LEVEL
local MAX_APPLICABLE_Y = PADDING and INSIDE_Y_LEVEL + 16 + 15 or
	INSIDE_Y_LEVEL + 15

-- Determines whether the block is one of the 26 around an inside block and
-- should thus be protected with protection type "around".
-- Modifies block_min_pos.
local function pos_around(block_min_pos)
	if block_min_pos.y > INSIDE_Y_LEVEL then
		block_min_pos.y = block_min_pos.y - 16
		if get_params_from_inside(block_min_pos) then return true end
	elseif block_min_pos.y < INSIDE_Y_LEVEL then
		block_min_pos.y = block_min_pos.y + 16
		if get_params_from_inside(block_min_pos) then return true end
	end

	block_min_pos.x = block_min_pos.x + 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.z = block_min_pos.z + 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.x = block_min_pos.x - 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.x = block_min_pos.x - 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.z = block_min_pos.z - 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.z = block_min_pos.z - 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.x = block_min_pos.x + 16
	if get_params_from_inside(block_min_pos) then return true end
	block_min_pos.x = block_min_pos.x + 16
	if get_params_from_inside(block_min_pos) then return true end

	return false
end
-- If not AROUND, the function is never used.
if not AROUND then pos_around = nil end

-- Checks whether the position is protected only according to area_containers.
-- See the overview for this file.
local function is_area_containers_protected(pos)
	-- Check that the position is within the protected level:
	local y = pos.y
	if y >= MIN_APPLICABLE_Y and y <= MAX_APPLICABLE_Y then
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
		elseif PADDING then
			if LAYER then
				-- Non-inside blocks in the layer are protected.
				return true
			else
				return pos_around(block_min_pos)
			end
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

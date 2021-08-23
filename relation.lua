--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements the allocation of
   unused mapblocks in which to place the inner chambers of area containers.

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

  There must be a mapping between the insides of containers and the container
  nodes themselves. A "relation" encodes an inside position and a container
  position. The inside position is the minimum coordinate of the inside chamber.
  Chambers are block-aligned, and are pretty much assumed to fill exactly one
  block. The container position is stored in the metadata at the inside
  position, and may or may not be set. A relation consists of param1 and param2
  values that can be stored in a node. Relations are allocated and freed using
  functions in this file. An allocated/freed parameter pair must never have both
  parameters be 0, but all possible parameter combinations are considered valid
  relations.
]]

local use = ...
local get_int_or_default, storage = use("misc", {
	"get_int_or_default", "storage",
})
local settings = use("settings")

local exports = {}

-- Settings --

-- The positioning settings should be multiples of 16.
local DEFAULT_INSIDE_SPACING = 240
local DEFAULT_Y_LEVEL = 16 * settings.y_level_blocks
local DEFAULT_X_BASE = -30608
local DEFAULT_Z_BASE = -30608
local MAX_CONTAINER_CACHE_SIZE = settings.max_cache_size

-- Check that the positioning settings are within bounds:
local mod_setting_message =
	"The setting area_containers_y_level_blocks is outside the mapgen_limit"
local file_setting_message =
	"A setting in this file is outside the mapgen_limit"
local mapgen_limit_rounded = 16 * math.floor(
	tonumber(minetest.settings:get("mapgen_limit") or 31000) / 16)
assert(DEFAULT_Y_LEVEL >= -mapgen_limit_rounded, mod_setting_message)
assert(DEFAULT_Y_LEVEL + 16 <= mapgen_limit_rounded, mod_setting_message)
assert(DEFAULT_X_BASE >= -mapgen_limit_rounded, file_setting_message)
assert(DEFAULT_X_BASE + DEFAULT_INSIDE_SPACING * 255 <= mapgen_limit_rounded,
	file_setting_message)
assert(DEFAULT_Z_BASE >= -mapgen_limit_rounded, file_setting_message)
assert(DEFAULT_Z_BASE + DEFAULT_INSIDE_SPACING * 255 <= mapgen_limit_rounded,
	file_setting_message)

-- Persistent Configuration --

-- The period between insides measured in node lengths.
local INSIDE_SPACING = get_int_or_default(
	"INSIDE_SPACING", DEFAULT_INSIDE_SPACING)
-- The y value of all inside positions.
local Y_LEVEL = get_int_or_default("Y_LEVEL", DEFAULT_Y_LEVEL)
-- The minimum x and z values of all inside positions.
local X_BASE = get_int_or_default("X_BASE", DEFAULT_X_BASE)
local Z_BASE = get_int_or_default("Z_BASE", DEFAULT_Z_BASE)
-- The next param values to be allocated if no other free spaces are available.
local param1_next = get_int_or_default("param1_next", 1)
local param2_next = get_int_or_default("param2_next", 0)

-- Container position caching --

-- The cache of container positions (indexed by get_params_index.)
local cached_containers = {}
-- The number of entries.
local container_cache_size = 0

-- Cache the container position to associate with the given parameter index.
local function cache_container(index, pos)
	local old_value = cached_containers[index]
	if pos and not old_value then
		-- Add.
		if container_cache_size >= MAX_CONTAINER_CACHE_SIZE then
			-- Just purge everything and start again.
			cached_containers = {}
			container_cache_size = 0
		end
		container_cache_size = container_cache_size + 1
	elseif old_value and not pos then
		-- Remove.
		container_cache_size = container_cache_size - 1
	end
	cached_containers[index] = pos
end

-- Parameter Interpretation --

-- Returns a numeric index unique to the parameter pair.
local function get_params_index(param1, param2)
	return param1 + param2 * 256
end
exports.get_params_index = get_params_index

-- Returns the related inside position (the minimum coordinate of the chamber.)
local function get_related_inside(param1, param2)
	return vector.new(
		X_BASE + param1 * INSIDE_SPACING,
		Y_LEVEL,
		Z_BASE + param2 * INSIDE_SPACING
	)
end
exports.get_related_inside = get_related_inside

-- Returns the two params associated with the position if it is a position that
-- could be returned from get_related_inside, or two nil values otherwise.
function exports.get_params_from_inside(inside_pos)
	if inside_pos.y ~= Y_LEVEL then return nil, nil end
	local param1 = (inside_pos.x - X_BASE) / INSIDE_SPACING
	local param2 = (inside_pos.z - Z_BASE) / INSIDE_SPACING
	if param1 >= 0 and param1 <= 255 and param2 >= 0 and param2 <= 255 and
	   param1 % 1 == 0 and param2 % 1 == 0 then
		return param1, param2
	end
	return nil, nil
end

-- The actual Y-level (in nodes) of all inside positions (container bottoms.)
exports.inside_y_level = Y_LEVEL

-- Gets the related container position. Returns nil if it isn't set.
function exports.get_related_container(param1, param2)
	local idx = get_params_index(param1, param2)
	local container_pos = cached_containers[idx]
	if not container_pos then
		local inside_pos = get_related_inside(param1, param2)
		local inside_meta = minetest.get_meta(inside_pos)
		container_pos = minetest.string_to_pos(
			inside_meta:get_string("area_containers:container_pos"))
		cache_container(idx, container_pos)
	end
	return container_pos
end

-- Sets the related container, or unsets it if container_pos is nil.
function exports.set_related_container(param1, param2, container_pos)
	local inside_pos = get_related_inside(param1, param2)
	local inside_meta = minetest.get_meta(inside_pos)
	inside_meta:set_string("area_containers:container_pos",
		container_pos and minetest.pos_to_string(container_pos) or "")
	cache_container(get_params_index(param1, param2), container_pos)
end

-- Parameter String Encoding and Decoding --

--[[
  The storage key "freed" is a string representation of a stack. It consists of
  concatenated fixed-length records representing parameter pairs. Each record is
  PARAMS_STRING_LENGTH characters long.
]]

-- Set up the bi-directional mapping between characters and segments of 6 bits:
local seg2byte = {string.byte(
	"123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+-",
	1, -1
)}
assert(#seg2byte == 63)
seg2byte[0] = string.byte("0") -- The indices must be [0-63]
local byte2seg = {}
for i = 0, 63 do
	byte2seg[seg2byte[i]] = i
end

local PARAMS_STRING_LENGTH = 3

local function params_to_string(param1, param2)
	local seg1 = param1 % 64
	local seg2 = param2 % 64
	local seg3 = math.floor(param1 / 64) + math.floor(param2 / 64) * 4
	return string.char(seg2byte[seg1], seg2byte[seg2], seg2byte[seg3])
end

local function string_to_params(str)
	local byte1, byte2, byte3 = string.byte(str, 1, 3)
	local seg1 = byte2seg[byte1]
	local seg2 = byte2seg[byte2]
	local seg3 = byte2seg[byte3]
	local param1 = seg1 + (seg3 % 4) * 64
	local param2 = seg2 + math.floor(seg3 / 4) * 64
	return param1, param2
end

-- Allocation and Deallocation (with No Map Alteration) --

-- Returns a newly allocated param1, param2. Returns nil, nil if there is no
-- space left.
function exports.alloc_relation()
	local param1, param2
	local freed = storage:get_string("freed")
	if #freed >= PARAMS_STRING_LENGTH then
		-- Pop a space off the freed stack if one is available.
		param1, param2 = string_to_params(
			string.sub(freed, -PARAMS_STRING_LENGTH))
		freed = string.sub(freed, 1, #freed - PARAMS_STRING_LENGTH)
		storage:set_string("freed", freed)
	elseif param2_next < 256 then
		-- Add a new space to the pool if no space is available.
		param1 = param1_next
		param2 = param2_next
		param1_next = param1_next + 1
		if param1_next >= 256 then
			-- Wrap around.
			param1_next = 0
			param2_next = param2_next + 1
		end
		storage:set_int("param1_next", param1_next)
		storage:set_int("param2_next", param2_next)
	end
	return param1, param2
end

-- Adds the relation to the freed list to be reused later.
function exports.free_relation(param1, param2)
	-- Push the params:
	local freed = storage:get_string("freed")
	freed = freed .. params_to_string(param1, param2)
	storage:set_string("freed", freed)
end

-- Tries to reclaim the specific relation from the freed list. Returned is
-- whether the relation could be reclaimed and removed from the freed list.
function exports.reclaim_relation(param1, param2)
	local find_params = params_to_string(param1, param2)
	local freed = storage:get_string("freed")
	-- A special case for when the reclaimed is the most recently freed:
	if string.sub(freed, -PARAMS_STRING_LENGTH) == find_params then
		freed = string.sub(freed, 1, #freed - PARAMS_STRING_LENGTH)
		storage:set_string("freed", freed)
		return true
	end
	-- Search through all the other records backward (more recent first):
	for i = 1, #freed - PARAMS_STRING_LENGTH + 1, PARAMS_STRING_LENGTH do
		local start = -i - PARAMS_STRING_LENGTH + 1
		local finish = -i
		local check_params = string.sub(freed, start, finish)
		if check_params == find_params then
			-- Found!
			freed = string.sub(freed, 1, start - 1) ..
				string.sub(freed, finish + 1)
			storage:set_string("freed", freed)
			return true
		end
	end
	return false
end

return exports

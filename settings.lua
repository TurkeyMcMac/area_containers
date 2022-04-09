--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It collects the mod's settings.

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

local settings = {
	Y_LEVEL_BLOCKS = tonumber(minetest.settings:get(
		"area_containers_y_level_blocks")) or 1931,
	ENABLE_CRAFTS = minetest.settings:get_bool(
		"area_containers_enable_crafts", true),
	MAX_CACHE_SIZE = tonumber(minetest.settings:get(
		"area_containers_max_cache_size")) or 256,
	WALL_LIGHT = tonumber(minetest.settings:get(
		"area_containers_wall_light")) or 14,
	PROTECTION = minetest.settings:get("area_containers_protection"),
}
if settings.PROTECTION ~= "none" and settings.PROTECTION ~= "walls" and
		settings.PROTECTION ~= "around" then
	settings.PROTECTION = "layer"
end

return settings

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

return {
	y_level_blocks = tonumber(minetest.settings:get(
		"area_containers_y_level_blocks") or 1931),
	enable_crafts = minetest.settings:get_bool(
		"area_containers_enable_crafts", true),
	max_cache_size = tonumber(minetest.settings:get(
		"area_containers_max_cache_size") or 256),
	wall_light = tonumber(minetest.settings:get(
		"area_containers_wall_light") or 14),
}

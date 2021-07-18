--[[
    Copyright (C) 2021  Jude Melton-Houghton

    This file is part of area_containers. It initializes basic stuff and
    calls the code from the other source files.

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

area_containers = {}

area_containers.settings = {
	y_level_blocks = tonumber(minetest.settings:get(
		"area_containers_y_level_blocks") or 1931),
	spacing_blocks = tonumber(minetest.settings:get(
		"area_containers_spacing_blocks") or 2),
	enable_crafts = minetest.settings:get_bool(
		"area_containers_enable_crafts", true),
}

local modpath = minetest.get_modpath("area_containers")
dofile(modpath .. "/crafts.lua")
dofile(modpath .. "/container.lua")
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/relation.lua")

area_containers.register_nodes()

if area_containers.settings.enable_crafts then
	area_containers.register_crafts()
end

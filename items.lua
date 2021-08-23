--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It specifies superficial item
   characteristics such as textures, in addition to registering the items.

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

AC.depend("misc")

minetest.register_craftitem("area_containers:lock", {
	description = AC.S("Area Container Lock"),
	inventory_image = "area_containers_lock.png",
	stack_max = 1,
	node_dig_prediction = "",
})

minetest.register_craftitem("area_containers:key_blank", {
	description = AC.S("Blank Area Container Key"),
	inventory_image = "area_containers_key_blank.png",
	stack_max = 1,
	node_dig_prediction = "",
})

minetest.register_craftitem("area_containers:key", {
	description = AC.S("Area Container Key"),
	inventory_image = "area_containers_key.png",
	groups = {not_in_creative_inventory = 1},
	stack_max = 1,
	node_dig_prediction = "",
})

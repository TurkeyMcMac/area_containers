--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It specifies the crafting recipes.

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

local use = ...
use("items")
use("nodes")

local function register_crafts_with_ingredients(
		container_corner, container_side, container_core,
		item_body, item_core)
	if minetest.registered_items[container_corner] and
	   minetest.registered_items[container_side] and
	   minetest.registered_items[container_core] then
		minetest.register_craft({
			output = "area_containers:container",
			recipe = {
				{
					container_corner,
					container_side,
					container_corner,
				},
				{
					container_side,
					container_core,
					container_side,
				},
				{
					container_corner,
					container_side,
					container_corner,
				},
			},
		})
	end

	if minetest.registered_items[item_body] and
	   minetest.registered_items[item_core] then
		minetest.register_craft({
			output = "area_containers:lock",
			recipe = {
				{item_body, ""       },
				{item_core, item_body},
				{item_body, item_body},
			},
		})

		minetest.register_craft({
			output = "area_containers:key_blank",
			recipe = {
				{item_body, item_body, item_core},
				{item_body, ""       , ""       },
			},
		})
	end
end

-- Minetest Game:
register_crafts_with_ingredients(
	"default:steel_ingot", "default:steelblock", "default:mese",
	"default:steel_ingot", "default:mese_crystal_fragment")

-- MineClone 2:
register_crafts_with_ingredients(
	"mcl_core:ironblock", "mcl_core:diamond", "mesecons:redstone",
	"mcl_core:iron_ingot", "mesecons:redstone")

-- Key recycling:
minetest.register_craft({
	output = "area_containers:key_blank",
	type = "shapeless",
	recipe = {"area_containers:key"},
})

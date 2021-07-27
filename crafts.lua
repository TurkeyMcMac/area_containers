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

-- Name the private namespace:
local area_containers = ...

function area_containers.register_crafts()
	-- Minetest Game:
	if minetest.registered_items["default:steel_ingot"] and
	   minetest.registered_items["default:mese"] then
		minetest.register_craft({
			output = "area_containers:container",
			recipe = {
				{
					"default:steel_ingot",
					"default:steel_ingot",
					"default:steel_ingot"
				},
				{
					"default:steel_ingot",
					"default:mese",
					"default:steel_ingot",
				},
				{
					"default:steel_ingot",
					"default:steel_ingot",
					"default:steel_ingot",
				},
			},
		})
	end

	-- MineClone 2:
	if minetest.registered_items["mcl_core:ironblock"] and
	   minetest.registered_items["mesecons:redstone"] and
	   minetest.registered_items["mcl_core:diamond"] then
		minetest.register_craft({
			output = "area_containers:container",
			recipe = {
				{
					"mcl_core:ironblock",
					"mesecons:redstone",
					"mcl_core:ironblock"
				},
				{
					"mesecons:redstone",
					"mcl_core:diamond",
					"mesecons:redstone",
				},
				{
					"mcl_core:ironblock",
					"mesecons:redstone",
					"mcl_core:ironblock",
				},
			},
		})
	end
end

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


function area_containers.register_crafts()
	if minetest.registered_craftitems["default:steel_ingot"] and
	   minetest.registered_nodes["default:mese"] then
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
end

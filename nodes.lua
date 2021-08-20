--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It specifies superficial node
   characteristics such as textures, in addition to registering the nodes.

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

local S = minetest.get_translator("area_containers")

local mesecon_on_color = "#FCFF00"
local mesecon_off_color = "#8A8C00"
local digiline_color = "#4358C0"

-- The mesecons namespace, or an empty table if it isn't available.
local mesecon_maybe = minetest.global_exists("mesecon") and mesecon or {}

-- A new table that is a deep copy of a and b, with b keys overriding a keys.
local function merged_table(a, b)
	local merged = table.copy(a)
	for key, value in pairs(table.copy(b)) do
		merged[key] = value
	end
	return merged
end

-- Returns the inside wire texture specification with the given ColorString.
local function wire_texture(color)
	return "(area_containers_wire.png^[colorize:" .. color .. ":255)"
end

-- Returns the outside wire texture specification with the given ColorString.
local function outer_wire_texture(color)
	return "(area_containers_outer_wire.png^[colorize:" .. color .. ":255)"
end

local base_wall_def = {
	groups = {}, -- not_in_creative_inventory will be added.
	is_ground_content = false,
	diggable = false,
	on_blast = function() end,
}
-- Registers the wall "area_containers:"..local_name with the definition that
-- is merged into the base definition above.
local function register_wall(local_name, def)
	local name = "area_containers:" .. local_name
	local full_def = merged_table(base_wall_def, def)
	full_def.groups = table.copy(full_def.groups)
	full_def.groups.not_in_creative_inventory = 1
	minetest.register_node(name, full_def)
	if mesecon_maybe.register_mvps_stopper then
		-- You can't push walls.
		mesecon_maybe.register_mvps_stopper(name)
	end
end

function area_containers.register_nodes()
	-- The base container tiles (order: +Y, -Y, +X, -X, +Z, -Z):
	local container_tiles = {}
	-- IDs for the purpose of identifying labels:
	local container_tile_ids = {"py", "ny", "px", "nx", "pz", "nz"}
	for i, id in ipairs(container_tile_ids) do
		container_tiles[i] = "area_containers_outer_port.png^" ..
			"area_containers_" .. id .. ".png"
	end
	-- Register all the container nodes:
	for name, def in pairs(area_containers.all_container_states) do
		def = merged_table(area_containers.container, def)
		def = merged_table(def, {
			description = S("Area Container"),
			tiles = table.copy(container_tiles),
			drop = area_containers.all_container_states[1],
		})
		if minetest.global_exists("mesecon") then
			local bits = def._area_containers_bits
			local wire_choices = {
				outer_wire_texture(mesecon_off_color),
				outer_wire_texture(mesecon_on_color),
			}
			for j = 1, 4 do
				local bit = bits % 2
				local tile_idx = 7 - j
				local label = "area_containers_" ..
					container_tile_ids[tile_idx] .. ".png"
				def.tiles[tile_idx] = table.concat({
					"area_containers_outer_port.png",
					wire_choices[bit + 1],
					label,
				}, "^")
				bits = math.floor(bits / 2)
			end
		end
		if minetest.global_exists("default") and
		   default.node_sound_metal_defaults then
			def.sounds = default.node_sound_metal_defaults()
		end
		def.groups = merged_table(def.groups or {}, {cracky = 2})
		if name ~= "area_containers:container_off" then
			def.groups.not_in_creative_inventory = 1
		end
		minetest.register_node(name, def)
	end
	minetest.register_alias("area_containers:container",
		"area_containers:container_off")

	local wall_light = area_containers.settings.wall_light
	register_wall("wall", {
		description = S("Container Wall"),
		paramtype = wall_light > 0 and "light" or "none",
		light_source = math.min(wall_light, minetest.LIGHT_MAX),
		tiles = {"area_containers_wall.png"},
	})

	register_wall("exit", merged_table(area_containers.exit, {
		description = S("Container Exit"),
		tiles = {"area_containers_wall.png^area_containers_exit.png"},
	}))

	local digiline_texture = "area_containers_wall.png"
	if minetest.global_exists("digiline") then
		digiline_texture = digiline_texture .. "^" ..
			wire_texture(digiline_color)
	end
	register_wall("digiline", merged_table(area_containers.digiline, {
		description = S("Container's Digiline Connection"),
		tiles = {digiline_texture},
	}))

	-- Register all port node variants:
	for variant, def in pairs(area_containers.all_port_variants) do
		local full_def = merged_table(area_containers.port, def)
		full_def.description = S("Container's Mesecon/Tube Connection")
		local tile = "area_containers_wall.png"
		local mesecons_spec = full_def.mesecons
		if mesecons_spec and mesecon_maybe.state then
			-- Register correct colors for mesecons-enabled ports:
			local color = mesecon_off_color
			local on = mesecon_maybe.state.on
			if mesecons_spec and mesecons_spec.receptor and
			   mesecons_spec.receptor.state == on then
				color = mesecon_on_color
			end
			tile = tile .. "^" .. wire_texture(color)
		end
		local label_id = string.sub(variant, 1, 2)
		tile = table.concat({
			tile, "^",
			"area_containers_port.png^",
			"area_containers_", label_id, ".png",
		}, "")
		full_def.tiles = {tile}
		register_wall("port_" .. variant, full_def)

	end

	register_wall("object_counter",
		merged_table(area_containers.object_counter, {
			description =
				S("Misc. Controlling Node for a Container"),
			tiles = {"area_containers_wall.png"},
		})
	)
end

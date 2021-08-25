--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It registers the nodes, putting
   together the functionality from other files.

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
local S, null_func, merged_table, get_port_id_from_name,
      all_container_states, all_port_states, mesecon_state_on,
      MCL_BLAST_RESISTANCE_INDESTRUCTIBLE = use("misc", {
	"translate", "null_func", "merged_table", "get_port_id_from_name",
	"all_container_states", "all_port_states", "mesecon_state_on",
	"MCL_BLAST_RESISTANCE_INDESTRUCTIBLE",
})
local settings = use("settings")
local container_base, exit_base, object_counter_base = use("container", {
	"container", "exit", "object_counter",
})
local container_digilines, digiline_base = use("digilines", {
	"container", "digiline",
})
local container_mesecons, ports_mesecons = use("mesecons", {
	"container", "ports",
})
local container_pipeworks, port_pipeworks = use("pipeworks", {
	"container", "port",
})

local mesecon_on_color = "#FCFF00"
local mesecon_off_color = "#8A8C00"
local digiline_color = "#4358C0"

-- The mesecons namespace, or an empty table if it isn't available.
local mesecon_maybe = minetest.global_exists("mesecon") and mesecon or {}

-- Returns the inside wire texture specification with the given ColorString.
local function wire_texture(color)
	return "(area_containers_wire.png^[colorize:" .. color .. ":255)"
end

-- Returns the outside wire texture specification with the given ColorString.
local function outer_wire_texture(color)
	return "(area_containers_outer_wire.png^[colorize:" .. color .. ":255)"
end

local wall_base = {
	paramtype = settings.wall_light > 0 and "light" or "none",
	light_source = math.min(settings.wall_light, minetest.LIGHT_MAX),
	groups = {}, -- not_in_creative_inventory will be added.
	is_ground_content = false,
	diggable = false,
	on_blast = null_func,
	_mcl_blast_resistance = MCL_BLAST_RESISTANCE_INDESTRUCTIBLE,
}
-- Registers the wall "area_containers:"..local_name with the definition that
-- is merged into the base definition above.
local function register_wall(name, def)
	local full_def = merged_table(wall_base, def)
	full_def.groups = table.copy(full_def.groups)
	full_def.groups.not_in_creative_inventory = 1
	minetest.register_node(name, full_def)
	if mesecon_maybe.register_mvps_stopper then
		-- You can't push walls.
		mesecon_maybe.register_mvps_stopper(name)
	end
end

-- Combine the functions into one (discarding their return values):
local container_base_after_place_node = container_base.after_place_node
local container_pipeworks_after_place_node =
	container_pipeworks.after_place_node
local function container_after_place_node(...)
	container_base_after_place_node(...)
	container_pipeworks_after_place_node(...)
end
-- The base container tiles (order: +Y, -Y, +X, -X, +Z, -Z):
local container_tiles = {}
-- IDs for the purpose of identifying labels:
local container_tile_ids = {"py", "ny", "px", "nx", "pz", "nz"}
for i, id in ipairs(container_tile_ids) do
	container_tiles[i] = "area_containers_outer_port.png^" ..
		"area_containers_" .. id .. ".png"
end
-- The activations in parallel to all_container_states:
local container_activations = {
	{0, 0, 0, 0}, {0, 0, 0, 1}, {0, 0, 1, 0}, {0, 0, 1, 1},
	{0, 1, 0, 0}, {0, 1, 0, 1}, {0, 1, 1, 0}, {0, 1, 1, 1},
	{1, 0, 0, 0}, {1, 0, 0, 1}, {1, 0, 1, 0}, {1, 0, 1, 1},
	{1, 1, 0, 0}, {1, 1, 0, 1}, {1, 1, 1, 0}, {1, 1, 1, 1},
}
-- Register all the container nodes:
for i, name in ipairs(all_container_states) do
	local container_def = {
		description = S("Area Container"),
		tiles = table.copy(container_tiles),
		drop = all_container_states[1],
		groups = merged_table(container_pipeworks.groups, {cracky = 2}),
		on_construct = container_base.on_construct,
		after_place_node = container_after_place_node,
		on_destruct = container_base.on_destruct,
		can_dig = container_base.can_dig,
		after_dig_node = container_pipeworks.after_dig_node,
		on_blast = null_func,
		_mcl_blast_resistance = MCL_BLAST_RESISTANCE_INDESTRUCTIBLE,
		on_rightclick = container_base.on_rightclick,
		on_punch = container_base.on_punch,
		mesecons = container_mesecons.mesecons,
		digiline = container_digilines.digiline,
		tube = container_pipeworks.tube,
	}
	if minetest.global_exists("mesecon") then
		local activation = container_activations[i]
		local wire_choices = {
			outer_wire_texture(mesecon_off_color),
			outer_wire_texture(mesecon_on_color),
		}
		for j, active in ipairs(activation) do
			-- The tile corresponding to this bit:
			local tile_idx = 7 - j
			local label = "area_containers_" ..
				container_tile_ids[tile_idx] .. ".png"
			container_def.tiles[tile_idx] = table.concat({
				"area_containers_outer_port.png",
				wire_choices[active + 1],
				label,
			}, "^")
		end
	end
	if minetest.global_exists("default") and
	   default.node_sound_metal_defaults then
		container_def.sounds = default.node_sound_metal_defaults()
	end
	if i > 1 then
		container_def.groups.not_in_creative_inventory = 1
	end
	minetest.register_node(name, container_def)
	if mesecon_maybe.register_mvps_stopper then
		mesecon_maybe.register_mvps_stopper(name)
	end
end
minetest.register_alias("area_containers:container", all_container_states[1])

register_wall("area_containers:wall", {
	description = S("Container Wall"),
	tiles = {"area_containers_wall.png"},
})

register_wall("area_containers:exit", merged_table(exit_base, {
	description = S("Container Exit"),
	tiles = {"area_containers_wall.png^area_containers_exit.png"},
}))

local digiline_texture = "area_containers_wall.png"
if minetest.global_exists("digiline") then
	digiline_texture = digiline_texture .. "^" ..
		wire_texture(digiline_color)
end
register_wall("area_containers:digiline", merged_table(digiline_base, {
	description = S("Container's Digiline Connection"),
	tiles = {digiline_texture},
}))

-- Register all port node variants:
for _, name in ipairs(all_port_states) do
	local port_mesecons = ports_mesecons[name]
	local full_def = merged_table(port_pipeworks, port_mesecons or {})
	full_def.description = S("Container's Mesecon/Tube Connection")
	full_def.paramtype = "none"
	full_def.light_source = 0
	local tile = "area_containers_wall.png"
	local mesecons_spec = full_def.mesecons
	if mesecons_spec and mesecon_maybe.state then
		-- Register correct colors for mesecons-enabled ports:
		local color = mesecon_off_color
		if mesecons_spec and mesecons_spec.conductor and
		   mesecons_spec.conductor.state == mesecon_state_on then
			color = mesecon_on_color
		end
		tile = tile .. "^" .. wire_texture(color)
	end
	tile = table.concat({
		tile, "^",
		"area_containers_port.png^",
		"area_containers_", get_port_id_from_name(name), ".png",
	}, "")
	full_def.tiles = {tile}
	register_wall(name, full_def)

end

register_wall("area_containers:object_counter",
	merged_table(object_counter_base, {
		description = S("Misc. Controlling Node for a Container"),
		tiles = {"area_containers_wall.png"},
	}))

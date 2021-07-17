local mesecon_on_color = "#FCFF00"
local mesecon_off_color = "#8A8C00"
local digiline_color = "#4358C0"

local mesecon_maybe = minetest.global_exists("mesecon") and mesecon or {}

local function merged_table(a, b)
	local merged = {}
	for key, value in pairs(a) do
		merged[key] = value
	end
	for key, value in pairs(b) do
		merged[key] = value
	end
	return merged
end

local function wire_texture(color)
	return "(area_containers_wire.png^[colorize:" .. color .. ":255)"
end

local function outer_wire_texture(color)
	return "(area_containers_outer_wire.png^[colorize:" .. color .. ":255)"
end

local base_wall_def = {
	groups = {}, -- not_in_creative_inventory will be added.
	is_ground_content = false,
	diggable = false,
	on_blast = function() end,
}
local function register_wall(local_name, def)
	local name = "area_containers:" .. local_name
	local full_def = merged_table(base_wall_def, def)
	full_def.groups = table.copy(full_def.groups)
	full_def.groups.not_in_creative_inventory = 1
	minetest.register_node(name, full_def)
	if mesecon_maybe.register_mvps_stopper then
		mesecon_maybe.register_mvps_stopper(name)
	end
end

function area_containers.register_nodes()
	local container_tiles = {}
	local container_tile_ids = {"py", "ny", "px", "nx", "pz", "nz"}
	for i, id in ipairs(container_tile_ids) do
		container_tiles[i] = "area_containers_outer_port.png^" ..
			"area_containers_" .. id .. ".png"
	end
	local container_activations = {
		{0, 0, 0, 0}, {0, 0, 0, 1}, {0, 0, 1, 0}, {0, 0, 1, 1},
		{0, 1, 0, 0}, {0, 1, 0, 1}, {0, 1, 1, 0}, {0, 1, 1, 1},
		{1, 0, 0, 0}, {1, 0, 0, 1}, {1, 0, 1, 0}, {1, 0, 1, 1},
		{1, 1, 0, 0}, {1, 1, 0, 1}, {1, 1, 1, 0}, {1, 1, 1, 1},
	}
	for i, name in ipairs(area_containers.all_container_states) do
		local container_def = merged_table(area_containers.container, {
			description = "Area container",
			tiles = table.copy(container_tiles),
			drop = area_containers.all_container_states[1],
		})
		if minetest.global_exists("mesecon") then
			local activation = container_activations[i]
			local wire_choices = {
				outer_wire_texture(mesecon_off_color),
				outer_wire_texture(mesecon_on_color),
			}
			for i, active in ipairs(activation) do
				-- The tile corresponding to this bit:
				local tile_idx = 7 - i
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
			container_def.sounds =
				default.node_sound_metal_defaults()
		end
		container_def.groups = merged_table(container_def.groups or {},
			{cracky = 2})
		if i > 1 then
			container_def.groups.not_in_creative_inventory = 1
		end
		minetest.register_node(name, container_def)
	end
	minetest.register_alias("area_containers:container",
		area_containers.all_container_states[1])

	register_wall("wall", {
		description = "Container wall",
		paramtype = "light",
		light_source = minetest.LIGHT_MAX,
		tiles = {"area_containers_wall.png"},
	})

	register_wall("exit", merged_table(area_containers.exit, {
		description = "Container exit",
		tiles = {"area_containers_wall.png^area_containers_exit.png"},
	}))

	local digiline_texture = "area_containers_wall.png"
	if minetest.global_exists("digiline") then
		digiline_texture = digiline_texture .. "^" ..
			wire_texture(digiline_color)
	end
	register_wall("digiline", merged_table(area_containers.digiline, {
		description = "Container's digiline connection",
		tiles = {digiline_texture},
	}))

	for variant, def in pairs(area_containers.all_port_variants) do
		local full_def = merged_table(area_containers.port, def)
		full_def.description = "Container's mesecon/tube connection"
		local tile = "area_containers_wall.png"
		local mesecons_spec = full_def.mesecons
		if mesecons_spec and mesecon_maybe.state then
			local color = mesecon_off_color
			local on = mesecon_maybe.state.on
			if mesecons_spec and mesecons_spec.conductor and
			   mesecons_spec.conductor.state == on then
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
end

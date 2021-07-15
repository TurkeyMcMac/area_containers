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
	return "(area_containers_wire.png^[colorize:" .. color .. ":255)";
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
	for _, name in ipairs(area_containers.all_container_states) do
		local container_def = merged_table(area_containers.container, {
			tiles = {"area_containers_wall.png"},
		})
		container_def.groups = merged_table(container_def.groups or {},
			{crumbly = 3, soil = 1})
		minetest.register_node(name, container_def)
	end

	register_wall("wall", {
		paramtype = "light",
		light_source = minetest.LIGHT_MAX,
		tiles = {"area_containers_wall.png"},
	})

	register_wall("exit", merged_table(area_containers.exit, {
		tiles = {"area_containers_wall.png^area_containers_exit.png"},
	}))

	register_wall("digiline", merged_table(area_containers.digiline, {
		tiles = {"area_containers_wall.png^" ..
			wire_texture(digiline_color)},
	}))

	for variant, def in pairs(area_containers.all_port_variants) do
		local full_def = merged_table(area_containers.port, def)
		local color = mesecon_off_color
		if full_def.mesecons and full_def.mesecons.conductor and
		   full_def.mesecons.conductor.state == "on" then
			color = mesecon_on_color
	  	end
		full_def.tiles = {table.concat({
			"area_containers_wall.png",
			wire_texture(color),
			"area_containers_port.png",
		}, "^")}
		register_wall("port_" .. variant, full_def)

	end
end

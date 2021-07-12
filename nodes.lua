function merged_table(a, b)
	local merged = table.copy(a)
	for key, value in pairs(b) do
		merged[key] = value
	end
	return merged
end

function area_containers.register_nodes()
	-- Container node definition
	local container_spec = table.copy(area_containers.container)
	container_spec.tiles = {"area_containers_wall.png"}
	container_spec.groups = {
		crumbly = 3,
		soil = 1,
	}
	minetest.register_node("area_containers:container", container_spec)

	-- Information shared by all walls
	local wall_spec_base = {
		paramtype = "light",
		light_source = minetest.LIGHT_MAX,
		is_ground_content = false,
		diggable = false,
		on_blast = function() end,
	}

	-- Regular wall definition
	local wall_spec = table.copy(wall_spec_base)
	wall_spec.tiles = {"area_containers_wall.png"}
	minetest.register_node("area_containers:wall", wall_spec)

	-- Exit wall tile definition
	local exit_spec = merged_table(wall_spec_base, area_containers.exit)
	exit_spec.tiles = {
		"area_containers_wall.png^area_containers_exit.png",
	}
	minetest.register_node("area_containers:exit", exit_spec)

	-- Digiline port definition
	local digiline_spec =
		merged_table(wall_spec_base, area_containers.digiline)
	digiline_spec.tiles = {
		"area_containers_wall.png^area_containers_digiline.png",
	}
	minetest.register_node("area_containers:digiline", digiline_spec)
end

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
	local exit_spec = table.copy(wall_spec_base)
	exit_spec.tiles = {
		"area_containers_wall.png^area_containers_exit.png",
	}
	for key, value in pairs(area_containers.exit) do
		exit_spec[key] = value
	end
	minetest.register_node("area_containers:exit", exit_spec)
end

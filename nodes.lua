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
		tubedevice = 1,
		tubedevice_receiver = 1,
	}
	minetest.register_node("area_containers:container", container_spec)
	if mesecon and mesecon.register_mvps_stopper then
		mesecon.register_mvps_stopper("area_containers:container")
	end

	-- Information shared by all walls
	local wall_spec_base = {
		paramtype = "light",
		light_source = minetest.LIGHT_MAX,
		groups = {not_in_creative_inventory = 1},
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

	-- Pipe definition
	local pipe_spec =
		merged_table(wall_spec_base, area_containers.pipe)
	pipe_spec.tiles = {
		"area_containers_wall.png^area_containers_pipe.png",
	}
	pipe_spec.groups = merged_table(pipe_spec.groups, {
		tubedevice = 1,
		tubedevice_receiver = 1,
	})
	minetest.register_node("area_containers:pipe", pipe_spec)
end

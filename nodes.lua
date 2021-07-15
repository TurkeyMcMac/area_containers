function merged_table(a, b)
	local merged = {}
	for key, value in pairs(a) do
		merged[key] = value
	end
	for key, value in pairs(b) do
		merged[key] = value
	end
	return merged
end

local function register_wall(local_name, def)
	local name = "area_containers:" .. local_name
	local base_def = {
		paramtype = "light",
		light_source = minetest.LIGHT_MAX,
		groups = {},
		is_ground_content = false,
		diggable = false,
		on_blast = function() end,
	}
	local full_def = merged_table(base_def, def)
	full_def.groups.not_in_creative_inventory = 1
	minetest.register_node(name, full_def)
	if minetest.global_exists("mesecon") and
	   mesecon.register_mvps_stopper then
		mesecon.register_mvps_stopper(name)
	end
end

function area_containers.register_nodes()
	local container_def = merged_table(area_containers.container, {
		tiles = {"area_containers_wall.png"},
		groups = {
			crumbly = 3,
			soil = 1,
			tubedevice = 1,
			tubedevice_receiver = 1,
		},
	})
	minetest.register_node("area_containers:container", container_def)

	register_wall("wall", {
		tiles = {"area_containers_wall.png"},
	})

	register_wall("exit", merged_table(area_containers.exit, {
		tiles = {"area_containers_wall.png^area_containers_exit.png"},
	}))

	register_wall("digiline", merged_table(area_containers.digiline, {
		tiles = {"area_containers_wall.png^" ..
			"area_containers_digiline.png"},
	}))

	register_wall("pipe", merged_table(area_containers.pipe, {
		tiles = {"area_containers_wall.png^area_containers_pipe.png"},
		groups = {
			tubedevice = 1,
			tubedevice_receiver = 1,
		},
	}))
end

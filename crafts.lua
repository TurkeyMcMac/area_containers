function area_containers.register_crafts()
	-- I think that crafts silently don't register if the ingredients are
	-- not themselves registered?
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

area_containers = {}

area_containers.settings = {
	y_level_blocks = tonumber(minetest.settings:get(
		"area_containers_y_level_blocks") or 1931),
	spacing_blocks = tonumber(minetest.settings:get(
		"area_containers_spacing_blocks") or 2),
	enable_crafts = minetest.settings:get_bool(
		"area_containers_enable_crafts", true),
}

local modpath = minetest.get_modpath("area_containers")
dofile(modpath .. "/crafts.lua")
dofile(modpath .. "/container.lua")
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/relation.lua")

area_containers.register_nodes()

if area_containers.settings.enable_crafts then
	area_containers.register_crafts()
end

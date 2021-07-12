area_containers = {}

local modpath = minetest.get_modpath("area_containers")
dofile(modpath .. "/allocator.lua")
dofile(modpath .. "/container.lua")
dofile(modpath .. "/nodes.lua")

area_containers.register_nodes()

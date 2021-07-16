area_containers = {}

local modpath = minetest.get_modpath("area_containers")
dofile(modpath .. "/crafts.lua")
dofile(modpath .. "/container.lua")
dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/relation.lua")

area_containers.register_nodes()
area_containers.register_crafts()

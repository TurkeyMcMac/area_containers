--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements basic container stuff.

   area_containers is free software: you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License as published
   by the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   area_containers is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with area_containers. If not, see <https://www.gnu.org/licenses/>.
]]

--[[
   OVERVIEW

   A container node is associated with an inside chamber through its param1 and
   param2. This relation is managed by relation.lua.

   The container lets players teleport into its inside chamber. They can leave
   similarly with the inside exit node. Containers can be locked.

   Port nodes inside the chamber correspond to faces of the container. Pipeworks
   tubes can pass items through the ports. A mesecons signal can conduct between
   the horizontal container faces and the ports.

   The container cannot be broken until it is empty of nodes and objects. While
   the inside's block is active, a special "object counter" node continuously
   tallies the objects so that the number can be checked when one attempts to
   break the container. Despite its name, the object counter may also perform
   other functions.

   Like some other files, this one exports a few tables (e.g. "container") which
   contain callbacks and other technical information for their respective nodes.
   This information is used by nodes.lua.
]]

local use = ...
local S, get_node_maybe_load, blockpos_in_range,
      EXIT_OFFSET, DIGILINE_OFFSET, PORT_OFFSETS,
      CONTAINER_NAME_PREFIX, PORT_NAME_PREFIX = use("misc", {
	"translate", "get_node_maybe_load", "blockpos_in_range",
	"EXIT_OFFSET", "DIGILINE_OFFSET", "PORT_OFFSETS",
	"CONTAINER_NAME_PREFIX", "PORT_NAME_PREFIX",
})
local is_locked, lock_allows_enter,
      set_lock, remove_lock, fill_key = use("lock", {
	"is_locked", "lock_allows_enter",
	"set_lock", "remove_lock", "fill_key",
})
local alloc_relation, free_relation, reclaim_relation,
      set_related_container, get_related_container, get_related_inside,
      get_params_from_inside, get_params_index = use("relation", {
	"alloc_relation", "free_relation", "reclaim_relation",
	"set_related_container", "get_related_container", "get_related_inside",
	"get_params_from_inside", "get_params_index",
})

local exports = {}

exports.container = {}

exports.exit = {}

exports.object_counter = {}

-- Gets the stored count of non-player objects associated with the inside.
local function get_non_player_object_count(inside_pos)
	local inside_meta = minetest.get_meta(inside_pos)
	return inside_meta:get_int("area_containers:object_count")
end

-- Updates the stored count of non-player objects associated with the inside.
-- The new count is returned. This should only be called for active blocks.
local function update_non_player_object_count(inside_pos)
	-- Try to limit updates to active blocks if possible:
	if not minetest.compare_block_status or
	   minetest.compare_block_status(inside_pos, "active") then
		local object_count = 0
		local objects_inside = minetest.get_objects_in_area(
			inside_pos, vector.add(inside_pos, 15))
		for _, object in ipairs(objects_inside) do
			if not object:is_player() then
				object_count = object_count + 1
			end
		end
		local inside_meta = minetest.get_meta(inside_pos)
		inside_meta:set_int("area_containers:object_count",
			object_count)
		return object_count
	end
	return get_non_player_object_count(inside_pos)
end

-- Returns whether there are any nodes or objects in the container.
-- The object count might not be 100% accurate. The node parameter is optional.
local function container_is_empty(pos, node)
	node = node or get_node_maybe_load(pos)
	local name_prefix = string.sub(node.name, 1, #CONTAINER_NAME_PREFIX)
	if name_prefix ~= CONTAINER_NAME_PREFIX then return true end
	-- Invalid containers are empty:
	if node.param1 == 0 and node.param2 == 0 then return true end
	local inside_pos = get_related_inside(node.param1, node.param2)
	-- These represent the area of the inner chamber (inclusive):
	local min_pos = vector.add(inside_pos, 1)
	local max_pos = vector.add(inside_pos, 14)

	-- Detect nodes left inside.
	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{MinEdge = min_edge, MaxEdge = max_edge}
	local data = vm:get_data()
	local c_air = minetest.CONTENT_AIR
	for i in area:iterp(min_pos, max_pos) do
		if data[i] ~= c_air then return false end
	end

	-- Detect objects inside.
	local objects_inside = minetest.get_objects_in_area(
		vector.subtract(min_pos, 1), vector.add(max_pos, 1))
	if #objects_inside > 0 then return false end
	-- Detect non-player objects in unloaded inside chambers:
	if get_non_player_object_count(inside_pos) > 0 then
		return false
	end

	return true
end

-- Sets up the "object counter" controller node at inside_pos. The params encode
-- the relation.
local function set_up_object_counter(inside_pos)
	-- Swap the node to keep the relation metadata:
	minetest.swap_node(inside_pos,
		{name = "area_containers:object_counter"})
	-- Reset the periodically updated data, just in case:
	local meta = minetest.get_meta(inside_pos)
	meta:set_int("area_containers:object_count", 0)
	-- The node checks for objects periodically when active:
	local timer = minetest.get_node_timer(inside_pos)
	timer:start(1)
end

-- Sets up the exit node near inside_pos. The params encode the relation.
local function set_up_exit(inside_pos)
	local pos = vector.add(inside_pos, EXIT_OFFSET)
	minetest.set_node(pos, {name = "area_containers:exit"})
	local meta = minetest.get_meta(pos)
	meta:set_string("infotext", S("Exit"))
end

-- Sets up the digiline node near inside_pos. The params encode the relation.
local function set_up_digiline(inside_pos)
	local pos = vector.add(inside_pos, DIGILINE_OFFSET)
	minetest.set_node(pos, {name = "area_containers:digiline"})
end

-- Removes and cleans up previous inside ports if they are there.
local function remove_previous_ports(inside_pos)
	for _, offset in pairs(PORT_OFFSETS) do
		local pos = vector.add(inside_pos, offset)
		local prev = get_node_maybe_load(pos)
		if string.sub(prev.name, 1, #PORT_NAME_PREFIX) ==
				PORT_NAME_PREFIX then
			minetest.remove_node(pos)
			local prev_def = minetest.registered_nodes[prev.name]
			if prev_def and prev_def.after_dig_node then
				prev_def.after_dig_node(pos, prev)
			end
		end
	end
end

-- Sets up the port nodes near inside_pos. The params encode the relation.
local function set_up_ports(param1, param2, inside_pos)
	for id, offset in pairs(PORT_OFFSETS) do
		local pos = vector.add(inside_pos, offset)
		local name = PORT_NAME_PREFIX .. id .. "_off"
		minetest.set_node(pos, {
			name = name, param1 = param1, param2 = param2,
		})
		local def = minetest.registered_nodes[name]
		if def and def.after_place_node then
			def.after_place_node(pos)
		end
	end
end

-- Creats a chamber with all the necessary nodes related with param1 and param2.
local function construct_inside(param1, param2)
	local inside_pos = get_related_inside(param1, param2)
	-- The min and max provide the guidelines for the walls:
	local min_pos = inside_pos
	local max_pos = vector.add(min_pos, 15)

	remove_previous_ports(inside_pos)

	local vm = minetest.get_voxel_manip()
	local min_edge, max_edge = vm:read_from_map(min_pos, max_pos)
	local area = VoxelArea:new{MinEdge = min_edge, MaxEdge = max_edge}

	-- Make the walls:
	local data = vm:get_data()
	local c_air = minetest.CONTENT_AIR
	local c_wall = minetest.get_content_id("area_containers:wall")
	for z = min_pos.z, max_pos.z do
		for y = min_pos.y, max_pos.y do
			for x = min_pos.x, max_pos.x do
				local content_id = c_air
				if x == min_pos.x or x == max_pos.x or
				   y == min_pos.y or y == max_pos.y or
				   z == min_pos.z or z == max_pos.z then
					content_id = c_wall
				end
				data[area:index(x, y, z)] = content_id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)

	-- Set up the special nodes:
	set_up_object_counter(inside_pos)
	set_up_exit(inside_pos)
	set_up_digiline(inside_pos)
	set_up_ports(param1, param2, inside_pos)
end

-- A set of unique parameter pairs (as two-item lists.) Their inside areas have
-- their emergences queued but are not yet constructed. When the server shuts
-- down, these pending relations must be freed; they would be hard to save. They
-- are removed from the set after being freed, just in case.
local emerging_relations = {}
minetest.register_on_shutdown(function()
	for _, params in pairs(emerging_relations) do
		minetest.log("error", "The area container with param1 = " ..
			params[1] .. " and param2 = " .. params[2] ..
			" had its construction interrupted by the shutdown")
		free_relation(params[1], params[2])
	end
	-- Clear the list in case any emerge callbacks somehow run after this:
	emerging_relations = {}
end)

-- Relates an inside to the container and sets up the inside (asynchronously.)
function exports.container.on_construct(pos)
	-- Make a copy for safety:
	pos = vector.new(pos)

	local node = get_node_maybe_load(pos)

	local param1 = node.param1
	local param2 = node.param2

	if param1 ~= 0 or param2 ~= 0 then
		-- If the relation is set, the container was probably moved by
		-- a piston or something.
		if reclaim_relation(param1, param2) then
			set_related_container(param1, param2, pos)
			return
		else
			minetest.log("error", "Could not reclaim the inside " ..
				"of the area container now located at " ..
				minetest.pos_to_string(pos) .. " with " ..
				"param1 = " .. param1 .. " and param2 = " ..
				param2 .. "; allocating a new inside instead")
		end
	end

	local meta = minetest.get_meta(pos)

	-- Make a broken container; it will be un-broken if all goes to plan:
	meta:set_string("infotext", S("Broken Area Container"))
	minetest.swap_node(pos, {
		name = node.name,
		param1 = 0, param2 = 0,
	})

	param1, param2 = alloc_relation()

	if not param1 then
		minetest.log("error", "Could not allocate an inside when " ..
			"constructing an area container at " ..
			minetest.pos_to_string(pos))
		return
	end

	-- Generate stuff (after emergence, to prevent conflicts with mapgen):
	local emerge_failed = false
	local index = get_params_index(param1, param2)
	emerging_relations[index] = {param1, param2}
	local function after_emerge_block(blockpos, action, blocks_left)
		if action == minetest.EMERGE_ERRORED or
		   action == minetest.EMERGE_CANCELLED then
			-- Don't count out-of-bounds failures:
			emerge_failed = emerge_failed or
				blockpos_in_range(blockpos)
		end

		-- Before more can be done, all blocks must emerge:
		if blocks_left > 0 then return end

		-- Abort if the relation was somehow freed or used up:
		if not emerging_relations[index] then return end

		emerging_relations[index] = nil

		if emerge_failed then
			minetest.log("error", "An emerge failure prevented " ..
				"complete construction of " ..
				"the area container located at " ..
				minetest.pos_to_string(pos) ..
				" with param1 = " .. param1 ..
				" and param2 = " .. param2)
			free_relation(param1, param2)
			return
		end

		-- Check that the node hasn't changed:
		local node_now = get_node_maybe_load(pos)
		if node_now.name ~= node.name or
		   node_now.param1 ~= 0 or node_now.param2 ~= 0 then
			free_relation(param1, param2)
			return
		end

		-- Now actually do the work, at long last:
		construct_inside(param1, param2)
		meta:set_string("infotext", S("Area Container"))
		minetest.swap_node(pos, {
			name = node.name,
			param1 = param1, param2 = param2,
		})
		set_related_container(param1, param2, pos)
	end
	-- Start the emergence:
	local inside_pos = get_related_inside(param1, param2)
	-- Extra blocks are emerged around the center to prevent set_lighting()
	-- calls in mapgen from overwriting param1 values:
	local min_emerge_pos = vector.subtract(inside_pos, 16)
	local max_emerge_pos = vector.add(inside_pos, 16)
	minetest.emerge_area(min_emerge_pos, max_emerge_pos, after_emerge_block)
end

function exports.container.after_place_node(pos, placer)
	if placer then
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name())
	end
end

-- Frees the inside related to the container.
function exports.container.on_destruct(pos)
	-- Only free properly allocated containers (with relation set):
	local node = get_node_maybe_load(pos)
	if node.param1 ~= 0 or node.param2 ~= 0 then
		free_relation(node.param1, node.param2)
	end
end

-- Adds a lock, removes a lock, or creates a new key.
function exports.container.on_punch(pos, node, puncher, ...)
	if node.param1 ~= 0 or node.param2 ~= 0 then
		local meta = minetest.get_meta(pos)
		local item_name = puncher:get_wielded_item():get_name()
		if item_name == "area_containers:lock" then
			if set_lock(pos, puncher) then
				meta:set_string("infotext",
					S("Locked Area Container (owned by @1)",
						meta:get_string("owner")))
				local lock = puncher:get_wielded_item()
				lock:set_count(lock:get_count() - 1)
				puncher:set_wielded_item(lock)
				return
			end
		elseif item_name == "" then
			if remove_lock(pos, puncher) then
				meta:set_string("infotext",
					S("Area Container"))
				puncher:set_wielded_item(
					ItemStack("area_containers:lock"))
				return
			end
		elseif item_name == "area_containers:key_blank" then
			if fill_key(pos, puncher) then
				local key = puncher:get_wielded_item()
				key:set_name("area_containers:key")
				key:get_meta():set_string("description",
					S("Key to @1's Area Container",
						meta:get_string("owner")))
				puncher:set_wielded_item(key)
				return
			end
		end
	end
	return minetest.node_punch(pos, node, puncher, ...)
end

-- Teleports the player into the container.
function exports.container.on_rightclick(pos, node, clicker)
	if (node.param1 ~= 0 or node.param2 ~= 0) and
	   lock_allows_enter(pos, clicker) then
		local inside_pos = get_related_inside(node.param1, node.param2)
		local self_pos = get_related_container(node.param1, node.param2)
		-- Make sure the clicker will be able to get back:
		if self_pos and vector.equals(pos, self_pos) then
			local props = clicker:get_properties() or {}
			local box_min = props.collisionbox or {-0.5, 0, -0.5}
			-- Place the clicker fully inside with some extra space:
			local dest = vector.offset(inside_pos,
				0.5 - math.min(box_min[1] - 0.02, -0.5),
				0.5 - math.min(box_min[2] - 0.02, 0),
				0.5 - math.min(box_min[3] - 0.02, -0.5))
			clicker:set_pos(dest)
		end
	end
	return clicker:get_wielded_item()
end

function exports.container.can_dig(pos)
	-- The lock item must be removed first:
	return not is_locked(pos) and container_is_empty(pos)
end

function exports.container.on_movenode(_from_pos, to_pos)
	local node = get_node_maybe_load(to_pos)
	set_related_container(node.param1, node.param2, to_pos)
end

-- Teleports the player out of the container.
function exports.exit.on_rightclick(pos, _node, clicker)
	local inside_pos = vector.subtract(pos, EXIT_OFFSET)
	local param1, param2 = get_params_from_inside(inside_pos)
	local clicker_pos = clicker and clicker:get_pos()
	if param1 and clicker_pos and
	   clicker_pos.x > inside_pos.x and
	   clicker_pos.x < inside_pos.x + 15 and
	   clicker_pos.y > inside_pos.y and
	   clicker_pos.y < inside_pos.y + 15 and
	   clicker_pos.z > inside_pos.z and
	   clicker_pos.z < inside_pos.z + 15 then
		-- Update the count before the block is deactivated:
		if clicker:is_player() then
			update_non_player_object_count(inside_pos)
		end

		local container_pos = get_related_container(param1, param2)
		if container_pos then
			local props = clicker:get_properties() or {}
			local min_y = (props.collisionbox or {[2] = 0})[2]
			-- Place the clicker fully on top with some extra space:
			local dest = vector.offset(container_pos,
				0, 0.5 - math.min(min_y - 0.02, 0), 0)
			clicker:set_pos(dest)
		end
	end
end

function exports.object_counter.on_timer(pos)
	-- The counter's position is also the inside_pos:
	update_non_player_object_count(pos)
	return true
end

return exports

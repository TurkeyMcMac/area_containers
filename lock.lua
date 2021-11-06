--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It implements container lock functions.

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

   Locks can be added or removed from area containers by container owners or
   people who can bypass protection (henceforth both called "admins".) Others
   entering the container must hold an appropriate key to get in. These keys
   can only be created by admins. Keys are bound to the node for its lifetime.
   If an admin sets the lock on an unowned container, they take ownership.

   This file contains only the business logic. See container.lua for the rest
   of the implementation.
]]

local use = ...
local rng = use("misc", {"rng"})

local exports = {}

-- Returns a unique lock ID.
local function get_next_lock_id()
	-- Generate 64 random bits and encode them in hexadecimal:
	return string.format("%08x%08x",
		rng:next() + 2147483648, rng:next() + 2147483648)
end

-- Returns whether the named player is an admin of the node owned as given.
-- A nil owner means that the node is unowned.
local function user_can_use(player_name, owner)
	return minetest.check_player_privs(player_name, "protection_bypass") or
		player_name == owner
end

-- Returns whether the given node is locked.
function exports.is_locked(pos)
	return minetest.get_meta(pos):contains("area_containers:lock")
end

-- Returns whether the user can enter the node according to the (possible) lock.
-- The user may be wielding a key item.
function exports.lock_allows_enter(pos, user)
	local meta = minetest.get_meta(pos)
	if meta:contains("area_containers:lock") and
	   not user_can_use(user:get_player_name(), meta:get("owner")) then
		local item_meta = user:get_wielded_item():get_meta()
		local lock_try =
			item_meta:get_string("area_containers:lock")
		local lock = meta:get_string("area_containers:lock")
		if lock_try ~= lock then return false end
	end
	return true
end

-- Sets the lock as the user. Returns whether doing so was successful.
function exports.set_lock(pos, user)
	local player_name = user:get_player_name()
	local meta = minetest.get_meta(pos)
	local owner = meta:get("owner")
	if not user_can_use(player_name, owner) then return false end
	if meta:contains("area_containers:lock") then return false end
	if minetest.is_protected(pos, player_name) then
		minetest.record_protection_violation(pos, player_name)
		return false
	end

	meta:set_string("area_containers:lock",
		meta:get("area_containers:lock_inactive") or get_next_lock_id())
	meta:set_string("area_containers:lock_inactive", "")
	-- Take ownership if it's unowned:
	if not owner then meta:set_string("owner", player_name) end
	return true
end

-- Removes the lock as the user. Returns whether doing so was successful.
function exports.remove_lock(pos, user)
	local player_name = user:get_player_name()
	local meta = minetest.get_meta(pos)
	local owner = meta:get("owner")
	if not user_can_use(player_name, owner) then return false end
	if not meta:contains("area_containers:lock") then return false end
	if minetest.is_protected(pos, player_name) then
		minetest.record_protection_violation(pos, player_name)
		return false
	end

	meta:set_string("area_containers:lock_inactive",
		meta:get_string("area_containers:lock"))
	meta:set_string("area_containers:lock", "")
	return true
end

-- Sets up the user's wielded item as a key to the lock. Returns whether
-- doing so was successful.
function exports.fill_key(pos, user)
	local meta = minetest.get_meta(pos)
	if not user_can_use(user:get_player_name(), meta:get("owner")) then
		return false
	end
	if not meta:contains("area_containers:lock") then return false end

	local key = user:get_wielded_item()
	key:get_meta():set_string("area_containers:lock",
		meta:get_string("area_containers:lock"))
	return user:set_wielded_item(key)
end

return exports

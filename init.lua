--[[
   Copyright (C) 2021  Jude Melton-Houghton

   This file is part of area_containers. It initializes basic stuff and
   calls the code from the other source files.

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

local dep_statuses = {init = "loading"} -- init.lua cannot be use'd.

-- dep is the name of a script file without ".lua". If it has not yet been used,
-- the script is run with this function as its argument and its return value is
-- recorded. If it has been used already, the recorded value does not change.
-- If the keys argument is nil, then the recorded value is returned. Otherwise,
-- a list of values is returned. These values are parallel to the keys list.
-- Each is the result of indexing the recorded script return value with the
-- corresponding key (indexing errors here are not caught.)
local function use(dep, keys)
	assert(dep_statuses, "use() called after registration time")
	local returned
	local status = dep_statuses[dep]
	if type(status) == "table" then
		-- The value is kept in a table in case it is nil:
		returned = status[1]
	else
		assert(status ~= "loading", "Circular dependency with use()")
		dep_statuses[dep] = "loading"
		local path = minetest.get_modpath("area_containers") .. "/" ..
			dep .. ".lua"
		returned = assert(loadfile(path))(use)
		dep_statuses[dep] = {returned}
	end

	if keys then
		local values = {}
		for i, key in ipairs(keys) do
			values[i] = returned[key]
		end
		-- The location of unpack() may depend on the Lua version:
		local unpack = unpack or table.unpack
		return unpack(values, 1, #keys)
	else
		return returned
	end
end

if use("settings", {"enable_crafts"}) then
	use("crafts")
end
use("items")
use("nodes")
use("protection")

-- No loading after registration time:
dep_statuses = nil

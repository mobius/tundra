-- Copyright 2010 Andreas Fredriksson
--
-- This file is part of Tundra.
--
-- Tundra is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Tundra is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Tundra.  If not, see <http://www.gnu.org/licenses/>.

-- glob.lua - Glob syntax elements for declarative tundra.lua usage

module(..., package.seeall)

local native = require "tundra.native"
local util = require "tundra.util"
local path = require "tundra.path"
local decl = require "tundra.decl"

local ignored_dirs = util.make_lookup_table { ".git", ".svn", "CVS" }

local function glob(directory, recursive, filter_fn)
	local result = {}
	local function dir_filter(dir_name)
		if not recursive or ignored_dirs[dir_name] then
			return false
		end
		return true
	end
	for _, path in ipairs(native.walk_path(directory, dir_filter)) do
		if filter_fn(path) then
			result[#result + 1] = path
		end
	end
	return result
end

-- Glob syntax - Search for source files matching extension list
--
-- Synopsis:
--   Glob {
--      Dir = "...",
--      Extensions = { ".ext", ... },
--      [Recursive = false,]
--   }
--
-- Options:
--    Dir = "directory" (required)
--    - Base directory to search in
--
--	  Extensions = { ".ext1", ".ext2" } (required)
--	  - List of file extensions to include
--
--	  Recursive = boolean (optional, default: true)
--	  - Specified whether to recurse into subdirectories
function Glob(args)
	local recursive = args.Recursive
	if type(recursive) == "nil" then
		recursive = true
	end
	local extensions = assert(args.Extensions)
	local ext_lookup = util.make_lookup_table(extensions)
	return glob(args.Dir, recursive, function (fn)
		local ext = path.get_extension(fn)
		return ext_lookup[ext]
	end)
end

-- FGlob syntax - Search for source files matching extension list with
-- configuration filtering
--
-- Usage:
--   FGlob {
--       Dir = "...",
--       Extensions = { ".ext", .... },
--       Filters = {
--         { Pattern = "/[Ww]in32/", Config = "win32-*-*" },
--         { Pattern = "/[Dd]ebug/", Config = "*-*-debug" },
--         ...
--       },
--       [Recursive = false],
--   }
local function FGlob(args)
	-- Use the regular glob to fetch the file list.
	local files = Glob(args)
	local pats = {}
	local result = {}

	-- Construct a mapping from { Pattern = ..., Config = ... }
	-- to { Pattern = { Config = ... } } with new arrays per config that can be
	-- embedded in the source result.
	for _, fitem in ipairs(args.Filters) do
		local tab = { Config = assert(fitem.Config) }
		pats[assert(fitem.Pattern)] = tab
		result[#result + 1] = tab
	end

	-- Traverse all files and see if they match any configuration filters. If
	-- they do, stick them in matching list. Otherwise, just keep them in the
	-- main list. This has the effect of returning an array such as this:
	-- {
	--   { "foo.c"; Config = "abc-*-*" },
	--   { "bar.c"; Config = "*-*-def" },
	--   "baz.c", "qux.m"
	-- }
	for _, f in ipairs(files) do
		local filtered = false
		for filter, list in pairs(pats) do
			if f:match(filter) then
				filtered = true
				list[#list + 1] = f
				break
			end
		end
		if not filtered then
			result[#result + 1] = f
		end
	end
	return result
end

decl.add_function("Glob", Glob)
decl.add_function("FGlob", FGlob)


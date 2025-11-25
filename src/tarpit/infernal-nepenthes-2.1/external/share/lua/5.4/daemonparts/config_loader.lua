#!/usr/bin/env lua5.4


---
-- The config_loader module provides a way to define a configuration
-- file's schema. It provides a means to force that values must exist
-- in a file, that values have the correct data type, that they have
-- default values, and that values that are not defined to exist are
-- rejected.
--
-- No constraints are imposed on the file format. By default, to parse
-- the file dofile() is called, causing the format to be basic Lua. This
-- can be overriden to load anything desired - JSON, YAML, XML, etc.
--
-- Multiple configuration files can be 'stacked' together in a priorty
-- chain, and/or allowing scanning 'config.d' style directories to
-- be implemented.
--
-- Normally the configuration spec is implemented as a singleton that
-- then calls these routines.
--
-- @module daemonparts.config_loader
--
local _M = {}


---
-- Reset configuration to defaults - as if no files have been loaded.
--
-- Be careful calling this if your program uses default_nil() - values
-- configured that way WILL become nil after a reset.
--
function _M.reset( t )

	local schema = getmetatable(t).schema
	assert( type(schema) == 'table', "No configuration schema on this table" )

	for k, v in pairs( schema ) do
		t[k] = v.reset()
	end

end


---
-- Load and verify a given configuration file. If any values in the
-- file do not meet specifications, error() will be called.
--
function _M.load_string( t, confdata )

	local mt = getmetatable(t)
	local schema = mt.schema
	assert( type(schema) == 'table', "No configuration schema on this table" )

	local x

	if mt.parse_function then
		x = assert(mt.parse_function(confdata))
	else
		x = load( confdata, 'confdata', 't' )()
	end

	for k, v in pairs( x ) do

		if not schema[k] then
			error("Unknown configuration name: " ..  tostring(k))
		end

		t[k] = schema[k].set( k, t[k], v )

	end

	return true
end


---
-- Load and verify a given configuration file. If any values in the
-- file do not meet specifications, error() will be called.
--
function _M.loadconfig( t, path )

	local mt = getmetatable(t)
	local schema = mt.schema
	assert( type(schema) == 'table', "No configuration schema on this table" )

	local f <close>, err = io.open( path, "r" )
	if not f then
		return false, err
	end

	local x

	if mt.parse_function then

		local res, err2 = pcall(function()
			local data = assert(f:read("*all"))
			x = assert(mt.parse_function(data))
		end)

		if not res then
			print("Failed load:", err2)
			return false, err2
		end
	else
		x = dofile( path )
	end

	for k, v in pairs( x ) do

		if not schema[k] then
			error("Unknown configuration name: " ..  tostring(k))
		end

		t[k] = schema[k].set( k, t[k], v )

	end

	return true
end


--
-- Macros that implement scalar type definitions.
--
local basic_types = {
	'string',
	'number',
	'boolean'
}

for i, value_type in ipairs( basic_types ) do	-- luacheck: ignore 213

	--
	-- Comments here in this macro will explain the internal API of
	-- the schema definitions. All possible types need to implement
	-- almost all of these functions.
	--
	_M[value_type] = function ( default )
		return {

			--
			-- "is_typed" tells the construct function (below) that
			-- this table is already a schema definition, and not to
			-- build one.
			--
			is_typed = true,

			--
			-- Says that yes, this is a scalar and not a compound type.
			--
			is_scalar = true,


			--
			-- "is_meta" indicates that this is a setting for the
			-- config_loader, and not a configuration element for the
			-- program calling config_loader.
			--
			-- First use case, and a good example, is specifying a
			-- function to call to parse the configuration file.
			--
			is_meta = false,

			--
			-- Debugging function: identify what type this schema
			-- definition represents.
			--
			is = function()
				return value_type
			end,

			--
			-- Used by variable-sized tables (arrays, etc) to expand
			-- their schema as new elements are added.
			--
			clone = function()
				return _M[value_type]( default )
			end,

			--
			-- Returns this part of the configuration to it's original,
			-- config not loaded state.
			--
			reset = function()
				return default
			end,

			--
			-- Integrate data from the configuration file into the
			-- defaults.
			--
			set = function( path, conf, value )	-- luacheck: ignore 212
				if type(value) ~= value_type then
					error("Incorrect data type for " .. path .. " - should be: " .. value_type)
				end

				return value
			end,

			--
			-- Validity checks to perform after the configuration is
			-- fully loaded.
			--
			verify = function() end

		}
	end

end


--
-- Shortcut to determine which constructor to use to generate the
-- schema if one is not provided. Makes definitions cleaner and easier
-- to read.
--
local function construct( val )

	if type(val) == 'string' then
		return _M.string( val )
	elseif type(val) == 'number' then
		return _M.number( val )
	elseif type(val) == 'boolean' then
		return _M.boolean( val )
	end

	-- meta setting, which are quickly discarded.
	if val.is_meta then
		return val
	end

	--print(pl.dump(val))

	-- table type; check if it's preconstructed
	if val.is_typed then
		return val.clone()
	end

	-- ordinary table
	return _M.table( val )

end


---
-- Creates a table definition that is an ordinary Lua table.
-- the values found within are assumed to be default values.
--
function _M.table( tab )

	local schema = {}

	for k, v in pairs(tab) do
		schema[k] = construct( v )
	end

	return {

		is_typed = true,

		is = function()
			return 'basic table'
		end,

		clone = function()
			return _M.table( tab )
		end,

		reset = function()
			local ret = {}

			for k, v in pairs( schema ) do
				ret[k] = v.reset()
			end

			return ret
		end,

		set = function( path, conf, data )

			for k, v in pairs( data ) do
				assert(schema[k], "Unknown setting name: " .. path .. '.' .. tostring(k))
				conf[k] = schema[k].set( path .. '.' .. k, conf[k], v )
			end

			return conf
		end,

		verify = function( path )
			for k, v in pairs(schema) do
				v.verify( path .. '.' .. tostring(k) )
			end
		end
	}

end


--
-- Creates tables that contain numerically index values of the
-- specified type.
--
function _M.array( tab )

	local schema = {}
	assert(#tab > 0, 'Empty Array Table Schema')

	for i, v in ipairs( tab ) do
		schema[ i ] = construct( v )

		if i > 1 then
			if schema[1].is() ~= schema[i].is() then
				error("Type mismatch in array")
			end
		end
	end


	return {

		is_typed = true,

		is = function()
			return 'array table'
		end,

		clone = function()
			return _M.array( tab )
		end,

		reset = function()
			local ret = {}

			for i, v in ipairs( schema ) do
				ret[i] = v.reset()
			end

			return ret
		end,

		set = function( path, conf, data )

			local max_i = 0
			for i, v in ipairs( data ) do
				if not schema[i] then
					schema[i] = schema[1].clone()
					conf[i] = schema[i].reset()
				end

				conf[i] = schema[i].set( path .. '.' .. i, conf[i], v )
				max_i = i + 1
			end

			-- delete defaults that are greater than the new incoming
			-- array.
			if #conf > max_i then
				for i = max_i, #conf do		-- luacheck: ignore 213
					table.remove(conf, #conf)
				end
			end

			return conf
		end,

		verify = function( path )
			for i in ipairs( schema ) do
				schema[i].verify( path .. '.' .. tostring(i) )
			end
		end
	}

end


--
-- Creates tables that are string values mapping to the value 'true'.
--
function _M.lookup( tab )

	local schema = {}

	for i, v in ipairs( tab ) do
		local vt = construct( v )
		assert( vt.is_scalar, "Invalid data in lookup table ( is " .. vt.is() .. ", must be a scalar )")
		schema[ i ] = vt

		if i > 1 then
			if schema[1].is() ~= schema[i].is() then
				error("Mismatched types in lookup table")
			end
		end
	end

	local original_size = #schema
	assert(original_size > 0, 'Empty Lookup Table Schema')

	return {

		is_typed = true,

		is = function()
			return 'lookup table'
		end,

		clone = function()
			return _M.lookup( tab )
		end,

		reset = function()
			local ret = {}

			for i, v in ipairs( schema ) do
				if i <= original_size then
					local value, is_real = v.reset()
					if value then
						ret[ v.reset() ] = true
					else
						assert(is_real, 'Schema reset error')
					end
				end
			end

			return ret
		end,

		set = function( path, conf, data )	-- luacheck: ignore 212
			local ret = {}

			for i, v in ipairs( data ) do
				if not schema[i] then
					schema[i] = schema[1].clone()
				end

				ret[v] = true
			end

			return ret
		end,

		verify = function()
			-- All scalars, always not nil - no problems can exist
			return
		end

	}

end


---
-- Creates a value that is valid for configuration files to set,
-- but is nil in default conditions.
--
function _M.default_nil( valtype )

	local schema
	local scalars = {
		['string'] = true,
		['number'] = true,
		['boolean'] = true
	}

	if scalars[ valtype ] then
		schema = _M[ valtype ]()
	else
		schema = construct( valtype )
	end

	return {

		is_typed = true,
		is_scalar = schema.is_scalar,

		is = function()
			return schema.is() .. ' (default nil)'
		end,

		clone = function()
			return _M.default_nil( schema )
		end,

		reset = function()
			return nil, true
		end,

		set = function( path, conf, val )	-- luacheck: ignore 212

			-- should only happen with compound types like tables;
			-- since one doesn't exist (it's null), it needs to be
			-- created.
			if not conf then
				conf = schema.reset()
			end

			return schema.set( path, conf, val )

		end,

		verify = function( path )
			schema.verify( path )
		end
	}

end


--
-- Creates a value with no default but must be set; ie, is an error
-- to not exist. Likely rare to use.
--
function _M.not_nil( valtype )

	local unset = true

	local schema
	local scalars = {
		['string'] = true,
		['number'] = true,
		['boolean'] = true
	}

	if scalars[ valtype ] then
		schema = _M[ valtype ]()
	else
		schema = construct( valtype )
	end

	return {

		is_typed = true,
		is_scalar = schema.is_scalar,

		is = function()
			return schema.is() .. ' (not nil)'
		end,

		clone = function()
			return _M.not_nil( schema )
		end,

		reset = function()
			unset = true
			return nil
		end,

		set = function( path, conf, val )

			if not conf then
				conf = schema.reset()
			end

			unset = false
			return schema.set( path, conf, val )

		end,

		verify = function( path )
			if unset then
				error("Value must be set: " .. tostring(path))
			end

			schema.verify( path )
		end
	}

end


---
-- Creates a value that must be a string; additionally it is normalized
-- into a valid filesystem path.
--
-- @param default string
--
function _M.filesystem_path( default )

	return {
		is_typed = true,
		is_scalar = true,

		is = function()
			return 'path to a file'
		end,

		clone = function()
			return _M.filesystem_path( default )
		end,

		reset = function()
			return default
		end,

		set = function( path, conf, val )	-- luacheck: ignore 212
			if type(val) ~= 'string' then
					error("Incorrect data type for " .. path .. " - should be filesystem path")
			end

			--
			-- Enforce a trailing slash.
			--
			if not val:match('%/$') then
				val = val .. '/'
			end

			return val
		end,

		verify = function() end
	}

end


---
-- Sets a parse function to call. By default, it uses dofile(), causing
-- the expected configuration file to be a Lua script that returns a
-- table. Setting this to json.decode(), as an example, sets the expected
-- file format to JSON.
--
-- Should be placed in the top level of the schema. Placing this within
-- a compound data type will cause undefined behavior.
--
-- @param func File parser function to utilize.
--
function _M.parse_function( func )

	return {
		is_typed = true,
		is_meta = true,

		is = function()
			return 'Parser Function'
		end,

		set = function( t )
			t.parse_function = func
		end
	}

end


---
-- Convert a table with a schema definition into a configuration parser
-- singleton. Calling this should be the last step before loading a file.
--
-- @param tab Table containing schema definition
-- @return Table containing a configuration singleton
--
function _M.prepare( tab )

	local s = {}
	local meta_settings = {}

	--
	-- Save the schema so we can reset/reload and/or include
	-- multiple files.
	--
	for k, v in pairs( tab ) do
		local typed = construct( v )
		tab[k] = nil

		if typed.is_meta then
			meta_settings[ #meta_settings + 1 ] = typed
		else
			s[k] = typed
		end
	end

	local mt = {

		schema = s,

		__call = function( t, paths )

			if type(paths) == 'string' then
				local res, err = _M.loadconfig(t, paths)

				if res then
					for k, v in pairs( s ) do
						v.verify( k )
					end
				end

				return res, err

			--elseif type(paths) == 'table' then
				--for i, path in ipairs(paths) do	-- luacheck: ignore 213
					--if _M.loadconfig(t, path) then
						--return
					--end
				--end
			else
				error("Unknown config type")
			end

		end
	}

	for _, v in ipairs( meta_settings ) do
		v.set( mt )
	end

	setmetatable( tab, mt )
	_M.reset( tab )
	return tab

end

return _M

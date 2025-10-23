#!/usr/bin/env lua5.4

local basexx = require 'basexx'
local config = require 'components.config'

local _M = {}

---
-- Pull the unique instance seed. Try to persist it if filesystem
-- permissions allow it.
--
function _M.get()

	--
	-- We allow this to fail silently, and fall back to generating
	-- a new one.
	--
	local function get_file()
		local contents
		pcall(function()

			local f <close> = assert( io.open( config.seed_file, 'r' ))
			contents = f:read("*all")

		end)

		if not contents then
			return nil
		end

		if #contents == 0 then
			return nil
		end

		return contents
	end

	--
	-- We let this crash out, as it's really needed
	--
	local function get_random()
		local f <close> = assert( io.open( '/dev/random', 'r' ))
		local contents = f:read( 32 )

		--
		-- Very difficult to trigger
		--
		-- luacov: disable
		if #contents == 0 then
			return nil
		end
		-- luacov: enable

		return basexx.to_hex(contents)
	end


	--
	-- Try to save; allowed to silently fail. Nepenthes will work
	-- correctly and simply change it's output every startup.
	--
	local function save_file( contents )
		return pcall(function()

			local f <close> = assert( io.open( config.seed_file, 'w+' ))
			f:write( contents )

		end)
	end


	local c = get_file()
	if not c then
		c = get_random()
	end

	save_file(c)
	return c

end


return _M

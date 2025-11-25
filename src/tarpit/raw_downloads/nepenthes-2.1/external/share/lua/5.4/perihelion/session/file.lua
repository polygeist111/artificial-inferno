#!/usr/bin/env lua5.3


local unix = require "unix"


--
-- Filesystem storage module.
--
-- Should work nicely with any multithreaded or forking application
-- server.
--
-- Might work for a cluster of servers backed by NFS. But things
-- are so implementation dependant, that it very well might not work
-- for that case.
--
local _M = {}



function _M.new( config )

	local path = config.path or "/tmp/perihelion-session"

	local function location( id, dir )
		if dir then
			return string.format(
				"%s/%s/%s",
					path,
					id:sub(1, 1),
					id:sub(2, 2)
			)
		else
			return string.format(
				"%s/%s/%s/%s",
					path,
					id:sub(1, 1),
					id:sub(2, 2),
					id
			)
		end
	end

	local function temp()
		return string.format(
			"%s/tmp/%.6f-%d",
				path,
				unix.gettimeofday(),
				unix.arc4random()
		)
	end


	assert(unix.mkpath(path .. '/tmp'))

	return {
		encoder = assert(config.encoder, "No encoder provided"),
		decoder = assert(config.decoder, "No decoder provided"),

		store = function( this, id, val )
			local scratch = temp()
			local f = io.open(scratch, "w")
			f:write(this.encoder( val ))
			f:close()

			local dir = location(id, true)
			assert(unix.mkpath(dir))
			assert(unix.rename(scratch, location(id)))
		end,

		retrieve = function( this, id )
			local s = unix.stat( location(id) )
			if not s then
				return
			end

			local f = io.open(location(id), "r")
			local ret = this.decoder( f:read("*all") )
			f:close()

			return ret
		end,

		purge = function( this, id )	-- luacheck: ignore 212
			unix.unlink(location(id))
		end
	}

end

return _M

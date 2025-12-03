#!/usr/bin/env lua5.3


--
-- In-memory session storage module.
--
-- Use cases are limited: Mainly single-threaded, single Lua state
-- servers such as Xavante or Lua-http without forking.
--
local _M = {}


function _M.new()

	return {
		data = {},

		store = function( this, id, val )
			this.data[ id ] = val
		end,

		retrieve = function( this, id )
			return this.data[ id ]
		end,

		purge = function( this, id )
			this.data[id] = nil
		end
	}

end

return _M

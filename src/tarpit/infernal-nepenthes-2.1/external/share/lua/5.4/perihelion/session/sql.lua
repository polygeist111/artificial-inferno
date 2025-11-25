#!/usr/bin/env lua5.3


local sqltable = require "sqltable"

--
-- SQL database session storage module.
--
-- Technically agnostic as to which database it is stored in;
-- anything supported by SqlTable will work nicely, assuming
-- the schema is ported.
--
-- Mostly tested against SQLite.
--
local _M = {}

function _M.new( config )

	local db = sqltable.connect( config.database )
	local ds = db:open_table {
		name = config.table_name,
		key = config.table_key
	}

	return {
		db = db,
		data = ds,

		encoder = assert(config.encoder, "No encoder provided"),
		decoder = assert(config.decoder, "No decoder provided"),

		store = function( this, id, val )
			local expire = val.expire
			val.expire = nil

			this.data[ id ] = {
				expire = expire,
				sdata = this.encoder( val )
			}
		end,

		retrieve = function( this, id )
			local row = this.data[ id ]

			if not row then
				return nil
			end

			local ret = this.decoder( row.sdata )
			ret.expire = row.expire

			return ret
		end,

		purge = function( this, id )
			this.data[id] = nil
		end
	}

end

return _M

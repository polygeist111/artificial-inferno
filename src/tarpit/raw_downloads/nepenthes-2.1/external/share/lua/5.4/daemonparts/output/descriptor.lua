#!/usr/bin/env lua5.3


local unix = require 'unix'

---
-- Socket/pipe/etc output module.
--
-- Writes logs directly to a given file descriptor. Calling output.reset()
-- flushes the buffer but otherwise does nothing.
--
-- @module daemonparts.output.descriptor
--
local _M = {}

---
-- Sets up the descriptor output module.
--
-- @param descriptor File descriptor to log to. Must be a Lua file handle,
--					or an integer unix file descriptor.
--
function _M.setup( descriptor )

	local descr = descriptor
	local ret = {}

	if type(descriptor) == 'number' then
		descr = unix.fdopen( descriptor )
	end


	local function log_print( ... )
		local args = {}
		for i, v in ipairs({ ... }) do
			args[i] = tostring(v)
		end

		local line = string.format("%s",
				table.concat(args, ' ')
			)

		descr:write(line .. '\n')
		descr:flush()
	end

	function ret.reset_hook()
		descr:flush()
	end

	function ret.info( ... )
		log_print(...)
	end

	function ret.notice( ... )
		log_print("NOTICE:", ... )
	end

	function ret.debug( ... )
		log_print("DEBUG:", ... )
	end

	function ret.warning( ... )
		log_print("WARNING:", ... )
	end

	function ret.error( ... )
		log_print("ERROR:", ... )
	end

	return ret

end

return _M

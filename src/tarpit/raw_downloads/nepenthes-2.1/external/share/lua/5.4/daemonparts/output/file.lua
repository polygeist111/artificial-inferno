#!/usr/bin/env lua5.3


---
-- File output module.
--
-- Writes logs directly to a specific file on disk. Calling
-- output.reset() flushes, closes, and reopens the file, allowing for
-- logs to be rotated. Log messages are prepended with a timestamp
-- before being written.
--
-- @module daemonparts.output.file
--
local _M = {}

---
-- Sets up the file output module.
--
-- @param file Path to file to log to. If this cannot be opened
--				read-write, an error is thrown.
--
function _M.setup( file )

	local logfile = assert( io.open(file, "a") )
	local ret = {}


	local function log_print( ... )
		local args = {}
		for i, v in ipairs({ ... }) do
			args[i] = tostring(v)
		end

		local line = string.format("%s %s\n",
				os.date('%Y-%m-%d %H:%M:%S'),
				table.concat(args, ' ')
			)

		logfile:write(line)
		logfile:flush()
	end

	function ret.reset_hook()
			logfile:close()
			logfile = assert( io.open(file, "a") )
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

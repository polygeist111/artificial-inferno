#!/usr/bin/env lua5.3


---
-- Table output module
--
-- Log messages are appended to a numerically indexed table, in the
-- format of a log_message object. Clearing the table before memory
-- runs out is left to the calling programmer.
--
-- The original intent was unit testing, but has occasionally found
-- itself useful in production contexts.
--
-- @module daemonparts.output.table
--
local _M = {}

---
-- A written log message
--
-- @table log_message
-- @field message Contents of a log message
-- @field timestamp When the message was written, as given by os.time().
-- @field level Severity level of the log messsage
--

---
-- Sets up the table output module.
--
-- @param tab Table log messages are appended to
--
function _M.setup( tab )

	local ret = {}

	local function log_print( level, ... )
		local args = {}
		for i, v in ipairs({ ... }) do
			args[i] = tostring(v)
		end

		local line = string.format("%s",
				table.concat(args, ' ')
			)

		tab[ #tab + 1 ] = {
			timestamp = os.time(),
			level = level,
			message = line
		}
	end

	function ret.reset_hook()
	end

	function ret.info( ... )
		log_print('info', ...)
	end

	function ret.notice( ... )
		log_print("notice", ... )
	end

	function ret.debug( ... )
		log_print("debug", ... )
	end

	function ret.warning( ... )
		log_print("warning", ... )
	end

	function ret.error( ... )
		log_print("error", ... )
	end

	return ret

end

return _M

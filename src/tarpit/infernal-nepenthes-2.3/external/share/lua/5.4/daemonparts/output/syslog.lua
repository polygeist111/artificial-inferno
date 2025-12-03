#!/usr/bin/env lua5.3

local unix = require 'unix'


---
-- Syslog output module
--
-- Log messages are set to the system log using the syslog() call.
-- Also calls openlog() and closelog() as appropriate.
--
-- @module daemonparts.output.syslog
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
-- Sets up the syslog output module.
--
-- @param facility the System log facility to log to
-- @param tag Tag to send - ie, the daemon name
--
function _M.setup( facility, tag )

	assert(_M.facility[facility], "Unknown syslog facility")
	assert(tag, "Specify syslog tag")

	local ret = {}

	local function log_print( ... )
		local args = {}
		for i, v in ipairs({ ... }) do
			args[i] = tostring(v)
		end

		return string.format("%s",
				table.concat(args, ' ')
			)
	end

	unix.openlog( tag, _M.LOG_PID, _M.facility[facility] )

	function ret.reset_hook()
		unix.closelog()
		unix.openlog( tag, _M.LOG_PID, _M.facility[facility] )
	end

	function ret.info( ... )
		unix.syslog( unix.LOG_INFO, log_print(...) )
	end

	function ret.notice( ... )
		unix.syslog( unix.LOG_NOTICE, log_print(...) )
	end

	function ret.debug( ... )
		unix.syslog( unix.LOG_DEBUG, log_print(...) )
	end

	function ret.warning( ... )
		unix.syslog( unix.LOG_WARNING, log_print(...) )
	end

	function ret.error( ... )
		unix.syslog( unix.LOG_ERR, log_print(...) )
	end

	return ret

end


---
-- A list of available log facilities.
--
_M.facility = {
	auth = unix.LOG_AUTH,
	authpriv = unix.LOG_AUTHPRIV,
	cron = unix.LOG_CRON,
	daemon = unix.LOG_DAEMON,
	ftp = unix.LOG_FTP,
	kern = unix.LOG_KERN,
	lpr = unix.LOG_LPR,
	mail = unix.LOG_MAIL,
	news = unix.LOG_NEWS,
	syslog = unix.LOG_SYSLOG,
	user = unix.LOG_USER,
	uucp = unix.LOG_UUCP,
	local0 = unix.LOG_LOCAL0,
	local1 = unix.LOG_LOCAL1,
	local2 = unix.LOG_LOCAL2,
	local3 = unix.LOG_LOCAL3,
	local4 = unix.LOG_LOCAL4,
	local5 = unix.LOG_LOCAL5,
	local6 = unix.LOG_LOCAL6,
	local7 = unix.LOG_LOCAL7
}


return _M

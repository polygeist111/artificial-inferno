#!/usr/bin/env lua5.3


--
-- Prevent other modules from monkey-patching.
-- Likely unnecessary.
--
local print = print


---
-- Output module provides a simple re-targetable logging structure.
--
-- Functions @{daemonparts.output.debug}, @{daemonparts.output.info},
-- @{daemonparts.output.notice}, @{daemonparts.output.warning}, and
-- @{daemonparts.output.error} generate output to standard out by
-- default.
--
-- All arguments are coerced to a string, and then concatened
-- with spaces in between, before output.
--
--
-- Calling @{switch} will switch the output to the given output
-- mode, globally throughout the running program.
--
-- This allows a daemon to start by logging to a controlling terminal,
-- and then switch to a log file after forking into the background.
--
-- This module is also a singleton: only one logging output can exist
-- at any time. Calling @{switch} redirects all calls to output,
-- globally within the program.
--
-- If individual reentrant streams are desired, call @{new}. It takes
-- the same arguments as @{switch} and returns a logger object, with
-- the same methods.
--
-- @module daemonparts.output
--
local _M = {
	print = print
}



---
-- Acceptable filter levels. These roughly correspond to the
-- identically named syslog severity levels.
--
-- No special processing is done for any level, except used for
-- filtering. See @{daemonparts.output.filter}
--
-- @table levels
--
local levels = {
	debug = 1,		-- Debugging output, noisy
	info = 2,		-- Normal output
	notice = 3,		-- Only Significant changes
	warning = 4,	-- Only warnings
	error = 5		-- Only critical errors
}


--
-- Standard Output, by default a wrapper around print()
--
local standard = {}


---
-- Normal output; nothing special, sometimes filtered.
-- @function info
--
function standard.info( ... )
	_M.print(...)
end


---
-- Info: elevated conditions worthy of attention
-- @function notice
--
function standard.notice( ... )
	_M.print("NOTICE:", ... )
end


---
-- Debug: Noisy output, filtered out by default.
-- @function debug
--
function standard.debug( ... )
	_M.print("DEBUG:", ... )
end


---
-- Human attention needed
-- @function warning
--
function standard.warning( ... )
	_M.print("WARNING:", ... )
end


---
-- Error: Critical conditions, usually a failure
-- @function error
--
function standard.error( ... )
	_M.print("ERROR:", ... )
end


---
-- Changes filtering level. Messages at the provided severity - as
-- well as messages of higher severity are output; those lower in
-- level are supressed. See @{daemonparts.output.levels} for valid
-- levels.
--
-- Returns nothing on success, throws error if an unknown level is
-- specified.
--
-- @param level Minimum outputted level.
--
function _M.filter( level )

	if not levels[ level ] then
		error("Unknown filter threshold")
	end

	_M.level = level

end


---
-- Reset the state of the module.
--
-- By default, resets to standard 'print' function output and sets
-- filter level to 'info'. Other output modules may have different
-- effects.
--
-- Takes no arguments and returns nothing on success.
--
function _M.reset()

	_M.print = print
	_M.level = 'info'

	for level in pairs(levels) do
		_M[level] = function( ... )
			if levels[ level ] >= levels[ _M.level ] then
				_M.module[ level ]( ... )
			end
		end
	end

	if _M.module.reset_hook then
		_M.module.reset_hook()
	end

end


---
-- Switches to a different form of output.
--
-- Returns nothing on success. Raises error if output type is not
-- known, or the called output module cannot parse it's given params.
--
-- @param to Name of output module to switch to. Currently, only
-- 'file' and 'descriptor' exist. See @{daemonparts.output.file} and
-- @{daemonparts.output.descriptor}. If 'to' is a table, it is assumed
-- to be an output plugin, containing functions that handle writing
-- output.
--
function _M.switch( to, ... )

	if type(to) == 'table' then
		_M.module = to
		return
	end

	local mod_name = 'daemonparts.output.' .. tostring(to)
	local res, out = pcall(require, mod_name)

	if not res then
		error("Output module not known")
	end

	_M.module = out.setup( ... )
	_M.reset()

end


---
-- Creates a re-entrant instance of a logging object.
--
-- Returns a table on success containing the same methods as
-- @{daemonparts.output}. Raises error if output type is not
-- known, or the called output module cannot parse it's given params.
--
-- @param to Name of output module to switch to. Currently, only
-- 'file' and 'descriptor' exist. See @{daemonparts.output.file} and
-- @{daemonparts.output.descriptor}. If 'to' is a table, it is assumed
-- to be an output plugin, containing functions that handle writing
-- output.
--
-- @return New logger object.
--
function _M.new( to, ... )

	if type(to) == 'table' then
		_M.module = to
		return
	end

	local mod_name = 'daemonparts.output.' .. tostring(to)
	local res, out = pcall(require, mod_name)

	if not res then
		error("Output module not known")
	end

	return out.setup( ... )

end



_M.module = standard
_M.reset()

return _M


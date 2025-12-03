#!/usr/bin/env lua5.4

local cqueues = require 'cqueues'
local signal = require 'cqueues.signal'


---
-- Routines that let corewait react to posix signals. Most common
-- use case is to gracefully stop a daemon quickly in the event of
-- SIGINT or SIGTERM; but abstracted to be useful for reload on
-- SIGHUP, reap children on SIGCHILD, whatever the programmer decides
-- to implement.
--
-- @module daemonparts.corewait.signal
--
local _M = {}


---
-- React to a signal but only once. The listener is created, used,
-- discarded.
--
function _M.once( core, callback, ... )

	local vargs = { ... }
	local listener = signal.listen( ... )
	signal.block( ... )

	core:wrap(function()
		local caught = core:poll( listener )

		if caught == listener then
			callback( caught:wait() )
		end

		signal.unblock( table.unpack( vargs ) )
	end)

end


---
-- Long running signal monitor implemented as an iterator.
--
function _M.listen( core, ... )

	local cq, is_running = cqueues.running()
	if (not is_running) or (cq ~= core.cq) then
		error('only call daemonparts.signal.listen from inside a coroutine')
	end

	local listener = signal.listen( ... )
	signal.block( ... )

	return function()

		if core:is_stopping() then
			return
		end

		-- loop in case poll returns something not a signal;
		-- normally should only go around once.
		repeat

			local caught = core:poll( listener )

			if caught == listener then
				return listener:wait()
			end

		until core:is_stopping()

	end

end


return _M

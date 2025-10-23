#!/usr/bin/env lua5.4

local process_monitor = require 'daemonparts.process.monitor'


---
-- Process Pool module. Allows starting, monitoring, and controlling
-- a group of assumed identical child processes with one interface.
--
-- Relies on the @{process.monitor} enhancement,
-- and thus, @{corewait}.
--
-- @module daemonparts.process.pool
--
local _M = {}


local _methods = {}

---
-- Returns the number of alive processes in this pool.
--
-- @param this Process pool object
-- @return Count of children
--
function _methods.count( this )
	return this._child_count
end


---
-- Returns true if this pool is active and running.
--
-- @param this Process pool object
-- @return Boolean; true if this object has started.
--
function _methods.running( this )
	return this._running
end


---
-- Tell the pool it's time to stop. Remaining processes will
-- continue until they terminate, unless killall_on_stop is set
-- to true, in which case they will be sent SIGTERM.
--
-- @param this Process pool object
--
function _methods.stop( this )
	this._stop = true
	this.mon:stop()
end


---
-- Arguments for a process monitor.
-- @table pool_args
--
-- @field size Integer. The number of processes to start.
--
-- @field entry Function. This is given to @{process.fork} when the child
--						As it's code to be run.
--
-- @field on_start Function. Callback to notify the parent process a child
--						has started. See @{_callbacks.on_start}
--
-- @field on_exit Function. Callback to notify the parent process a child
--						has exited. See @{_callbacks.on_exit}
--
-- @field restart_on_exit Boolean. If true, when a process exits, another
--						will be started to take it's place.
--
-- @field killall_on_stop Boolean. If true, calling stop() or allowing
--						<close> to reap the monitor will send a SIGTERM
--						to all monitored processes. Defaults to false.
--


--
-- The following stubs are just to get Luadoc.
--
-- luacov: disable
local _callbacks = {} -- luacheck: ignore

---
-- Callback, if provided, for the parent process to be notified
-- a child has started.
--
-- @param child A @{process.child} object, with @{process.monitor} extensions.
--
function _callbacks.on_start( child ) end -- luacheck: ignore

---
-- Callback, if provided, for the parent process to be notified
-- a child has exited.
--
-- @param child A @{process.child} object, with @{process.monitor} extensions.
-- @param code The exit status as provided by wait(2).
--
function _callbacks.on_exit( child, code ) end -- luacheck: ignore
-- luacov: enable


---
-- Creates a new process pool.
--
-- @param cq Corewait Instance
-- @param args Table containing @{pool_args} variables defining the pool.
--
function _M.new( cq, args )

	local function nilor( x, should_be )
		if type(x) == 'nil' then
			return true
		end

		if type(x) == tostring(should_be) then
			return true
		end

		error('Invalid Arguments: Needed ' .. tostring(should_be))
	end


	assert(type(args) == 'table', 'Invalid Arguments')
	assert(type(args.size) == 'number', 'Invalid Arguments: Pool size')
	assert(type(args.entry) == 'function', 'Invalid Arguments: entry function')
	nilor( args.on_start, 'function' )
	nilor( args.on_exit, 'function' )
	nilor( args.restart_on_exit, 'boolean' )
	nilor( args.killall_on_stop, 'boolean' )

	local ret = {
		mon = process_monitor.new( cq, {
			killall_on_stop = args.killall_on_stop
		}),
		_running = false,
		_stop = false,

		--
		-- Monitor has this too, and is effective, but results in
		-- a race: what if a child has exited, but on_exit has not
		-- yet been called? Calling monitor.count() will return an
		-- undercount in that case.
		--
		_child_count = 0
	}


	local function launch()
		cq:wrap(function()
			local child = assert( ret.mon:fork {
				entry = args.entry
			})

			ret._running = true
			ret._child_count = (ret._child_count + 1)

			if args.on_start then
				args.on_start( child )
			end

			local ecode, message = child:wait()

			if args.on_exit then
				args.on_exit( child, ecode, message )
			end

			ret._child_count = (ret._child_count - 1)

			if args.restart_on_exit then
				if (not ret._stop) and (not cq:is_stopping()) then
					launch()
				end
			end

		end)
	end

	cq:wrap(function()
		for i = 1, args.size do	-- luacheck: ignore 213
			launch()
		end
	end)

	return setmetatable(ret,
		{
			__index = _methods,
			__close = function()
				ret:stop()
			end
		}
	)

end


return _M

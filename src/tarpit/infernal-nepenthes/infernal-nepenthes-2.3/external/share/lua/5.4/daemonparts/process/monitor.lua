#!/usr/bin/env lua5.4

local signal = require 'cqueues.signal'
local promise = require 'cqueues.promise'

local unix = require 'unix'

local process = require 'daemonparts.process'




---
-- The process.monitor module extends the existing process module
-- with cqueues-compatible async functionality. Calling child:wait()
-- will pause the coroutine making the call, instead of causing the
-- entire program to go into a stopped state in a system call.
--
-- This module makes heavy use of cqueue's signal module, as well
-- as @{corewait}. Having more than one process monitor open and
-- active is likely to cause undefined behavior.
--
-- @module daemonparts.process.monitor
--
local _M = {}



local _methods = {}


---
-- Send a signal to all processes under monitoring. By default,
-- SIGTERM is used, however anything can be sent. No return value.
--
-- @param this The Process Monitor
-- @param with_signal A signal number to send to all processes. Defaults
--                    to SIGTERM.
--
function _methods.killall( this, with_signal )

	if not with_signal then
		with_signal = unix.SIGTERM
	end

	for pid in pairs( this.known_processes ) do
		unix.kill( pid, with_signal )
	end

end


---
-- Attach a process to the monitor. This is mostly an internal method,
-- but exposed for unit testing. Call one of @{fork}, @{fork_fcn},
-- @{exec}, @{exec_cmd} instead. No return value.
--
-- @param this The Process Monitor
-- @param child_process A @{process.child} object.
--
function _methods.attach( this, child_process )

	--
	-- Resolves a race condition: first process forks and
	-- terminates BEFORE the signal listener is ready.
	--
	this.start_promise:get()
	local on_exit = promise.new()

	--
	-- Override 'wait' so that it blocks the coroutine, not the
	-- process, until the child terminates.
	--
	child_process.wait = function()
		this.cq:poll( on_exit )
		return on_exit:get(0)
	end

	--
	-- Callback for the signal handler to know which coroutine
	-- to resume.
	--
	if this.known_processes[ child_process.pid ] then
		-- Uh-oh, child terminated before it could be accounted
		-- for. This is a different race than the one resolved
		-- by start_promise.
		local code = this.known_processes[ child_process.pid ]
		this.known_processes[ child_process.pid ] = nil
		this.race_hit = true	-- purely to prove this code path was hit in unit tests.
		on_exit:set( true, code )
		return
	end


	this.known_processes[ child_process.pid ] = function( exit_code )
		on_exit:set( true, exit_code )
	end

	this.process_count = this.process_count + 1

end


---
-- Forks a process. See @{process.fork} for details.
--
-- @param this The Process Monitor
-- @param args A @{process.fork_args} Table.
-- @return A @{process.child} object.
--
function _methods.fork( this, args )

	assert(type(args) == 'table', 'Unknown arguments')

	local child = this.cq:interrupt(function()
		return process.fork( args )
	end)

	--
	-- XXX: this is really ugly, but to prove that a certain race
	-- condition is called for, it must be made consistently easy
	-- to fire.
	--
	if this.prewait then
		this.cq:poll(2)
	end

	this:attach( child )
	return child

end


---
-- Forks a process. See @{process.fork_fcn} for details.
--
-- @param this The Process Monitor
-- @param fcn Function to execute in the child process.
-- @return A @{process.child} object.
--
function _methods.fork_fcn( this, fcn )

	local child = this.cq:interrupt(function()
		return process.fork_fcn( fcn )
	end)

	this:attach( child )
	return child

end


---
-- Forks a process and immediately calls exec().
-- See @{process.exec} for details.
--
-- @param this The Process Monitor
-- @param args A @{process.exec_args} Table.
-- @return A @{process.child} object.
--
function _methods.exec( this, args )

	local child = this.cq:interrupt(function()
		return process.exec( args )
	end)

	this:attach( child )
	return child

end


---
-- Forks a process and immediately calls exec().
-- See @{process.exec_cmd} for details.
--
-- @param this The Process Monitor
-- @param command Command to execute.
-- @return A @{process.child} object.
--
function _methods.exec_cmd( this, command, ... )

	local vargs = { ... }

	local child = this.cq:interrupt(function()
		return process.exec_cmd( command, table.unpack( vargs ) )
	end)

	this:attach( child )
	return child

end


---
-- Returns the total number of monitored child processes.
--
-- @param this Monitored object
-- @return number Count of child processes still alive.
--
function _methods.count( this )
	return this.process_count
end


---
-- Stop this process monitor. If killall_on_stop is true,
-- all processes will be given a shutdown signal. No return value.
--
-- @param this Monitored object
--
function _methods.stop( this )

	this.is_stopping = true
	if this.killall_on_stop then
		this:killall()
	end

end


---
-- Arguments for a process monitor.
-- @table monitor_args
-- @field killall_on_stop Boolean. If true, calling stop() or allowing
--                        <close> to reap the monitor will send a SIGTERM
--                        to all monitored processes. Defaults to true.
--


---
-- Creates a new process monitor object.
--
-- @param cq A @{corewait} object. Can be acquired as a singleton.
-- @param args A table of optional arguments.
--
function _M.new( cq, args )

	if type(args) == 'nil' then
		args = {}
	end

	assert(type(args) == 'table', 'invalid arguments')



	local ret = {
		cq = cq,
		known_processes = {},
		process_count = 0,
		start_promise = promise.new(),
		is_stopping = false
	}

	if type(args.killall_on_stop) == 'nil' then
		ret.killall_on_stop = true
	elseif type(args.killall_on_stop) == 'boolean' then
		ret.killall_on_stop = args.killall_on_stop
	else
		error('invalid arguments: killall_on_stop must be boolean')
	end

	setmetatable(ret, {
		__index = _methods,
		__close = function()
			ret:stop()
		end
	})


	if args.killall_on_stop then
		cq:wrap( function()
			repeat
				cq:poll()	-- forever, in theory
			until cq:is_stopping() or ret.is_stopping

			ret:killall()
		end)
	end


	---
	-- Reap exited processes from the monitor table.
	--
	local function sigchild_handler( pid, status, code )

		if pid == 0 then
			return
		end

		if (status ~= 'exited') and (status ~= 'killed') then
			return
		end

		if pid then
			if ret.known_processes[pid] then
				ret.known_processes[pid]( code )
				ret.known_processes[pid] = nil
				ret.process_count = ret.process_count - 1
			else
				--
				-- Race condition: it's possible the child may have
				-- forked, exited (thus throwing SIGCHLD), before it
				-- becomes attached to the process monitor.
				--
				-- Leave notice to the attachment function that it
				-- should do the cleanup.
				--
				ret.known_processes[pid] = code
			end
		end

	end


	cq:wrap( function()
		ret.start_promise:set( true, true )
		for sig in cq:signals( signal.SIGCHLD ) do
			if sig == signal.SIGCHLD then
				repeat

					local pid, status, code = unix.waitpid( -1, unix.WNOHANG )

					if pid then
						sigchild_handler( pid, status, code )
					end

				until (not pid) or (pid == 0)
			end
		end
	end)

	return ret

end



return _M

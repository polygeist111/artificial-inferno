#!/usr/bin/env lua5.4

local cqueues = require 'cqueues'
local condition = require 'cqueues.condition'
local signal = require 'cqueues.signal'
local promise = require 'cqueues.promise'

local corewait_signal = require 'daemonparts.corewait.signal'


---
-- The Corewait module is a boilerplate wrapper around cqueues.
--
-- This module provides a reentrant instance of a the wrapper code. The
-- returned instance includes a cqueues controller, a stop condition and
-- signal, and replacements for the cqueues poll(), step(), loop(), an
-- errors() functions that also monitor the stop condition.
--
-- The included stop condition is to solve a consistent problem: When a
-- daemon has been asked to stop, but has coroutines waiting on IO with
-- long timeouts - such as listening on a socket before accept() - the
-- correct thing to do is break those waiting threads out of hiberation
-- and to allow them to clean up and terminate.
--
-- With cqueues it's possible to wait for multiple different objects.
-- Thus, one coroutine watches for termination signals, and when it gets
-- a signal, starts the daemon shutdown process. Other coroutines that
-- using the poll() wrapper here are then immediately scheduled to be
-- woken up. Once activated, they can see that is_stopping() is now
-- true, and begin to terminate.
--
-- Corewait supercedes the daemonparts 1.x Signals code.
--
-- @module daemonparts.corewait.instance
--
local _M = {}


local _methods = {}


---
-- Calls cqueues.wrap() using this corewait instance's embedded cqueues
-- controller.
--
-- @param this Corewait Instance
-- @param fcn Function to be converted into a coroutine, and attached
--            to the cqueues controller embedded in this Corewait instance.
--
function _methods.wrap( this, fcn )
	assert( this._alive, 'controller destroyed' )
	return this.cq:wrap(fcn)
end


---
-- Indicator of corewait's internal state: normal operations or
-- shutting down?
--
-- @param this Corewait Instance
-- @return boolean - true if the daemon is in shutdown mode.
--
function _methods.is_stopping( this )
	assert( this._alive, 'controller destroyed' )
	return this._is_stopping
end


---
-- Start the shutdown process. @{is_stopping} will return true,
-- the signal handler will stop, and all threads currently paused
-- in @{poll} will be woken up. No return value.
--
-- @param this Corewait Instance
--
function _methods.shutdown( this )
	assert( this._alive, 'controller destroyed' )
	if not this._is_stopping then
		this._is_stopping = true
		this._stop_condition:signal()
	end
end


---
-- Wait for IO. Calls cqueues.poll() internally and tries to implement
-- that function exactly as-is. Calling cqueues.poll() directly will
-- still work as intended; however calling this function instead will
-- automatically wake up the thread as if a timeout occured when a
-- shutdown signal is received, or when @{shutdown} is called.
--
-- While in shutdown mode, immediately returns nil, to help the calling
-- thread finish it's work and terminate.
--
-- @param this Corewait Instance
-- @param ... Cqueues objects and/or timeout values to wait on.
-- @return Objects that polled ready; or nil if wakeup on shutdown.
--
function _methods.poll( this, ... )
	assert( this._alive, 'controller destroyed' )

	if this._is_stopping then
		return
	end

	local res = { cqueues.poll( this._stop_condition, ... ) }

	--
	-- Remove the stop condition from the result set.
	--
	local pos = 0
	for i, v in ipairs( res ) do	-- luacheck: ignore 213
		if v == this._stop_condition then
			pos = i
		end
	end

	if pos > 0 then
		table.remove(res, pos)
	end

	return table.unpack( res )

end


---
-- Sometimes things need to be triggered from within a coroutine,
-- but must be executed by the top level of the program. A good
-- example is forking the process - as an example, calling the
-- @{daemonparts.process} module cannot be done inside a coroutine
-- without causing undefined behavior.
--
-- Interrupt provides a way for a coroutine to indicate it needs work
-- done by the top level loop calling cqueues.step(). The coroutine
-- requesting an interrupt will be suspended until the given callback
-- function is run, and the resulting exit value will be provided back
-- to the coroutine.
--
-- Note that your program must use @{step} instead of cqueues.step in
-- order to handle the interrupt properly. Otherwise, cqueues will
-- return an error. @{loop} and @{errors} are provided which work the
-- same way as in the cqueues base module, but call @{step} instead.
-- Monkey patching cqueues might be possible (I've not tried it.)
--
-- @param this Corewait Instance
-- @param func Callback function to be executed
-- @return Return value of given callback
--
function _methods.interrupt( this, func )
	assert( this._alive, 'controller destroyed' )

	local intr = promise.new()

	this.cq:wrap(function()
		error(
			setmetatable(
			{
				is_interrupt = true,
				func = function()
					intr:set( true, func() )
				end
			},
			-- luacov: disable
			{
				__tostring = function()
					return "Coroutine Interrupt Request: " .. tostring(func)
				end
			}
			-- luacov: enable
		))
	end)

	this:poll( intr )
	return intr:get()

end


---
-- Most daemons gracefully shut down on SIGINT and/or SIGTERM.
-- This will enable a signal listener that calls shutdown().
--
-- @param this Corewait Instance
--
function _methods.enable_signal_stop( this )

	local function callback()
		this:shutdown()
		this._signals_on = false
	end

	corewait_signal.once( this, callback,
		signal.SIGTERM,
		signal.SIGINT
	)

	this._signals_on = true

end


---
-- Return an iterator that yields every time a signal arrives.
-- Continues forever until shutdown() is called, at which point
-- returns nil, terminating the loop.
--
-- For example:
-- for sig in cq:signals( signal.SIGUSR1 ) do print("Caught signal:", sig) end
--
-- @param this Corewait Instance
-- @param ... Signal(s) to listen for
-- @return Iterator function of caught signals
--
function _methods.signals( this, ... )
	return corewait_signal.listen( this, ... )
end


---
-- In order for @{interrupt} to work properly, this must be used instead
-- of cqueues.step. Otherwise your program will get an error instead
-- of the interrupt functioning correctly.
--
-- Semantics are the same as cqueues.step.
--
-- @param this Corewait Instance
-- @param timeout Timeout passed to cqueues.step()
--
function _methods.step( this, timeout )
	assert( this._alive, 'controller destroyed' )

	local success, err, context = this.cq:step( timeout )

	if type(err) == 'table' then
		if err.is_interrupt then
			err.func()
			return true
		end
	end

	return success, err, context

end


---
-- Calls @{step} in a loop. Same functionality as cqueues:loop().
--
-- @param this Corewait Instance
-- @param timeout Timeout passed to cqueues.step()
--
function _methods.loop( this, timeout )
	assert( this._alive, 'controller destroyed' )

	local res, err, context

	repeat
		res, err, context = this:step( timeout )
		if not res then
			break
		end

	until this:is_stopping() or this.cq:count() == 0

	return res, err, context
end


---
-- Creates an iterator over errors from @{step}. Same functionality
-- as cqueues:errors().
--
-- @param this Corewait Instance
-- @param timeout Timeout passed to cqueues.step()
--
function _methods.errors( this, timeout )
	assert( this._alive, 'controller destroyed' )

	return function()
		if this.cq:count() == 0 then
			return nil
		end

		local res, err, context
		repeat
			res, err, context = this:step( timeout )
		until not res or this.cq:count() == 0

		if res then
			return nil
		end

		return err, context
	end
end


---
-- Destroy the current cqueues controller and start completely
-- over. This is mandatory after a fork(), which largely corrupts
-- the cqueues controller.
--
-- @param this Corewait Instance
-- No return value.
--
function _methods.close( this )
	this:shutdown()

	this._alive = false
	this._stop_condition = nil
	this._cq = nil

	collectgarbage()
end


-- luacov: disable

---
-- Provides Cqueues compatible interface, allowing a higher level
-- cqueues controller to watch this one.
--
function _methods.pollfd( this )
	return this.cq:pollfd()
end

function _methods.events( this )
	return this.cq:events()
end

function _methods.timeout( this )
	return this.cq:timeout()
end



---
-- Thin wrapper around cqueues.monotime to avoid extra 'require'
--
-- @return Current return value of cqueues.monotime.
--
function _methods.monotime()
	return cqueues.monotime()
end

---
-- Thin wrapper around cqueues:count()
--
-- @return Number of coroutines attached to this controller.
--
function _methods.count( this )
	return this.cq:count()
end


-- luacov: disable

---
-- Creates a new Corewait instance.
--
-- @return new corewait instance
--
function _M.new()

	local ret = {

		_alive = true,
		_is_stopping = false,
		_signals_on = false,
		_stop_condition = condition.new(),
		cq = cqueues.new()

	}

	return setmetatable( ret,
		{
			__index = _methods,
			__close = function()
				ret:close()
			end,
			__gc = function()
				ret:close()
			end
		}
	)

end

return _M

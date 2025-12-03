#!/usr/bin/env lua5.4

local cqueues = require 'cqueues'
local instance = require 'daemonparts.corewait.instance'
local cq


---
-- Corewait provides boilerplate wrapper code around cqueues useful
-- for long running daemons.
--
-- This module provides a singleton and quick ways to access it. It
-- uses the fully reentrant implementation at
-- @{corewait.instance}. Calling the re-entrant version
-- instead of the singleton accessor is a fully supported way to use
-- corewait.
--
-- @module daemonparts.corewait
--
local _M = {}


local function check()
	if not cq then
		cq = instance.new()
	end
end


---
-- Access a Corewait controller, @{corewait.instance}, as a singleton.
-- If the singleton does not exist it will be created.
--
-- @return Corewait controller object
--
function _M.single()
	check()
	return cq
end


---
-- Creates an instance of a Corewait object,
-- @{corewait.instance}, that is not a singleton.
--
-- @return Corewait controller object
--
function _M.new()
	return instance.new()
end

--
-- The following all simply call into an instance created by check().
--
-- luacov: disable

---
-- Shortcut to cqueues.monotime, to allow skipping an extra require().
--
function _M.monotime()
	return cqueues.monotime()
end

---
-- Singleton wrapper around @{corewait.instance.is_stopping}.
--
function _M.is_stopping()
	check()
	return cq:is_stopping()
end

---
-- Singleton wrapper around @{corewait.instance.shutdown}.
--
function _M.shutdown()
	assert( cq, 'corewait not started' )
	return cq:shutdown()
end

---
-- Singleton wrapper around @{corewait.instance.poll}.
--
function _M.poll( ... )
	check()
	return cq:poll( ... )
end

---
-- Singleton wrapper around @{corewait.instance.interrupt}.
--
function _M.interrupt( func )
	assert( cq, 'corewait not started' )
	return cq:interrupt( func )
end

---
-- Singleton wrapper around @{corewait.instance.step}.
--
function _M.step( timeout )
	assert( cq, 'corewait not started' )
	return cq:step( timeout )
end

---
-- Singleton wrapper around @{corewait.instance.loop}.
--
function _M.loop( timeout )
	assert( cq, 'corewait not started' )
	return cq:loop( timeout )
end

---
-- Singleton wrapper around @{corewait.instance.errors}.
--
function _M.errors( timeout )
	assert( cq, 'corewait not started' )
	return cq:errors( timeout )
end

-- luacov: enable

---
-- Destroy the current singleton controller and start completely
-- over. This is mandatory after a fork(), which largely corrupts
-- a cqueues controller, leading to undefined behavior.
--
-- No return value.
--
function _M.destroy()
	if cq then
		cq:close()
		cq = nil
	end
end

return _M

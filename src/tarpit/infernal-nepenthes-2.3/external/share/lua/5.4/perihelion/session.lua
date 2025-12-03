#!/usr/bin/env lua5.3


---
-- Generate a session id. Pulls from /dev/urandom, because
-- that should exist in most Posix systems by this point without
-- requiring dependancies.
--
local function gen_session_id()

	local urandom = assert(io.open("/dev/urandom", "r"))

	local ret = ""
	local set = "0123456789abcdef"

	for i = 1, 36 do	-- luacheck: ignore 213
		local b = string.byte(urandom:read(1)) & 0xf
		ret = ret .. set:sub(b + 1, b + 1)
	end

	urandom:close()
	return ret

end


---
-- Retrieve an existing session, or create a new one.
--
local function session_setup( storage, web, options )

	local id = web.cookies[ 'sessionid' ]
	local data = nil
	local exists = false


	if id then
		data = storage:retrieve( id )
	end

	if data then
		exists = true

		if data.expire <= os.time() then
			storage:purge( id )
			id = nil
		end
	else
		id = nil
	end

	if not id then
		id = gen_session_id()
		data = {
			expire = os.time() + options.timeout,
			values = {}
		}
	end


	web.session_id = id
	web.session_options = {
		timeout = options.timeout,
		secure = options.secure
	}

	local changed = false

	web.SESSION = setmetatable({}, {
		__index = function( tab, key )	-- luacheck: ignore 212
			return data.values[key]
		end,

		__newindex = function( tab, key, value )	-- luacheck: ignore 212
			changed = true
			data.values[key] = value
		end,

		__ipairs = function( )
			return ipairs( data.values )
		end,

		__pairs = function( )
			return pairs( data.values )
		end,

		__call = function( )
			return data.values
		end
	})

	function web.end_session( inner_web )
		storage:purge( inner_web.session_id )
		inner_web.session_id = nil
	end

	function web.session_changed()
		if not exists then
			return true
		end

		local entered = data.expire - options.timeout
		if entered < (os.time() - 10) then
			return true
		end

		return changed
	end

end


---
-- Save session data to the backing store.
--
local function session_complete( storage, web )

	local fmt = "!%a, %d %b %Y %H:%M:%S GMT"

	-- strip off port numbers or Firefox won't take it.
	--local host = web.SERVER_NAME
	--if host:match("%:%d+$") then
		--host = host:gsub("%:%d+$", "")
	--end


	--
	-- There may have been a request to kill the session.
	-- Resend if we have a session id; otherwise, send an expired
	-- header to delete the cookie from the browser.
	--
	if web.session_id then

		local expire_time = os.time() + web.session_options.timeout
		local session_data = {
			expire = expire_time,
			values = web.SESSION()
		}

		if web.session_changed() then
			storage:store( web.session_id, session_data )
		end

		web:cookie {
			name = 'sessionid',
			value = web.session_id,
			HttpOnly = true,
			Secure = web.session_options.secure,
			Expires = os.date(fmt, expire_time),
			Path = web._prefix or '/',
			Domain = web.SERVER_NAME
		}

	else
		--
		-- It seems like this belongs in web:end_session(), instead
		-- of here. But having this be the last place to call cookie()
		-- ensures that the cookie is purged, and not overwritten by
		-- some other user-called cookie.
		--
		web:cookie {
			name = 'sessionid',
			value = "!!off",
			HttpOnly = true,
			Secure = web.session_options.secure,
			Expires = os.date(fmt, os.time() - 86400),
			Path = web._prefix or '/',
			Domain = web.SERVER_NAME
		}
	end

end




local _M = {}

---
-- Create a new session handler. Typically only called once
-- in an application's lifecycle.
--
function _M.new( storage, options )

	assert(type(storage) == 'table', "Valid storage handler required")
	assert(type(storage.purge) == 'function', "Storage handler is missing components")
	assert(type(storage.retrieve) == 'function', "Storage handler is missing components")
	assert(type(storage.store) == 'function', "Storage handler is missing components")

	if not options then
		options = {}
	end

	if options.secure == nil then
		options.secure = true
	end

	if not options.timeout then
		options.timeout = 30 * 60
	end


	--
	-- This is the loadable Perihelion module that has hooks.
	--
	return {
		pre_hook = function( web )
			session_setup( storage, web, options )
		end,

		post_hook = function( web )
			session_complete( storage, web )
		end
	}

end


return _M

#!/usr/bin/env lua


---
-- The central Perihelion app object.
--
local _methods = {}


--
-- 5.1 Compatibility
--
if not table.unpack then
	table.unpack = unpack	-- luacheck: ignore 122
end


---
--
-- Typical reponse codes, used by a number of functions below
--
local _codes = {

   [200] = "OK",
   [202] = "Accepted",
   [204] = "No Content",
   [301] = "Moved Permanently",
   [302] = "Found",
   [303] = "See Other",
   [304] = "Not Modified",
   [400] = "Bad Request",
   [401] = "Unauthorized",
   [403] = "Forbidden",
   [404] = "Not Found",
   [405] = "Method Not Allowed",
   [406] = "Not Acceptable",
   [408] = "Request Timeout",
   [409] = "Conflict",
   [410] = "Gone",
   [500] = "Internal Server Error",
   [501] = "Not Implemented",
   [502] = "Bad Gateway",
   [503] = "Service Unavailable",
   [504] = "Gateway Timeout",


}


---
-- Render a server error page.
--
-- This will become obsolete when Perihelion supports error pages.
--
local function wsapi_error( request_env, err ) -- luacheck: ignore 212

	local headers = { ["Content-type"] = "text/html" }

	local function error_text()
		coroutine.yield(  [[
<html>
<head>
	<title>500 Internal Server Error</title>
</head>
<body>
	<h1>Server Error</h1>
	An internal error occured with this application:
]]
.. tostring(err) ..
[[</body>
</html>
		]] )
	end

	return "500 Internal Server Error", headers, coroutine.wrap(error_text)

end


---
-- Render a not found page.
--
-- This will likely become obsolete when Perihelion supports error pages.
--
local function wsapi_404( request_env )

	local headers = { ["Content-type"] = "text/html" }

	local function error_text()
		coroutine.yield( [[
<html>
<head>
	<title>404 Not Found</title>
</head>
<body>
	<h1>Not Found</h1>
	The requested URL was not mapped:
	<p>
]]
	.. request_env.PATH_INFO ..
[[	</p>
</body>
</html>
		]] )
	end

	return "404 Not Found", headers, coroutine.wrap(error_text)

end


---
-- Simplify URL processing by removing redundant slashes and
-- chopping of variables.
--
local function compress_path( path )

	-- special case: do nothing if merely '/'.
	if path == '/' then
		return path
	end

	-- smoosh multiple slashes together. they cause pain.
	path = path:gsub("%/%/+", "/")

	-- chop off the last one, while we are at it
	path = path:gsub("%/$", "")

	return path

end


---
-- Disconnect GET variables from a request URI.
--
local function parse_uri( uri )

	-- chop variables
	local path, vars = string.match(uri, "([^%?]+)(.*)")

	-- chop the '?' off the variables
	if vars then
		vars = vars:gsub("^%?", "")
	end

	return compress_path( path ), vars

end


---
-- Undo URL encoding.
-- Lifted directly from "Programming In Lua" 5.0 edition
--
local function urldecode(s)

	s = string.gsub(s, "+", " ")
	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	end)

	return s

end


---
-- Split the path into components, as an iterator.
--
local function split_string( s, delimit )

	local function f()

		while true do

			local start = s:find(delimit)

			if not start then
				coroutine.yield(s)
				return
			end

			local part = s:sub(1, start - 1)
			local remain = s:sub(start)

			coroutine.yield(part, remain)
			s = s:sub(start + 1)

		end

	end

	return coroutine.wrap(f)

end


---
-- Decodes a GET query string into a table.
-- Mostly lifted from "Programming In Lua" 5.0 edition
--
local function decode_get_variables( vstring )

	local ret = {}

	-- skip non-sane input
	if not vstring then return {} end

	-- 'a=b' is the smallest the query string could possibly be
	if #vstring < 3 then return {} end

	for name, value in string.gmatch(vstring, "([^&=]+)=([^&=]+)") do
		name = urldecode(name)
		value = urldecode(value)
		ret[name] = value
	end

	return ret

end



---
-- Take a chunk of a multipart/form-data POST and turn it into
-- an entry in the POST table.
--
local function decode_mime_part( mime_part )

	--
	-- There are two parts to a MIME message part: headers and data.
	-- Split them.
	--
	local raw_headers = {}
	local data = nil
	--local line_term = "[\n" .. char(0x0D) .. char(0x0A) .. "]"

	for v, r in split_string( mime_part, "\n" ) do

		if not v or v:match("^%s*$") then
			data = r
			break
		else
			raw_headers[ #raw_headers + 1 ] = v
		end

	end

	--
	-- Kill the remaining newline at the beginning of the data field.
	--
	if data then
		data = data:gsub('^(%s*)', '')
	end

	--
	-- Extract header data
	--
	local decoded = {}
	local function headercheck( field )
		local c = string.match(field, 'Content%-Type: (.*)$')
		if c then
			decoded.content = c:gsub("(%s*)$", "")
		end

		local name = string.match(field, 'Content%-Disposition: form%-data; name="([^"]-)"%s*$')
		if name then
			decoded.name = name
			decoded.isfile = false
			return
		end

		local m, n = string.match(field, 'Content%-Disposition: form%-data; name="([^"]-)"; filename="([^"]-)"')
		if m then
			decoded.name = m
			decoded.filename = n:gsub("(%s*)$", "")
			decoded.isfile = true
			return
		end
	end


	for i in ipairs(raw_headers) do
		headercheck( raw_headers[i] )
	end

	if not decoded.name or decoded.name == '' then
		return nil
	end


	--
	-- Precisely one line terminator at the end.
	--
	decoded.value = data:gsub('(%s?%s)$', "")

	return decoded

end



---
-- Break up a multipart/form-data POST request.
--
local function decode_post_multipart( data, bound )

	local ret = {}
	bound = "--" .. bound
	local escaped_bound = bound:gsub('%-', '%%-')

	--
	-- Need to find the first chunk, which will be after the
	-- first delimiter. Advance the iterator once and throw it away.
	--
	for mime_part in split_string( data, escaped_bound ) do
		if mime_part and #mime_part > 1 then

			-- cut off the delimiter in the beginning, string_split
			-- leaves it there. Kill beginning new lines.
			mime_part = mime_part:sub( #bound )
			mime_part = mime_part:gsub("^(%s*)", "")

			local decoded = decode_mime_part(mime_part)

			if decoded then
				ret[ #ret + 1 ] = decoded
			end
		end
	end

	return ret

end


---
-- Decode POST variables.
--
local function decode_post_variables( req )

	assert(req.CONTENT_TYPE, "Content type isn't set - can't POST!")
	assert(req.CONTENT_LENGTH, "Content length isn't set - can't POST!")
	assert(req.input, "No input stream - can't POST!")

	--
	-- There's got to be a better way to handle this than slurping
	-- the entire content into memory. Line endings are making it
	-- a hairy mess to implement, though, and right now I just want
	-- this thing to work.
	--
	local len = tonumber(req.CONTENT_LENGTH) or 0
	local ctype = req.CONTENT_TYPE
	local data = req.input:read(len)

	--
	-- Easy, it's the same as GET.
	--
	if string.match(ctype, '^application/x%-www%-form%-urlencoded') then

		req.POST = decode_get_variables( data )
		req.POST_RAW = nil
		return

	end

	--
	-- Much harder. Thanks, HTML4, for causing this pain.
	--
	if string.match(ctype, "^multipart/form%-data;") then

		local bound = string.match(ctype, "boundary%=([%w%-]+)")
		local vars = decode_post_multipart( data, bound )

		req.POST = {}
		req.POST_RAW = nil
		req.FILE = {}

		for i, var in ipairs(vars) do	-- luacheck: ignore 213

			if not var.isfile then
				req.POST[var.name] = var.value
			else
				req.FILE[var.name] = {
					['CONTENT-TYPE'] = var.content,
					['DATA'] = var.value,
					['FILENAME'] = var.filename
				}
			end
		end

		return

	end


	--
	-- Fallback: unknown type, leave a big string.
	--
	req.POST = {}
	req.POST_RAW = data
	return

end



---
-- Destroy the internal variables we were caching inside the
-- request object.
--
local function sanitize_request( env )

	env._UNMATCHED = nil
	env._GET_VARIABLES = nil
	env._URI = nil

end


---
-- Set a list of handler functions for the given path, to be
-- invoked during an HTTP request.
--
-- This function is where the syntax-hack magic happens, thus the
-- multilayered complexity.
--
local function set_route( app, method, path )

	--
	-- Sanity check - set_route doesn't work on everything yet.
	--
	local methods = {
			GET = true,
			POST = true,
			HEAD = true,
			PUT = true,
			DELETE = true
		}

	local methods_decode_body = {
			POST = true,
			PUT = true
		}

	assert(methods[method], "Attempting to set unknown method")
	path = compress_path(path)

	--
	-- I can't claim credit for the following madness; it was shown to
	-- me by someone (I can't recall whom) at Lua Workshop 2012. Said
	-- demonstration immediately spawned the idea for Perihelion.
	--
	--
	-- Let's peel this onion.
	--
	-- First layer: set_route is called by the user of Perihelion to
	-- setup the routing table. It does this by immediately returning
	-- a function.
	--
	-- The returned function is what allows the table of handlers
	-- immediately after the path in the perihelion app to be valid
	-- Lua syntax.
	--
	-- set_route recieves the path, the following anonymous function
	-- gets the handlers.
	--
	return function( handlers )
		--
		-- Second layer: inside this anonymous function, Perihelion
		-- now has access to the user's handler functions, in the form
		-- of a table.
		--
		-- This anonymous function runs once, at app startup, and saves
		-- the handler table into the app's routing table.
		--
		if not app.routes[ path ] then app.routes[path] = {} end
		app.routes[ path ][ method ] = function( request_env, ... )

			--
			-- Third layer: this function, set inside the routes table,
			-- actually handles requests.
			--
			-- This is called for every request that matches the route,
			-- and steps through the provided handlers until it gets
			-- a valid way to end the HTTP request.
			--
			request_env.vars = {}

			request_env.GET = decode_get_variables(
					request_env._GET_VARIABLES
				)

			if methods_decode_body[ method ] then
				decode_post_variables(request_env)
			end

			sanitize_request(request_env)

			for i, v in ipairs(handlers) do	-- luacheck: ignore 213

				local output, headers, iter = v( request_env, ... )
				if type(output) == 'table' then
					for k, v2 in pairs(output) do
						request_env.vars[k] = v2
					end
				elseif type(output) == 'string'
						or type(output) == 'number' then
					return output, headers, iter
				else
					error("Undefined output")
				end
			end

			return wsapi_error(
				request_env,
				"Application didn't finish response"
			)
		end

		--
		-- This table is for the pattern-based route matcher, to
		-- perform matches in order specified by the programmer.
		--
		app.routesi[ #(app.routesi) + 1 ] = {
			path = path,
			route = app.routes[ path ][ method ],
			method = method
		}

	end

end


---
-- Call error hooks.
--
local function call_error_hooks( app, env, err )

	for i, hook in ipairs( app.errorhooks ) do	-- luacheck: ignore 213
		pcall( hook, env, err )
	end

end


---
-- Call normal hooks.
--
local function call_hooks( app, hooks, env, ... )

	for i, hook in ipairs( hooks ) do	-- luacheck: ignore 213
		local res, err = pcall( hook, env, ... )
		if not res then
			call_error_hooks( app, env, err )
			return false, err
		end
	end

	return true

end





---
-- Tells Perihelion that this application is running under
-- a prefix that must be removed before routing a web request.
--
function _methods.prefix( self, path )

	--
	-- Prefix must start with '/' and not end with '/'.
	--
	if path:sub(1, 1) ~= '/' then
		error("Invalid prefix: must start with '/'")
	end

	if path:sub(-1) == '/' then
		path = path:sub(1, #path - 1 )
	end

	self._prefix = compress_path( path )

end


---
-- Sets a GET handler in the application routing table.
--
function _methods.get( self, path )

	return set_route( self, "GET", path )

end


---
-- Sets a HEAD handler in the application routing table.
--
function _methods.head( self, path )

	return set_route( self, "HEAD", path )

end

---
-- Sets a POST handler in the application routing table.
--
function _methods.post( self, path )

	return set_route( self, "POST", path )

end


---
-- Sets a PUT handler.
--
function _methods.put( self, path )

	return set_route( self, "PUT", path )

end


---
-- Sets a DELETE handler.
--
function _methods.delete( self, path )

	return set_route( self, "DELETE", path )

end


--
-- XXX: Add PUT and DELETE support. More a function of
-- having the unit tests that ensure nothing collides.
--

---
-- Add a subapplication to this Perihelion application. Any path
-- below the path provided will be routed to the application below.
--
function _methods.wsapi( self, path, app )

	path = compress_path(path)

	self.routes[ path ] = { }

	local f = function( request_env )

		-- reappend the GET variables, so the underlying WSAPI
		-- application can make use of them.
		local uri = request_env._UNMATCHED
		if request_env._GET_VARIABLES then
			uri = uri .. "?" .. request_env._GET_VARIABLES
			request_env.QUERY_STRING = request_env._GET_VARIABLES
		end

		request_env.PATH_INFO = uri
		sanitize_request(request_env)

		return app.run( request_env )
	end

	local methods = {
			GET = true,
			POST = true,
			PUT = true,
			DELETE = true,
			OPTIONS = true,
			HEAD = true,

			soak = true
		}

	for k in pairs(methods) do
		self.routes[path][k] = f
	end

end


--
-- Add a before-request hook.
--
function _methods.pre_hook( self, hook )

	assert(type(hook) == 'function', "Not a hook")
	self.prehooks[ #(self.prehooks) + 1 ] = hook

end


--
-- Add an after-request hook.
--
function _methods.post_hook( self, hook )

	assert(type(hook) == 'function', "Not a hook")
	self.posthooks[ #(self.posthooks) + 1 ] = hook

end


--
-- Add an on-error hook.
--
function _methods.error_hook( self, hook )

	assert(type(hook) == 'function', "Not a hook")
	self.errorhooks[ #(self.errorhooks) + 1 ] = hook

end


---
-- Return a basic iterator; used in almost every application.
--
local function request_end( return_code, headers, output )

	if not _codes[ return_code ] then
		error("Requested return code not implemented")
	end

	return	tonumber(return_code) .. " " .. _codes[return_code],
			headers,
			coroutine.wrap(function()

				if type(output) == 'string' then
					coroutine.yield(output)
					return
				end

				if type(output) == 'table' then
					for i, v in pairs(output) do	-- luacheck: ignore 213
						coroutine.yield(tostring(v))
					end
				end

				error("What do I do with this?!")

			end)

end


---
-- Methods called from inside Perihelion app requests
--
local _int_methods = {}


---
-- Terminate a web call.
--
function _int_methods.return_status( self, code, output )

	return request_end( code, self.headers, output or "" )

end


---
-- Web call completed successfully
--
function _int_methods.ok( self, output )

	return request_end( 200, self.headers, output or "" )

end


---
-- Web call failed; explicitly render a 500 page
--
function _int_methods.err( self, output )

	return request_end( 500, self.headers, output or "" )

end


---
-- Web call failed - we have no URL here
--
function _int_methods.notfound( self, output )

	return request_end(
		404, self.headers,
		output or "<html><body>Not Found</body></html>"
	)

end


---
-- Web call failed - you aren't allowed
--
function _int_methods.nope( self, output )

	return request_end(
		403, self.headers,
		output or "<html><body>Not Authorized</body></html>"
	)

end


---
-- Redirect elsewhere
--
function _int_methods.redirect( self, url )

	if (not url) or (type(url) ~= 'string') then
		error("Redirect without destination")
	end

	self.headers['Location'] = url

	return request_end(
		302, self.headers,
		"<html><body><a href=" .. url .. "</a></body></html>"
	)

end


---
-- Redirect elsewhere... forever
--
function _int_methods.redirect_permanent( self, url )

	if (not url) or (type(url) ~= 'string') then
		error("Redirect without destination")
	end

	self.headers['Location'] = url

	return request_end(
		301, self.headers,
		"<html><body><a href=" .. url .. "</a></body></html>"
	)

end


---
-- Sends a cookie to the user agent.
--
function _int_methods.cookie( self, args )

	if type(args) ~= 'table' then
		error("Improper Cookie Data")
	end

	if (not args.name) or (not args.value) then
		error("Missing required Cookie Data")
	end

	if self.headers['Set-Cookie'] then
		print("WARNING: Attempt to set multiple cookies in one request")
		print("WARNING: The original cookie has been overwritten")
	end


	local cookie_string = string.format('%s=%s', args.name, args.value)

	if args.Secure then
		cookie_string = cookie_string .. '; Secure'
	end

	if args.Path then
		cookie_string = cookie_string .. '; Path=' .. args.Path
	end

	if args.HttpOnly then
		cookie_string = cookie_string .. '; HttpOnly'
	end

	if args.Domain then
		cookie_string = cookie_string .. '; Domain=' .. args.Domain
	end

	if args.Expires then
		cookie_string = cookie_string .. '; Expires=' .. tostring(args.Expires)
	end

	self.headers['Set-Cookie'] = cookie_string

end


---
-- Attach a bunch of hooks as one module.
--
function _methods.load_module( self, modhooks )

	if modhooks.pre_hook then
		self:pre_hook( modhooks.pre_hook )
	end

	if modhooks.post_hook then
		self:post_hook( modhooks.post_hook )
	end

	if modhooks.error_hook then
		self:error_hook( modhooks.error_hook )
	end

end


---
-- Sanity tests that a route is viable, called inside handle_request.
--
local function route_viable( route, uri_remain, method )

	-- Route must exist.
	if not route then
		return false
	end

	-- Route must support the method.
	if not route[ method ] then
		return false
	end

	-- The rest depends on the remaining URI. No URL?
	-- then it always can handle it.
	if type(uri_remain) ~= 'string' then
		return true
	end

	-- Route must be able to soak the remaining path, if the
	-- remaining path isn't merely get variables.
	if #uri_remain > 0 then
		return route.soak
	end

	return true

end


---
-- Executes a WSAPI request. Called by the web/app server or whatever
-- else is the container for this application.
--
local function handle_request( self, request_env )

	local uri, vars = parse_uri( request_env.PATH_INFO )
	local path = ''
	local ret, headers, iter

	local only_headers = false


	--
	-- shallow copy the environment, we need to mangle some paths
	--
	-- XXX: Xavante does some weird insanity with metamethods. Gotta
	-- explicitly initialize most vars before pairs() will see them.
	--
	-- Maybe Perihelion should detect if this is necessary and optimize
	-- it out otherwise.
	--
	local cgi_vars = {
			'SERVER_SOFTWARE',
			'SERVER_NAME',
			'GATEWAY_INTERFACE',
			'SERVER_PROTOCOL',
			'SERVER_PORT',
			'REQUEST_METHOD',
			'DOCUMENT_ROOT',
			'PATH_INFO',
			'PATH_TRANSLATED',
			'SCRIPT_NAME',
			'QUERY_STRING',
			'REMOTE_ADDR',
			'REMOTE_USER',
			'CONTENT_TYPE',
			'CONTENT_LENGTH',
			'APP_PATH',
			'HTTP_COOKIE',
			'input',
			'error'
		}

	local env = {}

	for i, variable in ipairs(cgi_vars) do		-- luacheck: ignore 213
		env[variable] = request_env[variable]
	end

	--
	-- Any X-* Headers? (XXX: Not likely to work on Xavante)
	--
	for k, v in pairs(request_env) do
		if k:match('^HTTP%_[xX].*') then
			env[k] = v
		end
	end

	--
	-- Now build the rest of the request object, including default
	-- headers.
	--
	env.headers = { ['Content-type'] = 'text/html' }
	setmetatable(env, { __index = _int_methods })


	--
	-- How does SCRIPT_NAME look? Make sure it's set, uWSGI
	-- isn't a fan of it.
	--
	env.SCRIPT_NAME = request_env.SCRIPT_NAME or ''


	--
	-- Cookies?
	--
	env.cookies = {}
	if request_env['HTTP_COOKIE'] then
		for k, v in string.gmatch(request_env['HTTP_COOKIE'], '(%w+)%=(%w+)') do
			env.cookies[k] = v
		end
	end


	--
	-- Is this a head/options request?
	--
	if env.REQUEST_METHOD == 'HEAD' then
		only_headers = true
	end


	--
	-- How does PATH_INFO look? Needs to start with a '/'.
	--
	if env.PATH_INFO:sub(1, 1) ~= '/' then
		env.PATH_INFO = '/' .. env.PATH_INFO
	end


	--
	-- Remove any specified prefix.
	--
	if self._prefix ~= '/' then

		local prefix_test = string.sub( uri, 1, #(self._prefix) )

		if prefix_test == self._prefix then
			uri = string.sub( uri, #(self._prefix) + 1 )
		end

	end


	local success, err = call_hooks( self, self.prehooks, env )
	if not success then
		return wsapi_error( env, err )
	end

	--
	-- Let's go find a path.
	--
	local function findit()
		--
		-- Attempt one: split the path apart, and go looking for
		-- anything that will take it in pieces.
		--
		-- This is the original way Perihelion worked. Pattern
		-- base request routing was too powerful of a feature for the
		-- first go around and, thus this was implemented as the first
		-- shot. It still works and is reasonably fast.
		--
		uri = compress_path(uri)

		for path_part, remain in split_string( uri, '/' ) do

			if path ~= '/' then
				path = path .. '/' .. (path_part or '')
			else
				path = path .. (path_part or '')
			end

			local route = self.routes[path]

			--
			-- Tests to ensure the handler is viable.
			--
			if route_viable( route, remain, env.REQUEST_METHOD ) then
				env._UNMATCHED = remain or '/'
				env._GET_VARIABLES = vars
				env._URI = uri
				env.SCRIPT_NAME = env.SCRIPT_NAME .. path
				ret, headers, iter = route[ env.REQUEST_METHOD ](env)
				return
			end

		end


		--
		-- Attempt two: see if anything hits with string.match().
		--
		-- This is a rather unintelligent algorithm, and likely
		-- a performance bottleneck especially in large apps.
		-- We'll deal with that later.
		--
		-- There has to be a way to merge both into a fairly complex,
		-- but efficient, algorithm. I just haven't found that yet and
		-- Perihelion is performing nicely so far.
		--
		for i, pr in ipairs(self.routesi) do	-- luacheck: ignore 213

			local try_path = pr.path
			local route = pr.route

			if env.REQUEST_METHOD ~= pr.method then
				-- no point wasting cycles on a route we can't use
				goto skip
			end

			local xm = { string.match(uri, "^" .. try_path .. "$") }

			if #xm > 0 then
				--
				-- Getting captures implies we have a pattern hit.
				-- However, we now need to ensure we aren't matching
				-- too much. Cut the matched part off of the URI and
				-- see if there's anything left.
				--
				local xpath = try_path
				local xuri = uri

				--
				-- This integer controls how many matches Perihelion
				-- will compute in a URL. 25 sounds sane.
				--
				local i2 = 25
				repeat
					local ustart, uend = string.find(xuri, xpath)	-- luacheck: ignore 211
					local pstart, pend = string.find(xpath, "%b()") -- luacheck: ignore 211

					uend = uend or 1
					pend = pend or 1

					xpath = xpath:sub(pend + 1) or ""
					xuri = xuri:sub(uend + 1) or ""

					--
					-- Prevent infinite loops.
					--
					i2 = i2 - 1
					if i2 <= 0 then
						error("Excessive route complexity")
					end

				until (#xuri == 0) or (xuri == "/")

				if #xuri == 0 then
					xuri = "/"
				end

				env._UNMATCHED = xuri

				--
				-- If there is an unmatched subpath at this point,
				-- the hander must be able to use it. Otherwise,
				-- continue looking.
				--
				if xuri  == '/' or route.soak then
					env.SCRIPT_NAME = env.SCRIPT_NAME .. try_path
					env._GET_VARIABLES = vars
					env._URI = uri


					local handler = route

					if handler then
						ret, headers, iter = handler(env, table.unpack(xm))
						return
					end
				else
					print("Pattern failed for", try_path)

				end
			end

			::skip::
		end


		--
		-- Nothing. Is this a HEAD request?
		--
		if env.REQUEST_METHOD == 'HEAD' then
			env.REQUEST_METHOD = 'GET'
			return findit( self, request_env )
		end

		ret, headers, iter = wsapi_404( request_env )
		return true, nil
	end

	success, err = pcall( findit )

	if not success then
		call_error_hooks( self, request_env, err )
		ret, headers, iter = wsapi_error( request_env, err )
	end

	success, err = call_hooks(
			self,
			self.posthooks,
			env,
			ret,
			headers
		)

	if not success then
		ret, headers, iter = wsapi_error( request_env, err )
	end

	if success and only_headers then
		iter = coroutine.wrap(function() return nil end)
	end

	return ret, headers, iter

end


---
-- The returned namespace just contains the 'new' function
-- for API calls and some versioning info.
--
local _M = {}


---
-- Version number of this copy of Perihelion.
--
_M._VERSION = "0.16"


---
-- Release date of this copy of Perihelion.
--
_M._RELEASE = "2023.0606"


---
-- Creates a new Perihelion application.
--
function _M.new( )

	local ret = {
		routes = {},
		routesi = {},
		prehooks = {},
		posthooks = {},
		errorhooks = {},
		_prefix = "/"
	}

	for k, v in pairs( _methods ) do
		ret[k] = v
	end

	--
	-- This is an ugly hack: WSAPI applications are called as
	-- functions in namespaces, not as objects. Thus we don't get
	-- a unique state per instantiated application.
	--
	-- We work around this with a closure. It should tail-call
	-- optimize away.
	--
	ret.run = function( ... )
		return handle_request( ret, ... )
	end

	return ret

end

return _M

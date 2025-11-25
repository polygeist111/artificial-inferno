#!/usr/bin/env lua5.4

if os.getenv('LUA_APP_BOOTSTRAP') then
	dofile(os.getenv('LUA_APP_BOOTSTRAP'))
end

pcall(require, "luarocks.loader")

local http_server = require 'http.server'
local http_headers = require 'http.headers'

local unix = require 'unix'

local daemonize = require 'daemonparts.daemonize'
local config = require 'components.config'
local output = require 'daemonparts.output'
local corewait = require 'daemonparts.corewait'


if not arg[1] then
	error("Provide application")
end

if not arg[2] then
	error("Provide config file")
end

local location = unix.getcwd()
package.path = package.path .. ';' .. location .. '/?.lua'

local app
local app_f = assert(loadfile( arg[1] ))
config( arg[2] )

if config.log_level then
	output.filter( config.log_level )
end

local function header_cleanup( var )
	return 'HTTP_' .. var:upper():gsub("%-", '_')
end


local function http_responder( server, stream )	-- luacheck: ignore 212

	local req_headers = stream:get_headers()
	local cl_family, cl_addr, cl_port = stream:peername()	-- luacheck: ignore 211
	local path = req_headers:get(':path')

	local request = {
		SERVER_NAME = req_headers:get(':authority'),
		SERVER_SOFTWARE = 'lua-http',
		SERVER_PROTOCOL = stream.connection.version,
		--SERVER_PORT = config.http_port,
		REQUEST_METHOD = req_headers:get(':method'),
		DOCUMENT_ROOT = "/",		-- XXX: Set correctly
		PATH_INFO = path,
		PATH_TRANSLATED = path,		-- XXX: Set Correctly
		APP_PATH = '/',				-- XXX: Set Correctly
		SCRIPT_NAME = '/',			-- XXX: what should this be?
		QUERY_STRING = "?",			-- XXX: Needs to be parsed
		REMOTE_ADDR = cl_addr,
		REMOTE_PORT = cl_port,
		REMOTE_USER = req_headers:get('authorization'),	-- XXX: parse this
		CONTENT_TYPE = req_headers:get('content-type'),
		CONTENT_LENGTH = req_headers:get('content-length'),
		HTTP_COOKIE = req_headers:get('cookie')
	}

	-- XXX: I'm sorry
	request[ header_cleanup('X_USER_AGENT') ] = req_headers:get('user-agent')

	-- import all nonstandard headers; they're important
	for name, val in req_headers:each() do
		--print(name, val)
		if name:match('^[Xx]%-') then
			request[ header_cleanup( name) ] = val
		end
	end

	-- X-forwarded-for or similar?
	if config.real_ip_header then
		local real_ip = request[header_cleanup(config.real_ip_header)]

		if real_ip then
			request.REMOTE_ADDR = real_ip
		end
	end

	request.input = stream:get_body_as_file()

	--
	-- Call WSAPI application here
	--
	local rawstatus, wsapi_headers, iter = app.run( request )

	-- XXX: This is an ugly way to do this, would be better to fix
	-- Perihelion maybe? I think that it's a successor project problem.
	local clean_headers = {}
	for k, v in pairs(wsapi_headers) do
		local lk = k:lower()
		if lk == 'content-type'
			and v:lower() == 'text/html' then
				clean_headers[lk] = 'text/html; charset=utf-8'
		else
			clean_headers[lk] = v
		end
	end

	local status
	if type(rawstatus) == 'string' then
		status = rawstatus:match("^(%d+)")
	else
		status = rawstatus
	end

	local res_headers = http_headers.new()
	res_headers:append("Server", config.server_software or 'nginx')
	res_headers:append(":status", status)

	for k, v in pairs(clean_headers) do
		res_headers:append(k, v)
	end

	stream:write_headers(res_headers, false)

	for chunk in iter do
		stream:write_chunk(chunk, false)
	end

	stream:write_chunk("", true)

	output.info(string.format("Web: %s [%s %s] %s",
		request.REMOTE_ADDR,
		request.REQUEST_METHOD,
		request.PATH_INFO,
		rawstatus
	))
end

local cq
local server

local function startup()
	cq = corewait.single()

	if config.nochdir then
		unix.chdir(location)
	end

	if config.pidfile then
		daemonize.pidfile( config.pidfile )
	end

	app = app_f()

	local args = {
		host = config.http_host,
		port = math.floor(config.http_port),
		onstream = http_responder,
		tls = false,
		cq = cq.cq
	}

	if config.unix_socket then
		unix.unlink( config.unix_socket )
		args.host = nil
		args.port = nil
		args.path = config.unix_socket
	end

	server = assert(http_server.listen(args))

	cq:wrap(function()
		cq:poll()
		output.info("Stop Signal Recieved")
		server:close()

		if app.shutdown_hook then
			pcall(app.shutdown_hook)
		end
	end)

	cq:enable_signal_stop()
	assert(server:listen())

end

if config.daemonize then
	daemonize.go( startup )
	output.switch('syslog', 'user', arg[1])
	output.filter( config.log_level )
else
	output.info("Remaining in foreground")
	startup()
end

output.notice("Startup HTTP:", config.http_host, config.http_port)

local last_err = cq:monotime()
local err_count = 0
for err in cq:errors() do
	output.error(err)

	if last_err ~= cq:monotime() then
		last_err = cq:monotime()
		err_count = 0
	else
		err_count = err_count + 1
		if err_count > 10 then
			os.exit(10)
		end
	end
end

if config.unix_socket then
	unix.unlink( config.unix_socket )
end

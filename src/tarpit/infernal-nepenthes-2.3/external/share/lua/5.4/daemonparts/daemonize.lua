#!/usr/bin/env lua5.3

local unix = require 'unix'

--
-- Flush Luacov, if applicable.
--
local function lc_flush()
	if package.loaded['luacov.runner'] then
		package.loaded['luacov.runner'].save_stats()
	end
end


---
-- Provides trouble-free support for forking into the background.
--
-- On completion of @{detach}, The program is it's own session leader,
-- stdin/stdout/stderr are redirected to /dev/null, working directory
-- is switched to '/'. If pidfile_path is provided, the appropriate
-- file is overwritten with the process ID number of the running daemon.
--
-- The optional heartbeat mechanism allows the daemon to signal the
-- launching foreground process that it is ready to handle requests;
-- this allows a user starting the daemon to see errors without viewing
-- log files. If used, the daemon must call either @{ready} or @{error}
-- when fully initalized. Failure to do so means the daemon will never
-- leave the foreground.
--
-- @module daemonparts.daemonize
--
local _M = {}


local state = {}


---
-- Manually write a pid file.
--
-- The file at 'path' will be completely overwritten with the CURRENT
-- process ID number. (Meaning, If called before @{detach}, the pid
-- written will be the parent process, not the background daemon.)
--
-- @param pidfile_path Path to file to be written
--
function _M.pidfile( pidfile_path )

	local f = assert(io.open( pidfile_path, "w" ))
	f:write( tostring(unix.getpid()) .. '\n' )
	f:close()

end


---
-- Forks a process into the background.
--
-- Returns nothing. Throws error on certain conditions that cannot
-- be handled automatically.
--
-- @param heartbeat If true, sets up a heartbeat socket for the daemon
--					to signal the parent that it is up and running.
--					Default is false.
--
function _M.detach( heartbeat )

	local rin, rout
	if heartbeat then
		rin, rout = assert(unix.pipe())
	end

	local pid, err = unix.fork()

	if not pid then
		--
		-- Very difficult to reliably trigger
		--
		-- luacov: disable
		error(err)
		-- luacov: enable
	end

	if pid > 0 then

		if heartbeat then
			unix.close(rout)
			local pipe = unix.fdopen(rin)
			local result = pipe:read("*l")
			pipe:close()

			if result == nil then
				print('Unexpected Process Exit')
				lc_flush()
				os.exit(16)
			end

			if result ~= "" then
				print(result)
				lc_flush()
				os.exit(15)
			end
		end

		lc_flush()
		os.exit(0)
	end


	if heartbeat then
		unix.close(rin)
		state.pipe = unix.fdopen(rout)
		state.pipe_fno = rout
	end


	local null = unix.open("/dev/null", unix.O_RDONLY)
	assert(unix.dup2( null, unix.STDIN_FILENO ))
	assert(unix.dup2( null, unix.STDERR_FILENO ))
	assert(unix.dup2( null, unix.STDOUT_FILENO ))

	assert(unix.setsid())

	--
	-- Switch to the existing root, so in the event the daemon starts
	-- with a working directory on a mounted filesystem, that filesystem
	-- can be unmounted or manipulated later.
	--
	unix.chdir('/')
	--lc_flush()

end


---
-- Daemonize an application, calling the given init function before
-- returning.
--
-- Wraps up all the daemonize pieces into one high-level try/catch
-- that does everything. Daemonizes with @{detach}; calls the given
-- init function wrapped in pcall(); sends the appropriate heartbeat
-- signal when complete.
--
-- @param init_fcn Initalization routine to call before calling @{ready}
--					or @{error}.
--
function _M.go( init_fcn )

	assert(type(init_fcn) == 'function')

	local res, err = pcall( function()
		_M.detach( true )
		init_fcn()
	end)

	if not res then
		_M.error(err)
	end

	_M.ready()

end


--
-- The following are called inside the daemon process, and thus, are
-- nearly impossible to save statistics on.
--
-- luacov: disable

---
-- Send a signal to the parent that the daemon is ready.
--
function _M.ready()

	assert(state.pipe, "heartbeat not enabled")

	state.pipe:write("\n")
	state.pipe:close()
	unix.close(state.pipe_fno)

end


---
-- Tell the parent that the daemon failed to start. Does not return,
-- calls os.exit() on completion.
--
-- @param message Error message intended to be printed to the terminal.
--
function _M.error( message )

	assert(state.pipe, "heartbeat not enabled")

	if #tostring(message) < 1 then
		message = "Daemon failed to start"
	end

	state.pipe:write(tostring(message) .. "\n")
	state.pipe:close()

	os.exit(15)

end
-- luacov: enable


return _M

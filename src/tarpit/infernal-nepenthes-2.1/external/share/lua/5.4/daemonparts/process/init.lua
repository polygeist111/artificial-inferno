#!/usr/bin/env lua5.3

local unix = require 'unix'

---
-- Provides methods for reliably spawning other processes.
--
-- Unlike os.execute(), or io.popen(), all three of stdin, stderr, and
-- stdout are accessible, as is the program's exit code. Both continuing
-- as a forked Lua program, or executing a seperate binary are possible.
--
-- Note that for some unix resources such as file handles, network
-- connections, etc are shared between the parent and child process -
-- and this is very often not what you want! The classic gotcha is a
-- database handle: if the parent has a database connection open, and
-- the child attempts to use it, chaos typically ensues. It's best for
-- the parent to close resources used by the child; if the parent needs
-- them, the child should close everything and reopen what is needed.
--
-- No amount of Lua abstraction can prevent from this. If chaotic, or
-- undefined behavior, or crashes begin to occur, immediately check that
-- the parent and child aren't both accessing the same file handles.
--
-- @module daemonparts.process
--
local _M = {}


---
-- The returned child process object.
--
-- In some cases, fields corresponding to stdin/out/err may be
-- missing if said streams are merged into another one, or if sent
-- to /dev/null.
--
-- @table child
-- @field pid Process ID number of the child
-- @field stdin a Lua file handle connected to the child's stdin
-- @field stdout a Lua file handle connected to the child's stdout
-- @field stderr a Lua file handle connected to the child's stderr
-- @field wait Calls waitpid(), suspending the parent until the
--				child exits. Returns the child's numeric exit code.
-- @field close Closes all file handles in the object. Undefined
-- 				behavior if any handles have already been closed.
--


---
-- Arguments for a forked process.
-- @table fork_args
-- @field entry Entry point function for the child process.
-- @field merge_stderr If true, the child's stderr is set to the same
--						pipe as stdout, merging the two streams.
--						Defaults to false - stdout and stderr will be
--						seperate pipes.
-- @field stdin_null If true, stdin will be connected to /dev/null
--						instead of a pipe. Defaults to false - stdin
--						will be sent to a pipe.
-- @field stdout_null If true, stdout will be connected to /dev/null
--						instead of a pipe. If also specified with
--						merge_stderr, both will go to /dev/null.
--						Defaults to false - stdout is sent to a pipe.
-- @field stderr_null If true, stderr will be connected to /dev/null
--						instead of a pipe. Takes precedence over
--						merge_stderr. Defaults to false - stderr is
--						sent to a pipe.
--


---
-- Forks the current process. Both the parent and the child continue;
-- the parent is given a child object ( see @{child} ), the child
-- enters the provided function and exits when the function returns.
--
-- @param values a @{fork_args} table of parameters for the child
-- @return a @{child} process object
--
function _M.fork( values )

	if type(values) ~= 'table' then
		error("Unknown arguments")
	end

	assert(type(values.entry) == 'function', "No Child Entry Point")

	local in_r, in_w
	local out_r, out_w
	local err_r, err_w
	local null

	if values.stdin_null
		or values.stdout_null
		or values.stderr_null then
			null = assert(unix.open('/dev/null', 'rw'))
	end

	if values.stdin_null then
		in_r = null
	else
		in_r, in_w = assert(unix.pipe())
	end

	if values.stdout_null then
		out_w = null
	else
		out_r, out_w = assert(unix.pipe())
	end

	if values.stderr_null then
		err_w = null
	elseif values.merge_stderr then
		err_w = out_w
	else
		err_r, err_w = assert(unix.pipe())
	end


	local child_pid, err = unix.fork()


	if not child_pid then
		--
		-- Remarkably difficult to trigger.
		--
		-- luacov: disable
		error(err)
		-- luacov: enable
	end

	if child_pid == 0 then
		local function child_setup()

			if not values.stdin_null then
				unix.close(in_w)
			end

			if not values.stdout_null then
				unix.close(out_r)
			end

			if not values.merge_stderr then
				if not values.stderr_null then
					unix.close(err_r)
				end
			end

			unix.dup2(out_w, unix.STDOUT_FILENO)
			unix.dup2(err_w, unix.STDERR_FILENO)
			unix.dup2(in_r, unix.STDIN_FILENO)

			values:entry()
		end

		local res, err2 = pcall(child_setup)
		local ecode = 0

		if not res then
			--
			-- This happens inside the child; luacov has trouble
			-- saving statistics as a result.
			--
			-- luacov: disable
			print(err2)
			ecode = 254
			-- luacov: enable
		end

		os.exit(ecode)
	end

	if not values.stdin_null then
		unix.close(in_r)
	end

	if not values.stdout_null then
		unix.close(out_w)
	end

	if (not values.merge_stderr) or (not values.stderr_null) then
		unix.close(err_w)
	end

	local ret = {
		pid = child_pid
	}

	function ret.wait()
		local p, s, ecode = unix.waitpid( child_pid ) -- luacheck: ignore 211
		return ecode
	end

	function ret.close()
		if ret.stdin then
			ret.stdin:close()
			ret.stdin = nil
		end

		if ret.stdout then
			ret.stdout:close()
			ret.stdout = nil
		end

		if ret.stderr then
			ret.stderr:close()
			ret.stderr = nil
		end
	end

	if not values.stdin_null then
		ret.stdin = unix.fdup(in_w)
		unix.close(in_w)
	end

	if not values.stdout_null then
		ret.stdout = unix.fdup(out_r)
		unix.close(out_r)
	end

	if not values.merge_stderr then
		if not values.stderr_null then
			ret.stderr = unix.fdup(err_r)
			unix.close(err_r)
		end
	end

	if values.stdin_null
		or values.stdout_null
		or values.stderr_null then
			unix.close(null)
	end

	return ret

end


---
-- Forks a child process.
--
-- This is a shortcut wrapper around @{fork}, which takes only a
-- function as it's arguments. All output streams are routed to
-- seperate pipes.
--
-- @param entry Entry point function of the child process.
-- @return A @{child} process object.
--
function _M.fork_fcn( entry )

	return _M.fork {
		entry = entry
	}

end


---
-- Arguments for an executed process.
--
-- The entire command can be given as one string in values.command, with
-- all arguments; in this case, argv should be set to nil.
--
-- Shell-like path searching is done for command; however the full
-- shell is not called, and thus redirections or pipes are not allowed.
--
-- @table exec_args
-- @field command Path to binary being executed
-- @field argv Argument flags to binary to be executed
-- @field merge_stderr If true, the child's stderr is set to the same
--						pipe as stdout, merging the two streams.
--						Defaults to false - stdout and stderr will be
--						seperate pipes.
-- @field stdin_null If true, stdin will be connected to /dev/null
--						instead of a pipe. Defaults to false - stdin
--						will be sent to a pipe.
-- @field stdout_null If true, stdout will be connected to /dev/null
--						instead of a pipe. If also specified with
--						merge_stderr, both will go to /dev/null.
--						Defaults to false - stdout is sent to a pipe.
-- @field stderr_null If true, stderr will be connected to /dev/null
--						instead of a pipe. Takes precedence over
--						merge_stderr. Defaults to false - stderr is
--						sent to a pipe.
--


---
-- Forks a child process, but instead of running Lua code, calls the
-- exec() system call to execute a different binary. Can run any
-- system command within permissions and/or available terminal
-- exceptions.
--
-- @param values An @{exec_args} table defining the process to be
-- 					executed.
-- @return A @{child} process object.
--
function _M.exec( values )

	local exec = {}

	if not values.argv then
		values.argv = {}
	end

	if #(values.argv) == 0 then
		for arg in string.gmatch( values.command, '([^%s]+)' ) do
			exec[ #exec + 1 ] = arg
		end
	else
		exec[1] = values.command

		for i, arg in ipairs( values.argv ) do	-- luacheck: ignore 213
			assert(type(arg) == 'string' or type(arg) == 'number',
					"Invalid command arguments"
				)

			exec[ #exec + 1 ] = arg
		end
	end

	return _M.fork {
		entry = function()
			--
			-- Inside the child, thus stats are difficult to save.
			--
			-- luacov: disable
			assert(unix.execvp( exec[1], exec ))
			-- luacov: enable
		end,

		merge_stderr = values.merge_stderr
	}

end


---
-- Forks a child process, but instead of running Lua code, calls the
-- exec() system call.
--
-- Like @{fork_fcn}, this is a thin wrapper around @{exec}, where the
-- command and any arguments are specified directly. All io streams
-- are sent to individual pipes.
--
-- @param command Path to binary to execute.
-- @param ... Further arguments given to the requested program
-- @return A @{child} child process object.
--
function _M.exec_cmd( command, ... )

	assert(type(command) == 'string', "Invalid command specified")
	local argv = { ... }

	return _M.exec {
		command = command,
		argv = argv,
		merge_stderr = false
	}

end

return _M

#!/usr/bin/env lua5.4

local cqueues = require 'cqueues'
local auxlib = require 'cqueues.auxlib'
local corewait = require 'daemonparts.corewait'
local rand = require 'openssl.rand'


for i = 1, 5 do
	if not rand.ready() then
		-- luacov: disable
		if i == 5 then
			error("Unable to seed")
		end
		-- luacov: enable
	end
end


local _M = {}

local function merge( a, b )
	for i in ipairs(b) do
		a[ #a + 1 ] = b[i]
	end

	return a
end


--
-- Recursive algorithm: Given a number of bytes per second,
-- create two sets of bytes/sec that eat half the time and
-- half the bytes, randomly distributed; split both of those
-- until the delay is under a suitable threshold and/or there's
-- not enough bytes to reasonably split the packet.
--
local function split( delay, bytes )

	if bytes < 2 then
		return { {
			bytes = bytes,
			delay = delay
		} }
	end

	if delay < 500 then
		return { {
			bytes = bytes,
			delay = delay
		} }
	end

	local left_bytes
	if bytes == 2 then
		left_bytes = 1
	else
		left_bytes = rand.uniform( bytes - 1 ) + 1
	end

	local right_bytes = bytes - left_bytes

	local left_delay = rand.uniform( delay - 1 ) + 1
	local right_delay = delay - left_delay

	local left = split( left_delay, left_bytes )
	local right = split( right_delay, right_bytes )

	return merge(left, right)

end

---
-- Generate a unique pattern of when and how much data is sent.
--
function _M.generate_pattern( delay, bytes )

	assert(delay > 0)
	assert(bytes > 0)

	--
	-- The original Nepenthes 1.x algorithm. Easily identified by
	-- it's constant rate of output.
	--
	--local chunk_size = #s
	--local delay = rate

	--repeat
		--chunk_size = chunk_size // 2
		--delay = delay / 2
	--until delay < 1

	--
	-- Fire the recursively splitting packet randomizer. Math is entirely
	-- integer, so convert delay into milliseconds.
	--
	local ret = split( delay * 1000, bytes )

	--
	-- Occasionally, part of the tree the above creates doesn't have
	-- enough bytes for the amount of delay it needs to split up - let's
	-- just reroll those. Add the packet with the most bytes and retry.
	--
	local largest = 1
	local to_fix = {}

	for i, v in ipairs(ret) do
		if v.bytes > ret[largest].bytes then
			largest = i
		end

		if v.delay > 500 then
			to_fix[ #to_fix + 1 ] = i
		end
	end

	if #to_fix > 0 then
		local new_delay = ret[largest].delay
		local new_bytes = ret[largest].bytes

		for i, fix in ipairs( to_fix ) do	-- luacheck: ignore 213
			new_delay = new_delay + ret[fix].delay
			new_bytes = new_bytes + ret[fix].bytes
		end

		to_fix[ #to_fix + 1 ] = largest
		table.sort(to_fix, function( a, b ) return a > b end )

		for i, fix in ipairs(to_fix) do	-- luacheck: ignore 213
			table.remove(ret, fix)
		end


		ret = merge( ret, split( new_delay, new_bytes ) )
	end


	--
	-- Convert delay back into seconds.
	--
	for i, v in ipairs( ret ) do	-- luacheck: ignore 213
		v.delay = v.delay / 1000
	end

	return ret

end


function _M.delay_iterator( s, log_entry, pattern )

	--
	-- Use a coroutine as the actual iterator. This way <close>
	-- works as expected, and the log entry gets marked 'complete'
	-- no matter what happens in the end.
	--
	local start_time = cqueues.monotime()

	local iter = coroutine.create(function()
		local sl <close> = log_entry

		repeat

			local block = table.remove(pattern, 1)

			if not block then
				sl.bytes_sent = sl.bytes_sent + #s
				return s
			end

			local ret = s:sub(1, block.bytes)
			s = s:sub(block.bytes + 1, #s)
			sl.bytes_sent = sl.bytes_sent + #ret
			sl.delay = cqueues.monotime() - start_time
			corewait.poll(block.delay)

			if #s > 0 then
				coroutine.yield( ret )
			else
				return ret
			end

		until #s <= 0

	end)

	--
	-- Iterator wrapper so Microdyne knows what to do with it.
	-- Also use cqueues.auxlib.resume to avoid the 'nested coroutine'
	-- problem - otherwise it would be simpler to just call
	-- coroutine.wrap().
	--
	-- Because to-be-closed values in a coroutine aren't closed on
	-- error, we also need to leverage the garbage collector to
	-- clean up. :(
	--
	return setmetatable({},
	{
		__call = function()

			if coroutine.status( iter ) == 'dead' then
				coroutine.close( iter )
				return nil
			end

			local ret, out = auxlib.resume( iter )

			if not ret then
				coroutine.close( iter )
				error(out)
			end

			return out

		end,

		__gc = function()
				coroutine.close( iter )
		end
	})

end


return _M

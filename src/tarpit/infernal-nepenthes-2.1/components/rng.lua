#!/usr/bin/env lua5.4

local digest = require 'openssl.digest'
local seed = require 'components.seed'


---
-- Simple direct one-to-one line rewrite of the xoshiro128* generator
-- into a pure Lua, reentrant module.
--
-- This is the same algorithm used by Lua itself; however Nepenthes
-- requires multiple independent generator states to function correctly,
-- Thus this interpretation.
--
-- It is very possible it is not entirely correct, due to semantics of
-- Lua and C being very different. However it appears to work well enough
-- (so far) for Nepenthes' purposes.
--
-- For the original algorithm, see: https://prng.di.unimi.it/
--
local _xorshiro = {}

local function rotl( x, k )

	return (x << k) | (x >> (32 - k))

end

function _xorshiro.random( s )

	local result = rotl(  s[1]
						+ s[2]
						+ s[3]
						+ s[4],
					7) + s[1]

	local t = s[2] << 9

	s[3] = s[3] ~ s[1]
	s[4] = s[4] ~ s[2]
	s[2] = s[2] ~ s[3]
	s[1] = s[1] ~ s[4]

	s[2] = s[2] ~ t

	s[4] = rotl(s[4], 11)

	return result

end

function _xorshiro.between( s, upper, lower )

	if (upper - lower) <= 0 then
		error("Requested random value range invalid")
	end

	return ((s:random() % (1 + upper - lower)) + lower)

end



local _M = {}

---
-- Seed a new Xorshiro generator from the SHA256 hash of the URL
-- that was requested. This makes every load of a specific URL look
-- identical.
--
-- Additionally include a 'seed' value that makes the different instances
-- with the same corpus unique.
--
function _M.new( uri )

	local dig = digest.new( 'sha256' )
	dig:update( seed.get() )
	local hash = dig:final( uri )

	local ret = { string.unpack( "jjjj", hash ) }
	return setmetatable( ret, { __index = _xorshiro } )

end

return _M

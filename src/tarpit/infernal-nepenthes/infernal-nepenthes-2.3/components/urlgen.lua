#!/usr/bin/env lua5.4

--
-- Normalize the leading slash on a URI to simplify further logic.
--
local function normalize( uri )
	if uri then
		if uri == '/' then
			uri = ""
		end

		if uri:sub(1, 1) == '/' then
			uri = uri:sub(2, -1)
		end

		if uri ~= '' then
			return uri
		end
	end
end


local _methods = {}

---
-- Create a new URL using the given psuedo-random number generator.
-- Use requested prefix if available; otherwise, default.
--
function _methods.create( this, rng, requested_prefix )

	local size = rng:between( 5, 1 )
	local parts = {}
	local prefix


	requested_prefix = normalize( requested_prefix )

	for i = 1, size do
		parts[ i ] = this.wordlist.choose( rng )
	end

	for i, available_prefix in ipairs(this.prefixlist) do
		if i == 1 then
			prefix = available_prefix
		end

		if requested_prefix == available_prefix then
			prefix = available_prefix
		end
	end

	if prefix then
		table.insert(parts, 1, prefix)
	end

	return '/' .. table.concat(parts, '/')

end

---
-- URL Bogon detection.
--
-- I would like to thank the Slashdot commenter for his very
-- clever idea for detecting tarpits. It's quite clever, I'll
-- admit. It's also easy to defeat, which we do here.
--
-- Since the URLs are built from a known dictionary, it's not
-- hard to sanity check them. If a crawler deliberately munges a
-- URL to force the tarpit to reveal itself, depending on how it
-- does so, there's a very good chance the result will be a 404
-- as expected from a real site.
--
function _methods.check( this, url )

	local is_bogon = false
	local count = 1
	local found_prefix

	for word in url:gmatch('/([^/]+)') do

		if count == 1 and #(this.prefixlist) >= 0 then
			for i, prefix in ipairs(this.prefixlist) do	-- luacheck: ignore 213
				if prefix == word then
					found_prefix = prefix
				end
			end

			if not found_prefix then
				if not this.wordlist.lookup( word ) then
					return true
				end
			end
		else

			if not this.wordlist.lookup( word ) then
				return true
			end

		end

		count = count + 1

	end

	return is_bogon, found_prefix

end



local _M = {}

function _M.new( wordlist, prefixlist )

	assert(wordlist, "Wordlist not provided")


	local clean_prefixes = {}
	if type(prefixlist) == 'table' then
		for i, prefix in ipairs(prefixlist) do	-- luacheck: ignore 213
			local cleaned_prefix = normalize( prefix )
			if cleaned_prefix then
				clean_prefixes[ #clean_prefixes + 1 ] = cleaned_prefix
			end
		end
	end

	local ret = {
		wordlist = wordlist,
		prefixlist = clean_prefixes
	}

	return setmetatable(
		ret, { __index = _methods }
	)

end

return _M

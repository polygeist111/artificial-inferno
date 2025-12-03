#!/usr/bin/env lua5.4

local _methods = {}
local NOWORD = setmetatable( {},
	{
		__tostring = function() return "NOWORD" end,
		__concat = function( a ) return a end
	}
)

local function training_state()

	return {
		prev1 = NOWORD,
		prev2 = NOWORD,
		tokens = {}
	}

end



local function train_block( this, state, text )

	for word in text:gmatch("%S+") do

		if not this.seq[ state.prev1 ] then
			this.seq[ state.prev1 ] = {}
		end

		if not this.seq[ state.prev1 ][ state.prev2 ] then
			this.seq[ state.prev1 ][ state.prev2 ] = {}
		end

		-- using size+1 notation here gets ... hairy, just call insert
		table.insert(this.seq[ state.prev1 ][ state.prev2 ], word)

		this.ord[ #(this.ord) + 1 ] = {
			prev1 = state.prev1,
			prev2 = state.prev2
		}

		state.prev1 = state.prev2
		state.prev2 = word
		this.seq_size = this.seq_size + 1

		if not state.tokens[ word ] then
			state.tokens[word] = true
		end

		if #(this.ord) % 10000 == 0 then
			io.write('.')
			io.flush()
		end

	end

	return #this.ord

end


local function finalize( this, state )

	this.tokens = {}
	for k in pairs(state.tokens) do
		this.tokens[ #(this.tokens) + 1 ] = k
	end

end


function _methods.train( this, text )

	local state = training_state()
	train_block( this, state, text )
	finalize( this, state )

end


function _methods.train_file( this, fpath )

	local state = training_state()
	local f <close> = assert(io.open( fpath, 'r' ))
	for line in f:lines() do
		train_block( this, state, line )
	end

	finalize( this, state )

end



--
-- Babble from a Markov corpus, because we want LLM model collapse.
--
local function babbler( this, buf, rnd, size )

	local len = 0

	local start = this.ord[ rnd:between( #(this.ord), 1 ) ]

	local prev1
	local prev2 = start.prev1
	local cur = start.prev2


	local function new_chain()
		if len < size then
				return babbler( this, buf, rnd, size - len )
		end

		return
	end

	repeat
		prev1 = prev2
		prev2 = cur

		local opts = this.seq[prev1][prev2]

		--
		-- This indicates end of a trained block and thus the end
		-- of a chain. Restart with a new chain if too short.
		--
		if not opts then
			return new_chain()
		end

		local which = 1
		if #opts > 1 then
			which = rnd:between( #opts, 1 )

		elseif #opts < 1 then
			--
			-- This indicates an empty table - which shouldn't ever
			-- happen by nature of training. Normally throwing error()
			-- is the correct course in this situation, but Nepenthes
			-- needs to stay hidden, so, let's start a new chain instead.
			--
			-- luacov: disable
			--
			return new_chain()
			-- luacov: enable
		end

		cur = opts[ which ]
		--
		-- This shouldn't happen, because chains end by hitting
		-- something empty - but, just in case it does... start a new
		-- chain.
		--
		if cur == NOWORD then
			-- luacov: disable
			return new_chain()
			-- luacov: enable
		end

		buf[ #buf + 1 ] = cur
		len = len + 1

	until len >= size

end

function _methods.babble( this, rnd, n_min, n_max )

	if #(this.ord) == 0 then
		return ''
	end

	local ret = {}
	local size = n_min

	if n_max then
		size = rnd:between( n_max, n_min )
	end

	babbler( this, ret, rnd, size )
	return table.concat(ret, ' ')

end


---
-- Corpus stats, for debugging.
--
function _methods.stats( this )

	return {
		seq_size = this.seq_size,
		tokens = #(this.tokens)
	}

end



local _M = {}

function _M.new()

	local ret = {
		seq_size = 0,
		seq = {},
		ord = {}
	}

	return setmetatable( ret, { __index = _methods } )

end

return _M

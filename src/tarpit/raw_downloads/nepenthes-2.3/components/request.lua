#!/usr/bin/env lua5.4

local config = require 'components.config'

local _methods = {}

function _methods.is_bogon( this )

	return this._is_bogon

end

function _methods.urllist( this )

	assert( (not this._is_bogon), 'Unable to load URLs: bogon request' )

	local ret = {}
	local count = #(this.template.data.links or {})

	if this.template.data.link_array then
		count = count + this.rng:between(
			this.template.data.link_array.max_count,
			this.template.data.link_array.min_count
		)
	end

	for i = 1, count do
		ret[ i ] = {
			description = this.wordlist.choose( this.rng ),
			link = this.urlgenerator:create( this.rng, this.prefix )
		}
	end

	return ret

end

function _methods.load_markov( this )

	assert( (not this._is_bogon), 'Unable to load markov: bogon request' )

	local function paragraph( m_min, m_max )
		return this.markov:babble( this.rng,
			m_min,
			m_max
		)
	end


	-- Markov time
	for i, v in ipairs( this.template.data.markov ) do	-- luacheck: ignore 213
		this.vars[v.name] = paragraph( v.min, v.max )
	end

	for i, v in ipairs( this.template.data.markov_array or {} ) do	-- luacheck: ignore 213

		local count = this.rng:between( v.max_count, v.min_count )
		local ret = {}

		for pi = 1, count do	-- luacheck: ignore 213
			ret[ #ret + 1 ] = paragraph( v.markov_min, v.markov_max )
		end

		this.vars[v.name] = ret
	end

end


function _methods.send_delay( this )

	if this.zero_delay then
		return 0
	end

	return this.rng:between(
		this.max_wait or config.max_wait,
		this.min_wait or config.min_wait
	)

end


function _methods.render( this )

	assert( (not this._is_bogon), 'Unable to render: bogon request' )

	local links = this:urllist()

	-- Named links
	for i, v in ipairs( this.template.data.links ) do	-- luacheck: ignore 213
		this.vars[ v.name ] = table.remove( links )
	end

	-- Optional link array
	this.vars['links'] = links

	return this.template:render( this.vars )

end



local _M = {}

function _M.new( silodata )

	return setmetatable( silodata, { __index = _methods } )

end

return _M

#!/usr/bin/env lua5.4

local output = require 'daemonparts.output'

local config = require 'components.config'
local wordlist = require 'components.wordlist'
local urlgen = require 'components.urlgen'
local template = require 'components.template'
local markov = require 'components.markov'
local rng_factory = require 'components.rng'
local request = require 'components.request'

local silos
local wordlists
local corpuses

local default_silo

local _M = {}

---
-- Roll through the configuration, instantiating and Markov corpuses,
-- URL generators, and templates as appropriate.
--
function _M.setup()

	silos = {} -- destroy pre-existing config
	wordlists = {}
	corpuses = {}
	default_silo = nil

	for i, siloconfig in ipairs( config.silos ) do	-- luacheck: ignore 213

		if not wordlists[ siloconfig.wordlist ] then
			wordlists[ siloconfig.wordlist ] = wordlist.new( siloconfig.wordlist )
			output.debug( "Loaded Wordlist:", siloconfig.wordlist )
		end

		if not corpuses[ siloconfig.corpus ] then
			local m = markov.new()
			m:train_file( siloconfig.corpus )
			corpuses[ siloconfig.corpus ] = m

			output.debug( "Trained Markov Corpus:", siloconfig.wordlist )
		end

		output.debug("Configure silo:", siloconfig.name)
		silos[ siloconfig.name ] = {
			urlgenerator = urlgen.new( wordlists[ siloconfig.wordlist ], siloconfig.prefixes ),
			wordlist = wordlists[ siloconfig.wordlist ],
			template = template.load( siloconfig.template ),
			markov = corpuses[ siloconfig.corpus ],
			name = siloconfig.name,
			min_wait = siloconfig.min_wait,
			max_wait = siloconfig.max_wait,
			zero_delay = siloconfig.zero_delay
		}

		if siloconfig.default then
			if default_silo then
				error('Multiple default silos')
			end

			default_silo = silos[ siloconfig.name ]
		end

	end

	--
	-- Still none? Choose the first
	--
	if not default_silo then
		default_silo = silos[ config.silos[1].name ]
	end

	assert(default_silo, 'No default silo found')

end


function _M.count()
	return #(config.silos)
end


function _M.new_request( requested_silo, url )

	assert(type(silos) == 'table', 'Silo module not initialized')

	local s = default_silo
	if silos[requested_silo] then
		s = silos[requested_silo]
	end

	local is_bogon, prefix = s.urlgenerator:check( url )

	local ret = {
		_is_bogon = is_bogon,
		prefix = prefix,
		silo = s.name,
		wordlist = s.wordlist,
		urlgenerator = s.urlgenerator,
		template = s.template,
		markov = s.markov,
		min_wait = s.min_wait,
		max_wait = s.max_wait,
		zero_delay = s.zero_delay,
		url = url,
		vars = {}
	}

	if not ret._is_bogon then
		ret.rng = rng_factory.new( url )
	end

	return request.new( ret )

end


return _M

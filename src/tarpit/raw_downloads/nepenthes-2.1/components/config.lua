#!/usr/bin/env lua5.4

local cp = require 'daemonparts.config_loader'
local yaml = require 'tinyyaml'

---
-- Default configuration
--
return cp.prepare {

	cp.parse_function( yaml.parse ),

	http_host = '::1',
	http_port = 8893,
	unix_socket = cp.default_nil('string'),
	templates = cp.array {
		'./templates'
	},
	nochdir = false,
	daemonize = false,
	pidfile = cp.default_nil('string'), -- ./pidfile',
	real_ip_header	= 'X-Forwarded-For',
	silo_header = 'X-Silo',
	seed_file = cp.default_nil('string'), -- './seed.txt',
	log_level = 'info',
	stats_remember_time = 3600,
	min_wait = 5,
	max_wait = 10,

	--markov = cp.default_nil {
		--cp.array {
			--name = 'default',
			--type = 'classic',
			--corpus = cp.not_nil('string')
		--}
	--},

	--urlgen = cp.default_nil {
		--cp.array {
			--name = 'default',
			--type = 'classic',
			--wordlist = cp.not_nil('string')
		--}
	--},

	silos = cp.array {
		{
			name = 'default',
			--markov = 'default',
			--urlgen = 'default',
			template = 'default',
			min_wait = 5,
			max_wait = 10,
			zero_delay = false,
			--markov_min = 10,
			--markov_max = 50,
			default = false,
			corpus = cp.not_nil('string'),
			wordlist = cp.not_nil('string'),
			prefixes = cp.array {
				cp.default_nil('string')
			}
		}
	}

}

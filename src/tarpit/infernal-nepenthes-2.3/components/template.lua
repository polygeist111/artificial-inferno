#!/usr/bin/env lua5.4

local lustache = require 'lustache'
local yaml = require 'tinyyaml'
local unix = require 'unix'

local cl = require 'daemonparts.config_loader'

local config = require 'components.config'


local function template_schema()
	return cl.prepare {
		cl.parse_function( yaml.parse ),

		markov = cl.array {
			{
				name = 'title',
				['min'] = 5,
				['max'] = 10
			},
			{
				name = 'header',
				['min'] = 5,
				['max'] = 10
			},
			{
				name = 'content',
				['min'] = 25,
				['max'] = 200
			}
		},

		markov_array = cl.default_nil (
			cl.array {
				{
					name = cl.default_nil('string'),
					min_count = 2,
					max_count = 5,
					markov_min = 25,
					markov_max = 200
				}
			}
		),

		links = cl.array {
			{
				name = 'footer_link',
				depth_min = 1,
				depth_max = 5,
				--description_min = 1,
				--description_max = 5
			}
		},

		link_array = cl.default_nil ({
			name = 'links',
			min_count = 5,
			max_count = 8,
			depth_min = 1,
			depth_max = 5,
			--description_min = 1,
			--description_max = 5
		})
	}
end


local _methods = {}

function _methods.render( this, vars )

	return lustache:render( this.code, vars, {})

end



local _M = {}

---
-- Pull a template code from disk.
--
function _M.load( template_name )

	local ret = {
		body = '',
		data = template_schema()
	}

	local template_path
	local is_file = false

	for i, possible_path in ipairs( config.templates ) do	-- luacheck: ignore 213
		template_path = string.format(
			"%s/%s.lmt",
			possible_path,
			template_name
		)

		local test = unix.stat( template_path )
		if test then
			is_file = unix.S_ISREG( test.mode )
			break
		end
	end

	if not is_file then
		error(string.format('Template %s not found', template_name))
	end

	local template_file <close> = assert(io.open(template_path, "r"))

	local yaml_code = template_file:read("*line")
	local body = ''

	if yaml_code == '---' then
		for line in template_file:lines() do
			if line == '...' then
				break
			elseif line then
				yaml_code = yaml_code .. '\n' .. line
			end
		end
	else
		body = yaml_code
		yaml_code = ''
	end

	ret.code = body .. template_file:read("*all")

	if #yaml_code > 0 then
		cl.load_string( ret.data, yaml_code )
	end

	if #(ret.code) > 1 then
		ret.is_valid = true
	else
		ret.is_valid = false
	end

	return setmetatable( ret, { __index = _methods } )

end


return _M

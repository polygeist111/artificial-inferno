#!/usr/bin/env lua5.4

local paths = {
	';%s/?.lua',
	';%s/?/init.lua',
	';%s/external/share/lua/5.4/?.lua',
	';%s/external/share/lua/5.4/?/init.lua'
}

local location = os.getenv('LUA_APP_LOCATION')
if location then
	for i, path in ipairs(paths) do	--luacheck: ignore 213
		package.path = package.path .. string.format(path, location)
	end
end

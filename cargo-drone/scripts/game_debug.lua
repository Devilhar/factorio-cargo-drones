
local game_debug = {}

function game_debug.print(...) end
function game_debug.error(...) end
function game_debug.call(func, ...) end

--[[
function game_debug.print(...)
	game.print(...)
end

function game_debug.error(...)
	game.error(...)
end

function game_debug.call(func, ...)
	func(...)
end
]]--
return game_debug

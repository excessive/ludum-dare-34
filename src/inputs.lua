local tactile = require "tactile"
local tiny    = require "tiny"

-- Define inputs
local k = tactile.key
local m = tactile.mouseButton
local g = function(button)
	return tactile.gamepadButton(button, 1)
end

-- Keyboard as axes
local kb_ws = tactile.binaryAxis(k "w",    k "s")
local kb_tvl = tactile.binaryAxis(k "lshift", k "lctrl")

-- Alternate keys (for teamviewer, but also why not)
local kb_tvr = tactile.binaryAxis(k "rshift", k "rctrl")
local kb_ud = tactile.binaryAxis(k "up",   k "down")

-- Gamepad axes
local left_y    = tactile.analogStick("lefty",  1)
local right_y   = tactile.analogStick("righty", 1)

local kb_return = function()
	return love.keyboard.isDown("return") and
		not (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))
end

return tiny.system {
	sys = {
		enter           = tactile.newButton(kb_return),
		escape          = tactile.newButton(k "escape"),
		mute            = tactile.newButton(k "pause"),
		change_language = tactile.newButton(k "f9"),
		show_overscan   = tactile.newButton(k "f10"),
	},
	game = {
		-- all u need is y axes...
		left_y      = tactile.newAxis(kb_ws, kb_tvl, left_y),
		right_y     = tactile.newAxis(kb_ud, kb_tvr, right_y),

		-- ...and menu buttons
		menu        = tactile.newButton(k "escape", m(2),      g "back",  g "start", g "y"),
		menu_back   = tactile.newButton(k "escape", m(3),      g "back",  g "b"),
		menu_action = tactile.newButton(kb_return,  k "space", g "a"),
		menu_up     = tactile.newButton(k "up",     k "w",     g "dpup"),
		menu_down   = tactile.newButton(k "down",   k "s",     g "dpdown"),
		menu_left   = tactile.newButton(k "left",   k "a",     g "dpleft"),
		menu_right  = tactile.newButton(k "right",  k "d",     g "dpright")
	},
	update = function(self)
		for k, v in pairs(self.sys) do
			if v.update then
				v:update()
			end
		end
		if console.visible then
			return
		end
		for k, v in pairs(self.game) do
			-- Only need to update buttons.
			if v.update then
				v:update()
			end
		end
	end
}

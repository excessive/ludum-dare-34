-- Game flags (beyond love's own)
-- TODO: Read a preferences file for conf stuff?
FLAGS = {
	game_version = "LD34:FINAL",
	debug_mode   = false, --not love.filesystem.isFused(),
	show_perfhud = false
}

-- Specify window flags here because we use some of them for the error screen.
local flags = {
	title          = "🍡 Dangomari 🍡",
	width          = 1280,
	height         = 720,
	fullscreen     = false,
	fullscreentype = "desktop",
	msaa           = 4,
	vsync          = true,
	resizable      = true,
	highdpi        = true
}

local use = {
	teamviewer_mode = FLAGS.debug_mode,
	love3d       = true,
	hot_reloader = FLAGS.debug_mode,
	fps_in_title = FLAGS.debug_mode,
	handle_screenshots = true,
	event_poll   = true,
	love_draw    = true,
	perfhud      = true,
	console      = true,
	console_font = {
		path = "assets/fonts/unifont-7.0.06.ttf",
		size = 16
	},
	log_header     = [[Please report this on GitHub at https://github.com/excessive/ludum-dare-34 or
send a DM on Twitter to @LandonManning or @shakesoda.]]
}

function love.conf(t)
	t.version = "0.10.0"
	for k, v in pairs(flags) do
		t.window[k] = v
	end
	t.gammacorrect = true -- Always use gamma correction.
	t.accelerometerjoystick = false -- Disable joystick accel on mobile
	t.modules.physics = not use.love3d -- Box2D is useless for 3D
	io.stdout:setvbuf("no") -- Don't delay prints.
end

--------------------------------------------------
-- /!\ Here be dragons. Thou art forewarned /!\ --
--------------------------------------------------

-- Add folders to require search path
love.filesystem.setRequirePath(
	love.filesystem.getRequirePath()
	.. ";libs/?.lua;libs/?/init.lua"
	.. ";src/?.lua;src/?/init.lua"
)


-- Helpers for hot reloading the whole game.
-- I sure hope you didn't have any other modules named "fire", because you sure
-- don't anymore!
local fire = {}
package.loaded.fire = fire
local pkg_cache = {}
local callbacks = {}
local world_saved = false

--- Save packages from startup so we can reset to this state at a later time.
-- This does *not* reset _G, so if you want to persist things between resets,
-- use globals.
function fire.save_the_world()
	world_saved = true
	pkg_cache = {}
	callbacks = {}
	for k, v in pairs(package.loaded) do
		pkg_cache[k] = v
	end
	for k, v in pairs(love) do
		callbacks[k] = v
	end
	pkg_cache.main = nil
end

--- Restore saved cache so Lua has to reload everything.
function fire.reset_the_world()
	if not world_saved then
		print "[Fire] No state saved to reset the world to."
		return
	end
	-- unload
	if love.quit then
		love.quit()
	end
	for k, v in pairs(package.loaded) do
		package.loaded[k] = pkg_cache[k]
	end
	for _, k in ipairs {
		'focus', 'keypressed', 'keyreleased', 'mousefocus', 'mousemoved',
		'mousepressed', 'mousereleased', 'wheelmoved', 'textedited', 'textinput',
		'resize', 'visible', 'gamepadaxis', 'gamepadpressed', 'gamepadreleased',
		'joystickadded', 'joystickaxis', 'joystickhat', 'joystickpressed',
		'lowmemory', 'joystickreleased', 'joystickremoved', 'filedropped',
		'directorydropped', 'update', 'quit', 'load', 'draw'
	} do
		love[k] = nil
	end
	for k, v in pairs(callbacks) do
		love[k] = v
	end
	love.event.clear()
	love.audio.stop()
	love.audio.setVolume(1.0)

	-- Clean out everything, just to be sure.
	collectgarbage("collect")
	-- Note: you have to collect TWICE to make sure everything is GC'd.
	collectgarbage("collect")

	require "main"

	print "Reloading game!"

	return love.run()
end

-- A few convenience functions.
--- Open save folder.
function fire.open_save()
	love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
end

--- Toggle fullscreen.
function fire.toggle_fullscreen()
	love.window.setFullscreen(not love.window.getFullscreen())
end

--- Take screenshot and save it to the save folder with the current date.
-- If the Screenshots folder does not exist, it will attempt to create it.
function fire.take_screenshot()
	love.filesystem.createDirectory("Screenshots")

	local ss   = love.graphics.newScreenshot()
	local path = string.format("%s/%s.png",
		"Screenshots",
		os.date("%Y-%m-%d_%H-%M-%S", os.time())
	)
	local f = love.filesystem.newFile(path)
	ss:encode("png", path)
end

local l3d_loaded     = false
local console_loaded = false
local perfhud_loaded = false

function love.run()
	local fire = require "fire"
	local reset = false

	if use.love3d and not l3d_loaded then
		l3d_loaded = true
		require "love3d".import(true, false)
	end

	if use.console and not console_loaded then
		console_loaded = true
		console = require "console"
		local params = use.console_font and use.console_font or { path = false, size = 14 }
		local have_font = params.path and love.filesystem.isFile(params.path) or false
		local font
		if have_font then
			font = love.graphics.newFont(params.path, params.size)
		else
			font = love.graphics.newFont(params.size)
		end
		console.load(font)
		console.update(0)
	end

	if use.perfhud and not perfhud_loaded then
		perfhud_loaded = true
		perfhud = require("perfhud")(10, 110, 200, 100, 1/30)
	end

	if console then
		if use.hot_reloader then
			console.clearCommand("restart")
			console.defineCommand(
				"restart",
				"Reload game files and restart the game.",
				function()
					reset = true
				end
			)
		end
		if use.perfhud then
			console.clearCommand("toggle-perfhud")
			console.defineCommand(
				"toggle-perfhud",
				"Toggle framerate overlay.",
				function()
					FLAGS.show_perfhud = not FLAGS.show_perfhud
				end
			)
		end
	end

	if use.hot_reloader then
		fire.save_the_world()
	end

	if love.math then
		love.math.setRandomSeed(os.time())
		for i=1,3 do love.math.random() end
	end

	if love.event then
		love.event.pump()
	end

	if love.load then love.load(arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0
	local last_update = -0.5 -- update immediately!

	-- Main loop time.
	while true do
		-- Process events.
		if love.event then
			love.event.pump()
			if use.event_poll then
				for name, a,b,c,d,e,f in love.event.poll() do
					if name == "keypressed" and a == "f5" then
						reset = true
					end
					if use.handle_screenshots then
						if name == "keypressed" and a == "f11" then
							fire.open_save()
						end
						if name == "keypressed" and a == "f12" then
							fire.take_screenshot()
						end
					end
					if name == "keypressed" and a == "return" then
						if (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
							fire.toggle_fullscreen()
						end
					end
					if name == "keypressed" and a == "escape" and
						(love.keyboard.isDown "lshift" or love.keyboard.isDown "rshift")
					then
						love.event.quit()
					end
					if use.teamviewer_mode then
						if name == "keypressed" and a == "5" then
							reset = true
						end
						if name == "keypressed" and a == "backspace" then
							love.event.quit()
						end
					end
					if name == "quit" then
						if not love.quit or not love.quit() then
							return
						end
					end
					if not console or not console[name] or not (type(console[name]) == "function" and console[name](a,b,c,d,e,f)) then
						love.handlers[name](a,b,c,d,e,f)
					end
				end
			end
		end

		if use.hot_reloader and reset then
			break
		end

		-- Update dt, as we'll be passing it to update
		local skip_time = false
		if love.timer then
			love.timer.step()
			dt = love.timer.getDelta()
			if love.keyboard.isDown "tab" then
				dt = dt * 4
			else
				-- Cap dt to 30hz - this results in slowmo, but that's less
				-- bad than the things that enormous deltas can cause.
				if dt > 1/30 then
					-- Record full delta if we're skipping frames, so that
					-- it can still be handled.
					skip_time = dt
				end
				dt = math.min(dt, 1/30)
			end
		end

		-- Call update and draw
		if love.graphics and love.graphics.isActive() then
			-- Discarding here causes issues with NVidia 352.41 on Linux
			-- love.graphics.discard()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()

			-- make sure the console is always updated
			if console then console.update(dt) end
			 -- will pass 0 if love.timer is disabled
			if love.update then love.update(dt, skip_time) end

			if use.love_draw and love.draw then love.draw() end

			if console then console.draw() end

			if use.perfhud then
				perfhud:update(skip_time or dt)
				if FLAGS.show_perfhud then
					perfhud:draw()
				end
			end

			love.graphics.present()

			-- Run a fast GC cycle so that it happens at predictable times.
			-- This prevents GC work from building up and causing hitches.
			collectgarbage("step")

			-- surrender just a little bit of CPU time to the OS
			if love.timer then love.timer.sleep(0.001) end

			local now = love.timer.getTime()
			if use.fps_in_title and now - last_update >= 0.25 then
				last_update = now
				love.window.setTitle(string.format(
					"%s - %s (%2.4fms/f %2.2ffps)",
					flags.title,
					FLAGS.game_version,
					love.timer.getAverageDelta(),
					love.timer.getFPS()
				))
			end
		end
	end

	if use.hot_reloader and reset then
		return fire.reset_the_world()
	end
end

local debug, print = debug, print

local function error_printer(msg, layer)
	local filename = "crash.log"
	local file     = ""
	local time     = os.date("%Y-%m-%d %H:%M:%S", os.time())
	local err      = debug.traceback(
		"Error: " .. tostring(msg), 1+(layer or 1)
	):gsub("\n[^\n]+$", "")

	if love.filesystem.isFile(filename) then
		file = love.filesystem.read(filename)
	end

	if file == "" then
		file = use.log_header .. "\n\n"
	else
		file = file .. "\n\n"
	end

	file = file .. string.format([[
=========================
== %s ==
=========================

%s]], time, err)

	love.filesystem.write(filename, file)
	print(err)
end

function love.errhand(msg)
	function rgba(color)
		local a = math.floor((color / 16777216) % 256)
		local r = math.floor((color /    65536) % 256)
		local g = math.floor((color /      256) % 256)
		local b = math.floor((color) % 256)
		return r, g, b, a
	end

	msg = tostring(msg)

	error_printer(msg, 2)

	if not love.window or not love.graphics or not love.event then
		return
	end

	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, flags.width, flags.height)
		if not success or not status then
			return
		end
	end

	love.window.setTitle(flags.title)

	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end
	love.graphics.reset()
	local font_path = "assets/fonts/NotoSans-Regular.ttf"
	local head, font
	if love.filesystem.isFile(font_path) then
		head = love.graphics.setNewFont(font_path, math.floor(love.window.toPixels(22)))
		font = love.graphics.setNewFont(font_path, math.floor(love.window.toPixels(14)))
	else
		print "Error screen font missing, using default instead."
		head = love.graphics.setNewFont(math.floor(love.window.toPixels(22)))
		font = love.graphics.setNewFont(math.floor(love.window.toPixels(14)))
	end

	love.graphics.setBackgroundColor(rgba(0xFF1E1E2C))
	love.graphics.setColor(255, 255, 255, 255)

	-- Don't show conf.lua in the traceback.
	local trace = debug.traceback("", 2)

	love.graphics.clear(love.graphics.getBackgroundColor())
	love.graphics.origin()

	local err = {}

	table.insert(err, msg.."\n")

	for l in string.gmatch(trace, "(.-)\n") do
		if not string.match(l, "boot.lua") then
			l = string.gsub(l, "stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end

	local c = string.format("Please locate the crash.log file at: %s\n\nI can try to open the folder for you if you press F11!", love.filesystem.getSaveDirectory())
	local h = "Oh no, it's broken!"
	local p = table.concat(err, "\n")

	p = string.gsub(p, "\t", "")
	p = string.gsub(p, "%[string \"(.-)\"%]", "%1")

	local function draw()
		local pos = love.window.toPixels(70)
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.setColor(rgba(0xFFF0A3A3))
		love.graphics.setFont(head)
		love.graphics.printf(h, pos, pos, love.graphics.getWidth() - pos)
		love.graphics.setFont(font)
		love.graphics.setColor(rgba(0xFFD2D5D0))
		love.graphics.printf(c, pos, pos + love.window.toPixels(40), love.graphics.getWidth() - pos)
		love.graphics.setColor(rgba(0xFFA2A5A0))
		love.graphics.printf(p, pos, pos + love.window.toPixels(120), love.graphics.getWidth() - pos)
		love.graphics.present()
	end

	local reset = false

	while true do
		love.event.pump()

		for e, a, b, c in love.event.poll() do
			if use.teamviewer_mode then
				if e == "keypressed" and a == "5" then
					reset = true
					break
				end
				if e == "backspace" then
					return
				end
			end
			if e == "quit" then
				return
			elseif e == "keypressed" and a == "f11" then
				fire.open_save()
			elseif e == "keypressed" and a == "f12" then
				fire.take_screenshot()
			elseif e == "keypressed" and a == "f5" then
				reset = true
				break
			elseif e == "keypressed" and a == "escape" and (love.window.getFullscreen()) then
				return
			elseif e == "keypressed" and a == "escape" then --or e == "mousereleased" then
				local name = love.window.getTitle()
				if #name == 0 then name = "Game" end
				local buttons = {"OK", "Cancel"}
				local pressed = love.window.showMessageBox("Quit?", "Quit "..name.."?", buttons)
				if pressed == 1 then
					return
				end
			end
		end

		if use.hot_reloader and reset then
			break
		end

		draw()

		if love.timer then
			love.timer.sleep(0.1)
		end
	end

	if use.hot_reloader and reset then
		return xpcall(fire.reset_the_world, love.errhand)
	end
end

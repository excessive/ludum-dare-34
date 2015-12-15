-- prevent FFI redefinition crashes with some dummy requires
do
	local cpml = require "cpml"
	local iqm  = require "iqm"
	require("fire").save_the_world()
end

Scene = require "scene"

-- Load global preferences
-- NOTE: Except for Scene, globals are ALLCAPS so you avoid them.
if love.filesystem.isFile("preferences.json") then
	local json = require "dkjson"
	local p = love.filesystem.read("preferences.json")
	PREFERENCES = json.decode(p)
else
	PREFERENCES = {
		language = "en",
		volume   = 0.7
	}
end

local tiny   = require "tiny"
local anchor = require "anchor"

local show_overscan = false
local muted = false

function love.load()
	local cpml = require "cpml"

	-- Set overscan
	anchor:set_overscan(0.1)

	-- Create world
	local world = tiny.world()
	world.debug    = false
	world.tickrate = 1/120
	world.tick     = 0
	world.octree   = cpml.octree(15, cpml.vec3(0, 0, 0), 0.01, 1.0)

	local notifications = world:addSystem(require("notifications"))
	function world.notify(msg, ding, icon)
		if ding then
			notifications.ding:stop()
			notifications.ding:play()
		end

		notifications:add(msg, icon)
	end

	world.language = require("languages").load(PREFERENCES.language)
	love.audio.setVolume(PREFERENCES.volume)

	world.inputs = world:addSystem(require "inputs")

	world:addSystem(require "systems.acceleration")
	world:addSystem(require "systems.movement")

	world.camera_system = world:addSystem(require "systems.camera")
	world.renderer = world:addSystem(require "systems.render")

	-- local default_screen = "scenes.credits" -- FLAGS.debug_mode and "scenes.gameplay" or "scenes.splash"
	local default_screen = "scenes.splash"
	anchor:update()
	Scene.set_world(world)
	Scene.switch(require(initial_screen or default_screen))
	Scene.register_callbacks()

	love.resize(love.graphics.getDimensions())
end

-- YOU CAN'T STOP ME, FOR I AM TOO POWERFUL
local unstoppable_systems = tiny.requireAll("no_pause")
local update_systems      = tiny.requireAll(tiny.rejectAny("no_pause", "draw_system", "physics_system"))
local physics_systems     = tiny.requireAll("physics_system")
local draw_systems        = tiny.requireAll("draw_system")

function love.resize(w, h)
	local top = Scene.current()

	-- Resize UI or whatever else needs doing.
	if top.resize then top:resize(w, h) end

	-- Update canvases
	top.world.renderer:resize(w, h)
end

function love.update(dt)
	anchor:update()

	local top    = Scene.current()
	local world  = assert(top.world)

	-- Make sure camera and render are last.
	local index = world:getSystemCount()
	if index > 0 then
		world:setSystemIndex(world.camera_system, index)
		world:setSystemIndex(world.renderer, index)
	end

	local update_dt = (top.paused or console.visible) and 0 or dt

	-- Update world
	world:update(update_dt, update_systems)

	if update_dt > 0 then
		-- Update physics systems at a constant tickrate
		world.tick = world.tick + dt
		while world.tick >= world.tickrate do
			world.tick = world.tick - world.tickrate
			world:update(world.tickrate, physics_systems)
		end
	end

	world:update(update_dt, draw_systems)

	-- Notifications/overlays go last, so they don't get drawn over.
	world:update(dt, unstoppable_systems)

	-- Toggle overscan
	if FLAGS.debug_mode then
		if world.inputs.sys.show_overscan:pressed() then
			show_overscan = not show_overscan
		end
	end

	-- Display overscan
	if show_overscan then
		love.graphics.setColor(180, 180, 180, 200)
		love.graphics.setLineStyle("rough")
		love.graphics.line(anchor:left(), anchor:center_y(), anchor:right(), anchor:center_y())
		love.graphics.line(anchor:center_x(), anchor:top(), anchor:center_x(), anchor:bottom())
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.rectangle("line", anchor:bounds())
	end

	-- Toggle mute
	if world.inputs.sys.mute:pressed() then
		if love.audio.getVolume() < 0.01 then
			love.audio.setVolume(PREFERENCES.volume)
			muted = false
		else
			love.audio.setVolume(0)
			muted = true
		end
		world.notify(muted and "Muted" or "Unmuted", true)
	end

	-- Cycle language
	if world.inputs.sys.change_language:pressed() then
		world.language.cycle(world)
	end
end

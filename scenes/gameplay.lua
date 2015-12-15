local tiny       = require "tiny"
local cpml       = require "cpml"
local anchor     = require "anchor"
local map_loader = require "map"
local geo        = require "geometry"
local memoize    = require "memoize"
local timer      = require "timer"
local convoke    = require "convoke"

local gp = tiny.system {}

-- Magic numbers!
local start_time     = 120
local increase_time  = 5
local increase_scale = 0.1
local good_weight    = 200
local play_voice     = 15
local cooldown       = 3

function gp:enter()
	love.graphics.setBackgroundColor(50, 50, 50)

	-- Background music
	self.bgm = love.audio.newSource("assets/bgm/game.ogg")
	self.bgm:setLooping(true)
	self.bgm:play()
	self.bgm:setVolume(PREFERENCES.volume)

	self.timer = timer.new()
	self.state = { opacity = 1, volume = 0 }

	self.hungry = love.graphics.newImage("assets/images/hungry.png")
	self.font = love.graphics.newFont("assets/fonts/NotoSans-Bold.ttf", 20)

	self.voice_timer = 0
	self.cooldown = false

	convoke(function(continue, wait)
		-- prevent accidental instant skipping
		self.timer.add(0.5, function()
			self.input_locked = false
		end)
		self.timer.tween(2.0, self.state, { opacity = 0 }, 'out-quad')
		self.timer.tween(5.0, self.state, { volume = PREFERENCES.volume }, 'out-quad')
		-- self.timer.add(60, continue())
		-- wait()
		-- self:transition_out()
	end)()


	-- vocals
	self.vocals = {
		chatter = {
			love.audio.newSource(select(2, self.world.language("gameplay/king-of-dangos"))),
			love.audio.newSource(select(2, self.world.language("gameplay/bigger"))),
			love.audio.newSource(select(2, self.world.language("gameplay/house"))),
		},
		collect = {
			love.audio.newSource(select(2, self.world.language("gameplay/nom"))),
			love.audio.newSource(select(2, self.world.language("gameplay/belly"))),
			dango = love.audio.newSource(select(2, self.world.language("gameplay/fusion"))),
		},
		over = {
			real = love.audio.newSource(select(2, self.world.language("gameplay/family"))),
			good = love.audio.newSource(select(2, self.world.language("gameplay/biggest"))),
		}
	}

	-- Time limit
	self.time = start_time

	-- Time in game
	self.game_time = 0

	-- Game is playable
	self.playing = true

	-- Which game end?
	self.ending = "bad"

	-- We don't want this in package.loaded, so don't use require()
	map_loader.load(self.world, "assets/levels/level.lua")

	self.world:addEntity {
		mesh     = require("iqm").load("assets/models/sky.iqm"),
		position = cpml.vec3(),
		scale    = cpml.vec3(50, 50, 50),
		sky      = true
	}

	self.world.level_entities["Terrain"].roughness = 0.1

	self.player           = assert(self.world.level_entities["player"])
	self.player.scale     = cpml.vec3(0.5, 0.5, 0.5)
	self.player.roughness       = 1.0
	self.player.possessed       = true
	self.player.speed           = 0.2
	self.player.mass            = 10.0
	self.player.weight          = 10.0
	self.player.max_velocity    = 0.025
	self.player.camera_distance = 1.7
	self.player.camera_offset   = 0.25
	self.player.camera_near     = 0.001
	self.player.camera_far      = 100.0
	self.player.center_offset   = 0.051 -- slight inaccuracy to fix shadows

	self.camera = self.world:addEntity {
		camera       = true,
		fov          = 25,
		near         = 0.0001,
		far          = 100.0,
		exposure     = 1.25,
		position     = cpml.vec3(0, 0, 0),
		orbit_offset = cpml.vec3(0, 0, -1),
		offset       = cpml.vec3(0, 0, -0.25)
	}

	self.world:addEntity {
		light         = true,
		direction     = cpml.vec3(0.2, 0.1, 0.7):normalize(),
		color         = { 1.25, 1.23, 0.95 },
		position      = cpml.vec3(3, -0.1, 0),
		intensity     = 1.5,
		range         = 3.8,
		fov           = 25,
		near          = 1.0,
		far           = 100.0,
		bias          = 1.0e-5,
		depth         = 50,
		cast_shadow   = true,
		follow_player = false
	}

	local player = self.player
	self.world:addSystem(tiny.processingSystem {
		filter  = tiny.requireAll("light", "cast_shadow", "follow_player"),
		process = function(self, entity, dt)
			if entity.follow_player then
				entity.position = player.position + entity.direction * 20
			end
		end
	})

	self.world:addEntity {
		light     = true,
		direction = cpml.vec3(0, 0, -1),
		color     = { 0, 0.5, 1 },
		intensity = 0.05,
		specular  = { 0, 0, 0 }
	}

	-- self.world:addEntity {
	-- 	light     = true,
	-- 	direction = cpml.vec3(0.3, 0.3, 0.7):normalize(),
	-- 	color     = { 1, 1, 0.5 },
	-- 	intensity = 0.25
	-- }

	self.world:addEntity {
		light     = true,
		direction = cpml.vec3(-0.1, -0.1, 1):normalize(),
		color     = { 0, 0.6, 1 },
		intensity = 0.125,
		specular  = { 0, 0, 0 }
	}

	self.player_control = self.world:addSystem(require "systems.player_controller")

	-- Always refresh before playing with system indices...
	self.world:refresh()
	self.world:setSystemIndex(self.world.inputs, 1)
	self.world:setSystemIndex(self.player_control, 2)

	self.left = nil
end

function gp:update(dt)
	if not self.bgm then
		return
	end
	local player = self.player
	local dangos = 0

	-- print(self.bgm)

	self.timer.update(dt)
	-- self.bgm:setVolume(self.state.volume)

	self.game_time = self.game_time + dt

	-- voice cooldown
	if self.cooldown then
		self.cooldown = self.cooldown - dt

		if self.cooldown <= 0 then
			self.cooldown = false
		end
	end

	-- Play random chatter
	self.voice_timer = self.voice_timer + dt
	if self.voice_timer >= play_voice and not self.cooldown then
		self.vocals.chatter[love.math.random(1, #self.vocals.chatter)]:play()
		self.voice_timer = self.voice_timer - play_voice
		self.cooldown = cooldown
	end

	if self.playing then
		-- Decrease time
		self.time = self.time - dt

		-- End game
		if self.time <= 0 then
			self.time    = 0
			self.playing = false
			-- print(self.ending, self.weight)
			-- shhhhh
			-- self.bgm:setVolume(PREFERENCES.volume / 2)
		end

		-- Update aabb in world space
		player.aabb = geo.get_aabb(player)

		for name, entity in pairs(self.world.level_entities) do
			-- Count remaining dangos
			if name:sub(1, 5) == "Dango" then
				dangos = dangos + 1
			end

			-- Please don't kill the world or the player
			if entity.mesh and not (entity.ghost or entity.actor) then
				-- Static entity
				local aabb = {
					position = entity.aabb.center,
					extent   = entity.aabb.size / 2
				}

				-- Player entity
				local obb = {
					position = player.aabb.center,
					extent   = player.aabb.size / 2,
					rotation = cpml.mat4():rotate(
						player.orientation:to_axis_angle(),
						cpml.vec3(0, 0, 1)
					)
				}

				local object_volume = aabb.extent.x * aabb.extent.y * aabb.extent.z
				local player_volume = obb.extent.x * obb.extent.y * obb.extent.z

				-- Collision detection
				local edible = (object_volume / 2) < player_volume
				if cpml.intersect.aabb_obb(aabb, obb) then
					if edible then
						-- What did I intersect?
						console.i(string.format("%s was delicious!", entity.name))

						-- Collecting a dango increases time
						if name:sub(1, 5) == "Dango" then
							self.time = self.time + increase_time

							if not self.cooldown then
								self.vocals.collect.dango:play()
								self.cooldown = cooldown
							end
						elseif not self.cooldown then
							self.vocals.collect[love.math.random(1, #self.vocals.collect)]:play()
							self.cooldown = cooldown
						end

						-- Destroy entity
						self.world.octree:remove(entity)
						self.world:removeEntity(entity)
						self.world.level_entities[name] = nil

						local growth = 1.0 + object_volume / player_volume / 4
						-- print(growth)

						-- Grow! ( ͡° ͜ʖ ͡°)
						player.scale  = player.scale * growth
						-- player.speed  = player.speed * growth
						player.aabb   = geo.get_aabb(player)
						player.weight = (
							player.mass * player.scale.x * player.scale.y * player.scale.z
						)
						print("weight", player.weight)
					else
						-- console.i("I can't eat that! %s is too big!", entity.name)
					end
				end
			end
		end

		-- You weigh enough but didn't collect all the dangos
		if player.weight >= good_weight and dangos > 0 then
			self.ending = "good"
		-- You weight enough and collected all the dangos
		elseif player.weight >= good_weight and dangos == 0 then
			self.ending = "real"
		end
	end

	if self.time <= 0 then
		self.playing = false

		if self.ending ~= "bad" then
			self.vocals.over[self.ending]:play()
			self:transition_out()
		else
			self:transition_out()
		end
	end
end

function gp:draw()
	love.graphics.push()
	love.graphics.translate(anchor:right(), anchor:bottom())
	local scale = 7
	local size = math.sqrt(100) * scale
	local size = math.sqrt(self.player.weight or 1) * scale
	love.graphics.setColor(0, 0, 0, 220)
	love.graphics.circle("fill", 0, 0, math.sqrt(400) * scale)
	if self.player.weight >= good_weight then
	-- if false then
		love.graphics.push()
		love.graphics.rotate(self.time / 2)
		love.graphics.setColor(100, 255, 120)
		love.graphics.circle("fill", 0, 0, size)
		local n = 16
		local lstart = size + 4
		local lend   = lstart + 10
		local ldist  = 5
		for i=1,n do
			love.graphics.rotate(math.pi*2/n)
			love.graphics.setColor(cpml.color.from_hsv((i * 50) % 360, 0.5, 255))
			love.graphics.circle("fill", size, 0, 20)
			love.graphics.setLineWidth(4)
			love.graphics.setColor(0, 0, 0)
			love.graphics.line(lstart,  ldist, lend,  ldist)
			love.graphics.line(lstart, -ldist, lend, -ldist)
			love.graphics.setLineWidth(1)
		end
		love.graphics.pop()
		love.graphics.setColor(cpml.color.from_hsv(100, 0.65, 90))
	else
		love.graphics.setColor(190, 200, 190)
		love.graphics.circle("fill", 0, 0, math.max(size, 40))
		love.graphics.setColor(190, 215, 220)
		love.graphics.circle("line", 0, 0, math.sqrt(good_weight) * scale)
		love.graphics.setColor(210, 235, 240)
		love.graphics.draw(self.hungry, -self.hungry:getWidth()/2, -self.hungry:getHeight()/2)

		love.graphics.setColor(cpml.color.from_hsv(100, 0.65, 50))
		if self.time < 15 and math.floor(self.time * 5) % 2 == 0 then
			love.graphics.setColor(cpml.color.from_hsv(0, 0.95, 255))
		end
	end
	local str = string.format("%2.2fs", self.time)
	local width = self.font:getWidth(str)
	love.graphics.setFont(self.font)
	love.graphics.printf(str, -width/2, -self.font:getHeight()/2, width, "center")

	love.graphics.pop()

	love.graphics.setColor(0, 0, 0, 255 * self.state.opacity)
	love.graphics.rectangle(
		"fill", 0, 0,
		love.graphics.getWidth(),
		love.graphics.getHeight()
	)
end

function gp:leave()
	self.world:clearEntities()
	self.world:removeSystem(self.player_control)
	self.bgm:stop()
	self.bgm = nil
	self.left = true
end

function gp:transition_out()
	-- convoke(function(continue, wait)
		-- self.timer.tween(1, self.state, { opacity = 1, volume = 0 }, 'in-out-quad', continue())
		-- wait()
		-- self.bgm:stop()
		-- self.timer.add(1, continue())
		-- wait()
		Scene.switch(require "scenes.credits")
	-- end)()
end

return gp

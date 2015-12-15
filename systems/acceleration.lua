local tiny = require "tiny"
local cpml = require "cpml"

return tiny.processingSystem {
	filter = tiny.requireAll("mass", "force", "velocity"),
	physics_system = true,
	zero = cpml.vec3(),
	process = function(self, entity, dt)
		local mass = entity.mass

		if entity.scale then
			-- mass = mass * entity.scale.x * entity.scale.y * entity.scale.z
		end

		local acceleration = mass > 0 and (entity.force / mass) * dt or self.zero
		assert(cpml.vec3.isvector(acceleration))

		-- Avoid instancing new vectors.
		entity.velocity.x = entity.velocity.x + acceleration.x
		entity.velocity.y = entity.velocity.y + acceleration.y
		entity.velocity.z = entity.velocity.z + acceleration.z

		if entity.max_velocity then
			local speed = entity.velocity:len()
			if speed > entity.max_velocity then
				local scale = speed / entity.max_velocity
				entity.velocity.x = entity.velocity.x / scale
				entity.velocity.y = entity.velocity.y / scale
				entity.velocity.z = entity.velocity.z / scale
			end
		end
	end
}

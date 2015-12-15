local tiny = require "tiny"

local function falloff(axis, speed)
	local a = math.max(math.abs(axis) - speed, 0)
	if axis >= 0 then
		return a
	else
		return -a
	end
end

return tiny.processingSystem {
	filter = tiny.requireAll("position", "velocity"),
	physics_system = true,
	process = function(self, entity, dt)
		entity.position.x = entity.position.x + entity.velocity.x
		entity.position.y = entity.position.y + entity.velocity.y
		entity.position.z = entity.position.z + entity.velocity.z

		local falloff_speed = 0.975
		entity.velocity.x = entity.velocity.x * falloff_speed
		entity.velocity.y = entity.velocity.y * falloff_speed
		entity.velocity.z = entity.velocity.z * falloff_speed
	end
}

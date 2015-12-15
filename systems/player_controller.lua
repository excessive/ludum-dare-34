local tiny = require "tiny"
local cpml = require "cpml"

local function get_triangle(ray, objects, ret)
	for _, o in ipairs(objects) do
		if o.data.triangle then
			local hit = cpml.intersect.ray_triangle(ray, o.data)
			if hit then
				if type(ret) == "table" then
					table.insert(ret, {
						object = o.data,
						hit    = hit
					})
				else
					return o.data
				end
			end
		end
	end
end

return tiny.processingSystem {
	filter  = tiny.requireAll("possessed", "orientation"),
	physics_system = true,
	gravity = 9.81 / 1.5,
	onAdd = function(self, entity)
		entity.orientation_offset = cpml.quat(0, 0, 0, 1)
	end,
	process = function(self, entity, dt)
		local gi = self.world.inputs.game
		local l, r = gi.left_y:getValue(), gi.right_y:getValue()
		local spin = -(r - l)
		local speed = -(r + l) * entity.speed

		speed = math.max(speed, -entity.speed / 2)

		entity.orientation = entity.orientation * cpml.quat.rotate(spin * dt, cpml.vec3.unit_z)
		entity.direction   = entity.orientation * cpml.vec3.unit_y
		entity.direction   = entity.direction:normalize()

		local reject = self:reject(entity)
		if reject then
			-- <MattRB_> when a collision is detected apply a force with the
			-- strength of the dot product between the object's relative
			-- velocities and direction of contact.
			local power = entity.velocity:dot(reject)
			-- console.i("REJECTED => %2.4f", power)
			entity.velocity = entity.velocity + reject * -power * 1.01
			entity.force    = reject * -power
		else
			entity.force = entity.direction * speed
		end

		local rot_speed = entity.velocity:len() * 15
		local forward = entity.direction:normalize():dot(entity.velocity:normalize()) >= 0
		rot_speed = rot_speed * (forward and -1 or 1)
		entity.orientation_offset = entity.orientation_offset * cpml.quat.rotate(rot_speed, cpml.vec3.unit_x)

		-- Camera
		local camera = self.world.camera_system.active_camera
		camera.direction      = entity.direction
		camera.position       = entity.position
		camera.orbit_offset.z = -entity.camera_distance * entity.scale.z
		camera.offset.z       = -entity.camera_offset * entity.scale.z
		camera.near           = entity.camera_near * entity.scale.z
		camera.far            = entity.camera_far * entity.scale.z

		local old_position = entity.position:clone()

		self:fix_camera(entity, camera)

		local correct, normal = self:snap_to_terrain(entity)
		local up      = cpml.vec3.unit_z
		local side    = up:cross(normal)
		local forward = side:cross(normal)
		local slope   = 1+up:dot(-normal)

		entity.force = entity.force + forward * slope * self.gravity

		if (entity.position - correct):len() < self.gravity * entity.scale.z * dt then
			-- Dangos are positioned in the center instead of bottom so this is
			-- used to offset it.
			entity.position = correct + cpml.vec3(0, 0, entity.center_offset * entity.scale.z)
		else
			entity.force = entity.force + (-cpml.vec3.unit_z * self.gravity)
			entity.position.z = math.max(entity.position.z, correct.z)
		end
	end,
	fix_camera = function(self, entity, camera)
		local up         = cpml.vec3.unit_z
		local down       = -cpml.vec3.unit_z
		local camera_pos1 = camera.position + (camera.direction * camera.orbit_offset.z)
		local rays     = {
			{
				camera_pos = camera_pos1,
				position   = camera_pos1 + up * entity.center_offset * entity.scale + camera.near,
				direction  = down
			}
		}
		for _, ray in ipairs(rays) do
			local triangles = {}
			self.world.octree:cast_ray(ray, get_triangle, triangles)
			if triangles[1] and triangles[1].hit.z > ray.camera_pos.z then
				local new_dir = (entity.position - triangles[1].hit):normalize()
				camera.direction = new_dir
			end
		end
	end,
	reject = function(self, entity)
		local ray     = {
			position  = entity.position,
			direction = entity.force:normalize()
		}
		local triangles = {}
		self.world.octree:cast_ray(ray, get_triangle, triangles)

		local triangle
		for i, t in ipairs(triangles) do
			if not triangle
			or entity.position:dist(t.hit) < entity.position:dist(triangle.hit) then
				triangle = t
			end
		end

		if not triangle or (
			triangle and triangle.hit:dist(entity.position) > entity.center_offset * entity.scale:len()
		) then
			return false
		end

		return triangle.object.normal
	end,
	snap_to_terrain = function(self, entity)
		local up      = cpml.vec3.unit_z
		local down    = -cpml.vec3.unit_z
		local ray     = {
			position  = entity.position + up * entity.center_offset * entity.scale,
			direction = down
		}
		local triangles = {}
		self.world.octree:cast_ray(ray, get_triangle, triangles)

		local triangle
		for i, t in ipairs(triangles) do
			if not triangle
			or entity.position:dist(t.hit) < entity.position:dist(triangle.hit) then
				triangle = t
			end
		end

		-- Can't climb slopes that are too steep, but we can go down them.
		if triangle and (
			triangle.object.normal:dot(up) < 0.85 and
			triangle.hit.z > entity.position.z
		) then
			return entity.position_old, triangle.object.normal
		else
			return (triangle and triangle.hit or entity.position),
			       (triangle and triangle.object.normal or cpml.vec3.unit_z)
		end
	end
}

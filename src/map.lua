local cpml = require "cpml"
local iqm = require "iqm"
local geo = require "geometry"

local function load(world, path)
	local chunk = love.filesystem.load(path)
	local ok, map = pcall(chunk)
	if not ok then
		console.e("Unable to load map: %s", map)
		return false
	end

	world.level_entities = {}
	for _, data in ipairs(map.objects) do
		local entity = {}
		for k, v in pairs(data) do
			entity[k] = v
		end
		if entity.path then
			assert(
				love.filesystem.isFile(entity.path),
				string.format("%s doesn't exist!", entity.path)
			)
			entity.mesh = assert(iqm.load(entity.path, entity.actor))
		end

		entity.position	 = cpml.vec3(entity.position)
		entity.orientation = cpml.quat(entity.orientation)
		entity.scale		 = cpml.vec3(entity.scale)
		entity.velocity	 = cpml.vec3(0, 0, 0)
		entity.force		 = cpml.vec3(0, 0, 0)
		entity.direction = entity.orientation * cpml.vec3.unit_y
		world.level_entities[entity.name] = entity
		world:addEntity(entity)

		if world.octree and entity.mesh then
			entity.aabb = geo.get_aabb(entity)
			world.octree:add(entity, entity.aabb)

			for i, triangle in ipairs(entity.mesh.triangles) do
				local polygon = {
					triangle = true,
					normal = (
						cpml.vec3(triangle[1].normal) +
						cpml.vec3(triangle[2].normal) +
						cpml.vec3(triangle[3].normal)
					):normalize(),
					cpml.vec3(triangle[1].position) + entity.position,
					cpml.vec3(triangle[2].position) + entity.position,
					cpml.vec3(triangle[3].position) + entity.position
				}

				local aabb = geo.calculate_aabb(polygon)
				world.octree:add(polygon, aabb)
			end
		end
	end

	-- print(world.octree.count)

	return true
end

return {
	load = load
}

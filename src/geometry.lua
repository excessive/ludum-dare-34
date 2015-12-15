local cpml = require "cpml"

local function mk_obb(min, max, rot)
	local function p(x, y, z)
		return rot * { x, y, z, 1 }
	end
	local vertices = {
		p(min.x, min.y, max.z), p(max.x, min.y, max.z), p(max.x, max.y, max.z), p(min.x, max.y, max.z), -- front
		p(min.x, min.y, min.z), p(min.x, max.y, min.z), p(max.x, max.y, min.z), p(max.x, min.y, min.z), -- back
		p(min.x, max.y, min.z), p(min.x, max.y, max.z), p(max.x, max.y, max.z), p(max.x, max.y, min.z), -- top
		p(min.x, min.y, min.z), p(max.x, min.y, min.z), p(max.x, min.y, max.z), p(min.x, min.y, max.z), -- bottom
		p(max.x, min.y, min.z), p(max.x, max.y, min.z), p(max.x, max.y, max.z), p(max.x, min.y, max.z), -- right
		p(min.x, min.y, min.z), p(min.x, min.y, max.z), p(min.x, max.y, max.z), p(min.x, max.y, min.z)  -- left
	}
	local indices = {
		 1,  2,  3,  1,  3,  4, -- front
		 5,  6,  7,  5,  7,  8, -- back
		 9, 10, 11,  9, 11, 12, -- top
		13, 14, 15, 13, 15, 16, -- bottom
		17, 18, 19, 17, 19, 20, -- right
		21, 22, 23, 21, 23, 24, 24  -- left
	}
	local layout = { { "VertexPosition", "float", 3 } }
	local m = love.graphics.newMesh(layout, vertices, "triangles", "static")
	m:setVertexMap(indices)
	return m
end

local function mk_line(s, direction, length)
	local function p(v) return { v.x, v.y, v.z } end
	local e = s + direction * (length or 1)
	local thickness = 0.1
	local up = cpml.vec3.unit_z
	local side = direction:cross(cpml.vec3.unit_z)
	local vertices = {
		p(s - up * thickness),
		p(e - up * thickness),
		p(s + up * thickness),
		p(e + up * thickness)
	}
	local indices = { 1, 2, 3, 2, 3, 4 }
	local layout = { { "VertexPosition", "float", 3 } }
	local m = love.graphics.newMesh(layout, vertices, "triangles", "static")
	m:setVertexMap(indices)
	return m
end


-- Calculate aabb for individual polygons in a mesh
local function calculate_aabb(polygon)
	local aabb = {
		min = cpml.vec3(polygon[1]),
		max = cpml.vec3(polygon[1])
	}

	for i, vertex in ipairs(polygon) do
		if i > 1 then
			aabb.min.x = math.min(aabb.min.x, vertex.x)
			aabb.min.y = math.min(aabb.min.y, vertex.y)
			aabb.min.z = math.min(aabb.min.z, vertex.z)

			aabb.max.x = math.max(aabb.max.x, vertex.x)
			aabb.max.y = math.max(aabb.max.y, vertex.y)
			aabb.max.z = math.max(aabb.max.z, vertex.z)
		end
	end

	aabb.size   = aabb.max - aabb.min
	aabb.center = (aabb.max + aabb.min) / 2

	return aabb
end

-- Calculate aabb for objects in world space
local function get_aabb(entity)
	local base      = entity.mesh.bounds.base
	local scale_min = (entity.scale * cpml.vec3(base.min)) + entity.position:clone()
	local scale_max = (entity.scale * cpml.vec3(base.max)) + entity.position:clone()
	local half_size = (scale_max - scale_min) / 2

	local aabb  = {}
	aabb.center = (scale_max + scale_min) / 2
	aabb.size   = half_size * 2
	aabb.min    = aabb.center + half_size * -1
	aabb.max    = aabb.center + half_size

	return aabb
end

return {
   mk_obb         = mk_obb,
   mk_line        = mk_line,
	calculate_aabb = calculate_aabb,
	get_aabb       = get_aabb
}

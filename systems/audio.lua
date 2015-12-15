local tiny = require "tiny"
local cpml = require "cpml"

local system = tiny.processingSystem {
	filter = tiny.requireAll("sound")
}

function system:onAddToWorld()
	love.audio.setDistanceModel("inverse")
end

function system:onAdd(entity)
	entity.sound:setLooping(entity.sound_looping == nil and true or entity.sound_looping)
	entity.sound:setVolume(entity.sound_volume or 1)
	entity.sound:play()
end

function system:onRemove(entity)
	entity.sound:stop()
end

-- Update sound positions as objects move.
function system:process(entity, dt)
	if entity.sound:getChannels() > 1 then
		return
	end
	local pos = entity.position or cpml.vec3()
	if entity.parent_matrix then
		local m = entity.parent_matrix
		local p = m * { pos.x, pos.y, pos.z, 1 }
		pos = cpml.vec3(p[1], p[2], p[3])
	end
	entity.sound:setPosition(pos:unpack())
end

return system

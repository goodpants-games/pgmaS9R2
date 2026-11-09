local Consts = require("game.consts")

---@class game.entities.Entity: batteries.Class
---@overload fun(x:number?, y:number?, w:number?, h:number?):game.entities.Entity
---@field msg any
---@field update fun(self:game.entities.Entity)?
---@field postUpdate fun(self:game.entities.Entity)?
local Entity = batteries.class {
    name = "game.entities.Entity"
}

local nextEntityId = 0

function Entity:new(x, y, w, h)
    ---@type game.World
    self.world = nil
    self._removeOnFrameEnd = false

    self.msg = batteries.pubsub()
    self.tags = {}
    
    -- base properties --

    self.name = ""
    --- unique numeric id
    self.id = nextEntityId
    nextEntityId = nextEntityId + 1

    self.x = x or 0.0
    self.y = y or 0.0

    self.xVel = 0.0
    self.yVel = 0.0

    -- collision properties --

    self.collision = false
    self.width = w or 0.0
    self.height = h or 0.0
    self.restitution = 0.0
    self.colGroup = Consts.COLGROUP_DEFAULT
    self.colMask = Consts.COLGROUP_ALL
    -- touch monitor properties --

    self.touchMonitor = false
    ---@type game.entities.Entity[]?
    self._touching = nil
    ---@type game.entities.Entity[]?
    self._prevTouching = nil

    -- render properties --
    self.zIndex = 0
    self.zOffset = 0 -- how many pixels this sprite is lifted from the ground
    self.visible = true
    ---@type (fun(self:game.entities.Entity)|table)?
    self.render = nil
end

---Remove this entity from its world.
function Entity:remove()
    if self.world then
        self.world:removeEntity(self)
    end
end

---@param tag string
function Entity:addTag(tag)
    self.tags[tag] = true
end

---@param tag any
function Entity:removeTag(tag)
    self.tags[tag] = nil
end

---@param tag string
function Entity:hasTag(tag)
    return not not self.tags[tag]
end

---@param msg string
---@param ... any
function Entity:publish(msg, ...)
    self.msg:publish(msg, self, ...)
end

function Entity:getCenterX()
    return self.x + self.width / 2
end

function Entity:getCenterY()
    return self.y + self.height / 2
end

function Entity:getCenterPos()
    return self.x + self.width / 2,
           self.y + self.height / 2
end

---@return game.entities.Entity[]
function Entity:getOverlappingEntities()
    return self._touching or {}
end

return Entity
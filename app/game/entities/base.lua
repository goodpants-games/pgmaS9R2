local Consts = require("game.consts")

---@class game.entities.Entity: batteries.Class
---@overload fun(x:number?, y:number?, w:number?, h:number?):game.entities.Entity
---@field msg any
---@field update fun(self:game.entities.Entity)?
---@field postUpdate fun(self:game.entities.Entity)?
---@field render fun(self:game.entities.Entity)|table
local Entity = batteries.class {
    name = "game.entities.Entity"
}

function Entity:new(x, y, w, h)
    ---@type game.World
    self.world = nil
    self._removeOnFrameEnd = false
    
    -- base properties --
    self.name = ""

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

    -- render properties --
    self.zIndex = 0

    self.msg = batteries.pubsub()
end

---Remove this entity from its world.
function Entity:remove()
    if self.world then
        self.world:removeEntity(self)
    end
end

return Entity
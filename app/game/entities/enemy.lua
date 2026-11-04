local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")

---@class game.entities.Enemy: game.entities.Entity
local Enemy = batteries.class {
    extends = require("game.entities.base")
}

function Enemy:new(x, y)
    self:super(centeredRect(x, y, 14, 14))
    self.collision = true
    self.colGroup = Const.COLGROUP_NPC
    self.render = RectRenderer(1.0, 0.0, 0.0)

    self.cooldown = 12 -- in frames
    self.lastFire = 0
end

function Enemy:update()
    --cooldown
    self.lastFire = self.lastFire + 1

    if self.lastFire < self.cooldown then
        return
    end

    local world = self.world
    if not world["player"] then
        return
    end

    local distX = (world.player.x - self.x)
    local distY = (world.player.y - self.y)
    local dirX = distX / math.length(distX, distY)
    local dirY = distY / math.length(distX, distY)

    --local raycastDist = world:raycast(self.x, self.y, distX*100, distY*100)
    local sightRaycast = world:raycast(self.x, self.y, dirX*distX, dirY*distY)
    if not sightRaycast then
        local e = world:newEntity("enemyProjectile", self.x + (self.width/2), self.y + (self.height/2))
        e.xVel = dirX * 4
        e.yVel = dirY * 4
        world:addEntity(e)

        self.lastFire = 0
    end
end

return Enemy
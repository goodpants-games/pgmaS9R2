local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")
local Util = require("game.util")

---@class game.entities.Enemy: game.entities.Entity
local Enemy = batteries.class {
    extends = require("game.entities.base")
}

function Enemy:new(x, y)
    self:super(centeredRect(x, y, 14, 14))
    self:addTag("enemy")

    self.collision = true
    self.colGroup = Const.COLGROUP_NPC
    self.render = RectRenderer(1.0, 0.0, 0.0)

    self.fireWait = 40 -- in frames
    self.fireTimer = 0

    self.dead = false

    self.gunSight = Util.newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight.maxBounces = 1

    self.msg:subscribe("removingFromWorld", self._removing)
    self.msg:subscribe("hit", self._hit)
end

function Enemy:_removing()
    self.gunSight:remove()
end

function Enemy:_hit(hitVx, hitVy)
    hitVx, hitVy = math.normalize(hitVx, hitVy)

    self:removeTag("enemy")

    -- Die . Now.
    self.xVel = hitVx * 3
    self.yVel = hitVy * 3
    self.dead = true
    self.zIndex = -10
    self.gunSight:remove()
    self.gunSight = nil
    self.msg:unsubscribe("hit", self._hit)
    self.render.r = self.render.r * 0.5
    self.render.g = self.render.g * 0.5
    self.render.b = self.render.b * 0.5

    local cx, cy = self:getCenterPos()
    for _, ent in ipairs(self.world:findEntitiesWithTag("enemy")) do
        local ocx, ocy = ent:getCenterPos()
        local dist = math.distance(cx, cy, ocx, ocy)
    end
end

function Enemy:update()
    local world = self.world
    if not world.player then
        return
    end
    
    if self.dead then
        self.xVel = self.xVel * 0.9
        self.yVel = self.yVel * 0.9
        return
    end

    local centerX, centerY = self:getCenterPos()
    local playerCenterX, playerCenterY = world.player:getCenterPos()
    local playerDx = playerCenterX - centerX
    local playerDy = playerCenterY - centerY

    local sightRaycast = world:raycast(centerX, centerY, playerDx, playerDy, Const.COLGROUP_DEFAULT)
    if not sightRaycast then
        if not self.gunSight.world then
            self.world:addEntity(self.gunSight)
        end

        local dx, dy = math.normalize(playerDx, playerDy)
        self.gunSight:updateSight(centerX, centerY, dx, dy)

        self.fireTimer = self.fireTimer + 1
        if self.fireTimer >= self.fireWait then
            print("fire the weapon")
            self.fireTimer = 0
            Sceneman.switchScene("entry")
        end
    else
        if self.gunSight.world then
            self.gunSight:remove()
            self.gunSight:clearSight()
        end

        self.fireTimer = 0
    end
    -- if not sightRaycast then
    --     local e = world:newEntity("enemyProjectile", self.x + (self.width/2), self.y + (self.height/2))
    --     if e then
    --         e.xVel = dirX * 4
    --         e.yVel = dirY * 4
    --         world:addEntity(e)

    --         self.lastFire = 0
    --     end
    -- end
end

return Enemy
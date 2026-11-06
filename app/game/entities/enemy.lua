local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")
local Util = require("game.util")
local EnemyAi = require "game.enemy_ai"

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
    self.moveSpeed = 2.0

    self.noticeWait = 20
    self.fireWait = 40 -- in frames
    self.fireTimer = 0

    self.dead = false

    self.gunSight = Util.newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight.maxBounces = 1

    self._hasMoveTarget = false
    self._moveTargetX = 0
    self._moveTargetY = 0

    ---@type game.EnemyAi?
    self.ai = nil

    self.msg:subscribe("removingFromWorld", self._removing)
    self.msg:subscribe("hit", self._hit)
    self.msg:subscribe("alertDeath", self._alertDeath)
end

function Enemy:_removing()
    self.gunSight:remove()
    self.ai = nil
end

function Enemy:_hit(hitVx, hitVy)
    hitVx, hitVy = math.normalize(hitVx, hitVy)

    -- Die . Now.
    self.dead = true
    self.msg:unsubscribe("hit", self._hit)
    self:removeTag("enemy")

    -- alert any enemies in sight line to perceived origin of bullet
    for _, ent in ipairs(self.world:findEntitiesWithTag("enemy")) do
        ---@cast ent game.entities.Enemy
        if self:_hasSightLineTo(ent) then
            ent:publish("alertDeath", self.x, self.y, hitVx, hitVy)
        end
    end

    self.xVel = hitVx * 3
    self.yVel = hitVy * 3
    self.zIndex = -10

    self.gunSight:remove()
    self.gunSight = nil

    -- darken color
    self.render.r = self.render.r * 0.5
    self.render.g = self.render.g * 0.5
    self.render.b = self.render.b * 0.5
end

function Enemy:_alertDeath(victimX, victimY, hitVx, hitVy)
    self._moveTargetX = victimX
    self._moveTargetY = victimY
    self._hasMoveTarget = true

    -- make enemy yellow for debug purposes
    self.render.g = 1.0
    print("it's yellow ??")

    self.ai = EnemyAi(self.world)
    self.ai:markTilesFromDirection(victimX, victimY, hitVx, hitVy, 2)
    self.ai:markTilesInSightOf(self.x, self.y, 1)
end

function Enemy:_hasSightLineTo(oent)
    local cx, cy = self:getCenterPos()
    local ocx, ocy = oent:getCenterPos()
    local dx = ocx - cx
    local dy = ocy - cy

    local hit = not self.world:raycast(cx, cy, dx, dy, Const.COLGROUP_DEFAULT)
    return hit, dx, dy
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

    if self._hasMoveTarget then
        local dx,dy = self._moveTargetX - self.x, self._moveTargetY - self.y
        if math.length(dx, dy) < 10 then
            print("STOP IT")
            self._hasMoveTarget = false
        else
            dx, dy = math.normalize(dx, dy)
            self.xVel = dx * self.moveSpeed
            self.yVel = dy * self.moveSpeed
        end
    else
        self.xVel = 0
        self.yVel = 0
    end

    local sightRaycast, playerDx, playerDy =
        self:_hasSightLineTo(world.player)

    if sightRaycast then
        if not self.gunSight.world then
            self.world:addEntity(self.gunSight)
        end

        local cx, cy = self:getCenterPos()
        local dx, dy = math.normalize(playerDx, playerDy)
        self.gunSight:updateSight(cx, cy, dx, dy)

        self.fireTimer = self.fireTimer + 1
        if self.fireTimer == self.noticeWait then
            print("notice")
            self._hasMoveTarget = true
            self._moveTargetX, self._moveTargetY = world.player:getCenterPos()
        end

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
    if self.ai then
        self.ai:update()
    end
end

return Enemy
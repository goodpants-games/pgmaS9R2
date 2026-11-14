local Util = require("game.util")
local Resmgr = require("game.resmgr")
local EnemyAi = require("game.enemy_ai")

---@class game.entities.MaidEnemy: game.entities.Enemy
local MaidEnemy = batteries.class {
    extends = require("game.entities.base_enemy")
}

function MaidEnemy:new(x, y)
    self:super(Util.centeredRect(x, y, 13, 12))
    self:addTag("enemy")

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/maid_enemy.json"))
    self.render.sprite.alignment = "center"
    self.render.ox = 6
    self.render.oy = 0

    self.reflectProjectiles = true
    self.hitStunTimer = nil ---@type integer?

    self.aiBehavior.shootPlayer = false
    self.aiBehavior.chasePlayer = false

    self._forceChase = false
    self._lastKnownPx = -1
    self._lastKnownPy = -1
    self._hitPosX = -1
    self._hitPosY = -1
    self._hitDirX = 0
    self._hitDirY = 0
end

function MaidEnemy:update()
    if self.hitStunTimer and not self.dead then
        self.aiBehavior.enabled = false
        self.xVel = self.xVel * 0.9
        self.yVel = self.yVel * 0.9
        self.hitStunTimer = self.hitStunTimer - 1

        local hasSightLine = self:hasSightLineTo(self.world.player)
        if hasSightLine then
            self._lastKnownPx, self._lastKnownPy = self.world.player:getCenterPos()
        end

        if self.hitStunTimer <= 0 then
            self.hitStunTimer = nil
            self.sightTimer = 0
            self._forceChase = true
        end
    else
        self.aiBehavior.enabled = true
    end

    MaidEnemy.__super.update(self)

    if self.aiBehavior.enabled and self._forceChase then
        self._forceChase = false
        local hasSightLine = self:hasSightLineTo(self.world.player)
        if hasSightLine then
            print("sees player")
            self.sightTimer = self.noticeWait - 1
        elseif self._lastKnownPx ~= -1 then
            print("force chase")
            self.aiTask = coroutine.create(function()
                return self:_beginChase(self._lastKnownPx, self._lastKnownPy)
            end)
        else
            print("investigate source")
            self.ai = EnemyAi(self)
            self.ai:initMapAwareness()
            self.moveSpeed = self.ALERT_MOVE_SPEED
            self.aiTask = coroutine.create(function()
                return self:_killerSearch(
                    self._hitPosX, self._hitPosY,
                    self._hitPosX, self._hitPosY,
                    self._hitDirX, self._hitDirY)
            end)
        end
    end
end

function MaidEnemy:_switchToNormalCostume()
    self.render.oy = 8
    self.render.sprite = Resmgr.newSprite("/res/sprites/enemy1.json")
end

function MaidEnemy:_hit(hitVx, hitVy)
    if not self.reflectProjectiles then
        return MaidEnemy.__super._hit(self, hitVx, hitVy)
    end

    hitVx, hitVy = math.normalize(hitVx, hitVy)

    self._hitDirX, self._hitDirY = hitVx, hitVy
    self._hitPosX, self._hitPosY = self:getCenterPos()

    self.reflectProjectiles = false
    self.xVel = hitVx * 4.0
    self.yVel = hitVy * 4.0
    self.hitStunTimer = 40

    self.aiBehavior.shootPlayer = true
    self.aiBehavior.chasePlayer = true
    self:_switchToNormalCostume()

    local disguise = Util.newEntity("disguise_pickup", self:getCenterPos())
    if disguise then
        ---@cast disguise game.entities.DisguisePickup
        disguise:launch(-hitVx, -hitVy)
        self.world:addEntity(disguise)
    end
end

function MaidEnemy:loadPersistentData(data)
    MaidEnemy.__super.loadPersistentData(self, data)
    if self.dead then
        self:_switchToNormalCostume()
    end
end

return MaidEnemy
local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")

---@class game.entities.Projectile: game.entities.Entity
local Projectile = batteries.class {
    extends = require("game.entities.base")
}

function Projectile:new(x, y)
    self:super(centeredRect(x, y, 1, 1))
    self.collision = true
    self.touchMonitor = true
    self.colGroup = 0
    self.colMask = bit.bor(Const.COLGROUP_NPC)

    self.restitution = 1.0
    self.bouncesLeft = 4

    self.isAttached = false
    ---@type game.entities.Entity?
    self.entAttachedTo = nil

    self._touchEv = function(...) self._touched(...) end
    self._pickupEv = function(...) self._pickUp(...) end
    self.msg:subscribe("touched", self._touchEv)
end

function Projectile:_touched(oent, nx, ny)
    if oent then
        oent:publish("hit", self.xVel, self.yVel)
        self.entAttachedTo = oent
        self:_enterAttachedMode()
    else
        self.bouncesLeft = self.bouncesLeft - 1
        if self.bouncesLeft <= 0 then
            self:_enterAttachedMode()
            
            -- self:remove()
        end
    end
end

function Projectile:_pickUp(ent)
    if ent:hasTag("player") then
        ent.ammo = ent.ammo + 1
    end

    self:remove()
end

function Projectile:_enterAttachedMode()
    self.xVel = 0
    self.yVel = 0
    self.isAttached = true

    self.msg:unsubscribe("touched", self._touchEv)
    self.msg:subscribe("pickUp", self._pickupEv)
    self:addTag("playerPickup")
end

function Projectile:postUpdate()
    local ent = self.entAttachedTo
    if ent then
        self.x, self.y = ent:getCenterPos()
    end
end

function Projectile:render()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    Lg.setColor(0, 0, 0)
    Lg.circle("fill", cx, cy, 2)
end

return Projectile
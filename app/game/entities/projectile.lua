local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")

---@class game.entities.Projectile: game.Entity
local Projectile = batteries.class {
    extends = require("game.entity")
}

function Projectile:new(x, y)
    self:super(centeredRect(x, y, 0, 0))
    self.collision = true
    self.touchMonitor = true
    self.colGroup = 0
    self.colMask = bit.bor(Const.COLGROUP_DEFAULT, Const.COLGROUP_NPC)

    self.restitution = 1.0
    self.bouncesLeft = 4
    self.zOffset = 6
    self.alwaysDrawOverTilemap = false

    self.isAttached = false
    ---@type game.Entity?
    self.entAttachedTo = nil
    self.hasPickupFocus = false

    self.msg:subscribe("touched", self._touched)
    self.msg:subscribe("interactFocusChanged", self._pickupFocusChanged)
end

function Projectile:_pickupFocusChanged(v)
    self.hasPickupFocus = v
end

function Projectile:_touched(oent, nx, ny)
    if oent and oent:hasTag("enemy") then
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
    self.alwaysDrawOverTilemap = true

    self.msg:unsubscribe("touched", self._touched)
    self.msg:subscribe("interact", self._pickUp)
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

    if self.hasPickupFocus then
        Lg.setColor(1, 1, 0)
    else
        Lg.setColor(0, 0, 0)
    end
    
    Lg.circle("fill", cx, cy, 2)
end

return Projectile
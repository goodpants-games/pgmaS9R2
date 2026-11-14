local centeredRect   = require("game.util").centeredRect

local Const  = require "game.consts"
local Resmgr = require "game.resmgr"

---@class game.entities.Projectile: game.Entity
local Projectile = batteries.class {
    extends = require("game.entity")
}

function Projectile:new(x, y)
    self:super(centeredRect(x, y, 0, 0))
    self:addTag("strayPlayerBullet")
    
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

    self.sprite = Resmgr.newSprite("/res/sprites/knife.json")
    self.renderAngle = 0.0
    self.renderSx = 1.0

    self.msg:subscribe("touched", self._touched)
    self.msg:subscribe("interactFocusChanged", self._pickupFocusChanged)
end

function Projectile:_pickupFocusChanged(v)
    self.hasPickupFocus = v
end

function Projectile:_touched(oent, nx, ny)
    if oent and oent:hasTag("enemy") and not oent.reflectProjectiles then
        oent:publish("hit", self.xVel, self.yVel)
        self.entAttachedTo = oent
        self:_enterAttachedMode()
    else
        if not oent or oent.reflectProjectiles then
            if oent then
                oent:publish("hit", self.xVel, self.yVel)
                
                self.xVel = -self.xVel
                self.yVel = -self.yVel

                local ang = (love.math.random()*2-1) * math.rad(30)
                self.xVel, self.yVel = math.rotate(self.xVel, self.yVel, ang)
                self.bouncesLeft = 2
                -- local normX = self:getCenterX() - oent:getCenterX()
                -- local normY = self:getCenterY() - oent:getCenterY()
                -- normX, normY = math.normalize(normX, normY)
                -- print(normX, normY)

                -- local speed = math.length(self.xVel, self.yVel)
                -- self.xVel = normX * speed
                -- self.yVel = normY * speed

                -- v' = v - (1+R)(v ⋅ n)
                -- local dot = (self.xVel * normX + self.yVel * normY) * (self.restitution + 1.0)
                -- self.xVel = self.xVel - dot * normX
                -- self.yVel = self.yVel - dot * normY
            end
            
            self.bouncesLeft = self.bouncesLeft - 1
            if self.bouncesLeft <= 0 then
                self:_enterAttachedMode()
                
                -- self:remove()
            end
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
    if self.entAttachedTo then
        self.renderSx = math.sign2(self.xVel)
        self.sprite.cel = 2
        self.renderAngle = 0
    end
    
    self.xVel = 0.0
    self.yVel = 0.0
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

    if self.xVel ~= 0 or self.yVel ~= 0 then
        self.renderAngle = math.atan2(self.yVel, self.xVel)
    end
end

function Projectile:render()
    local cx, cy = self:getCenterPos()

    if self.hasPickupFocus then
        Lg.setColor(0, 0, 0)
    else
        Lg.setColor(1, 1, 1)
    end
    
    self.sprite:draw(cx, cy, self.renderAngle, self.renderSx, 1.0)
end

return Projectile
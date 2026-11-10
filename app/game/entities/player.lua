local Resmgr         = require("game.resmgr")
local SpriteRenderer = require("game.util").SpriteRenderer
local centeredRect   = require("game.util").centeredRect
local bool2int       = require("game.util").bool2int
local newEntity      = require("game.util").newEntity
local Const = require("game.consts")

local FIRE_CHARGE_MIN = 40
local ANGLE_SNAP = 0.00001

---@class game.entities.Player: game.entities.Entity
local Player = batteries.class {
    extends = require("game.entities.base")
}

function Player:new(x, y)
    self:super(centeredRect(x, y, 14, 14))
    self:addTag("player")
    
    self.collision = true
    self.colGroup = Const.COLGROUP_PLAYER
    self.render = SpriteRenderer(Resmgr.newSprite("/res/sprites/squid_player.json"))
    self.render.sprite.alignment = "topleft"
    self.render.ox = -1
    self.render.oy = -20

    self.cancelFire = false
    self.fireCharge = 0
    self.ammo = 1

    self.msg:subscribe("addedToWorld", self._addedToWorld)
    self.msg:subscribe("removingFromWorld", self._removingFromWorld)

    -- create gun sight
    self.gunSight = newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight:setColor(1, 1, 0)

    self._lastPickupTarget = nil
    self._fireDirX = 0.0
    self._fireDirY = 0.0
end

function Player:_addedToWorld()
    self.world.player = self
    self.world:addEntity(self.gunSight)
end

function Player:_removingFromWorld()
    if self.world.player == self then
        self.world.player = nil
    end

    self.gunSight:remove()
end

function Player:update()
    local world = softassert(self.world)
    if not world then return end

    if self.fireCharge == 0 then
        local inputX = bool2int(world:isInputDown("right"))
                       - bool2int(world:isInputDown("left"))
        local inputY = bool2int(world:isInputDown("down"))
                       - bool2int(world:isInputDown("up"))
        if inputX ~= 0 and inputY ~= 0 then
            inputX, inputY = math.normalize(inputX, inputY)
        end

        self.xVel = inputX * 2
        self.yVel = inputY * 2
    else
        self.xVel = 0
        self.yVel = 0
    end

    self:_weaponUpdate()
    self:_pickupUpdate()
end

function Player:_weaponUpdate()
    local world = assert(self.world)

    if self.ammo == 0 then
        return
    end

    local centerX = self.x + self.width/2
    local centerY = self.y + self.height/2

    if world:isInputReleased("fire") then
        self.cancelFire = false
    end

    if world:isInputDown("fire") and not self.cancelFire then
        if world:isInputPressed("pickUp") then
            self.fireCharge = 0
            self.gunSight.visible = false
            self.cancelFire = true
        else
            self.fireCharge = self.fireCharge + 1
            self.gunSight.visible = world.curFrame % 3 == 0

            -- update color of sight to indicate charge time
            local t = math.min(1.0, self.fireCharge / FIRE_CHARGE_MIN)
            local r, g, b
            if t < 1.0 then
                r, g, b = batteries.colour.hsv_to_rgb(0, 1.0, t)
            else
                r, g, b = 1, 1, 0
            end

            self.gunSight.r, self.gunSight.g, self.gunSight.b = r, g, b
        end
    else
        if self.fireCharge > FIRE_CHARGE_MIN then
            -- fire!!!!
            local proj = world:newEntity("projectile", self.x + self.width/2, self.y + self.height/2)
            if proj then
                proj.xVel = self._fireDirX * 10
                proj.yVel = self._fireDirY * 10
                world:addEntity(proj)
            end

            self.ammo = self.ammo - 1
        end

        self.fireCharge = 0
        self.gunSight.visible = false
    end
end

function Player:_pickupUpdate()
    local nearestPickup = nil
    local nearestPickupDist = 16

    local cx, cy = self:getCenterPos()
    for _, ent in ipairs(self.world:findEntitiesWithTag("playerPickup")) do
        local ecx, ecy = ent:getCenterPos()
        local dist = math.distance(cx, cy, ecx, ecy)
        if dist < nearestPickupDist then
            nearestPickup = ent
            nearestPickupDist = dist
        end
    end

    if nearestPickup then
        if self.world:isInputPressed("pickUp") then
            nearestPickup:publish("pickUp", self)
        end
    end

    if nearestPickup ~= self._lastPickupTarget then
        if self._lastPickupTarget then
            self._lastPickupTarget:publish("pickupFocusChanged", false)
        end
        if nearestPickup then
            nearestPickup:publish("pickupFocusChanged", true)
        end

        self._lastPickupTarget = nearestPickup
    end
end

function Player:postUpdate()
    local world = softassert(self.world)
    if not world then return end

    local centerX = self.x + self.width/2
    local centerY = self.y + self.height/2

    if self.fireCharge > 0 then
        -- update sights. this is in post-update so that the mouse position reading
        -- doesn't lag behind the camera update.
        local mouseX = world.camX + App.mouseX
        local mouseY = world.camY + App.mouseY
    
        local fireDx = mouseX - centerX
        local fireDy = mouseY - centerY
        if fireDx * fireDx + fireDy * fireDy == 0 then
            fireDx, fireDy = 1, 0
        end

        local fireAng = math.atan2(fireDy, fireDx)
        fireAng = math.round(fireAng / ANGLE_SNAP) * ANGLE_SNAP

        fireDx = math.cos(fireAng)
        fireDy = math.sin(fireAng)
        self._fireDirX, self._fireDirY = fireDx, fireDy

        self.gunSight:updateSight(centerX, centerY, fireDx, fireDy)
    end
end

return Player
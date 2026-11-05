local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local bool2int     = require("game.util").bool2int
local newEntity    = require("game.util").newEntity

local Const = require("game.consts")

local FIRE_CHARGE_MIN = 40

---@class game.entities.Player: game.entities.Entity
local Player = batteries.class {
    extends = require("game.entities.base")
}

function Player:new(x, y)
    self:super(centeredRect(x, y, 14, 14))
    self:addTag("player")
    
    self.collision = true
    self.colGroup = Const.COLGROUP_PLAYER
    self.render = RectRenderer(0.0, 1.0, 0.0)

    self.cancelFire = false
    self.fireCharge = 0
    self.ammo = 1

    self.msg:subscribe("addedToWorld", self._addedToWorld)
    self.msg:subscribe("removingFromWorld", self._removingFromWorld)

    -- create gun sight
    self.gunSight = newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight:setColor(1, 1, 0)

    self._lastPickupTarget = nil
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
            local mouseX = world.camX + App.mouseX
            local mouseY = world.camY + App.mouseY
        
            local fireDx = mouseX - centerX
            local fireDy = mouseY - centerY
            local fireDirLen = math.sqrt(fireDx * fireDx + fireDy * fireDy)
            if fireDirLen > 0 then
                fireDx = fireDx / fireDirLen
                fireDy = fireDy / fireDirLen
            end
        
            local proj = world:newEntity("projectile", self.x + self.width/2, self.y + self.height/2)
            if proj then
                proj.xVel = fireDx * 10
                proj.yVel = fireDy * 10
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
        local rayDx = world.mouseX - centerX
        local rayDy = world.mouseY - centerY
        local rayLen = math.length(rayDx, rayDy)

        if rayLen > 0 then
            self.gunSight:updateSight(
                centerX, centerY,
                rayDx / rayLen, rayDy / rayLen)
        end
    end
end

return Player
local Resmgr         = require("game.resmgr")
local SpriteRenderer = require("game.util").SpriteRenderer
local centeredRect   = require("game.util").centeredRect
local bool2int       = require("game.util").bool2int
local newEntity      = require("game.util").newEntity
local drawEntity     = require("game.util").drawEntity
local Input          = require("input")
local Const = require("game.consts")
local DirAnim = require("game.util.dir_anim")

local FIRE_CHARGE_MIN = 40
local ANGLE_SNAP = 0.00001

---@class game.entities.Player: game.Entity
local Player = batteries.class {
    extends = require("game.entity")
}

function Player:new(x, y)
    self:super(centeredRect(x, y, 13, 12))
    self:addTag("player")

    self.squidSprite = Resmgr.newSprite("/res/sprites/squid_player.json")
    self.squidSprite.alignment = "center"
    self.mutantSprite = Resmgr.newSprite("/res/sprites/mutant_player.json")
    self.mutantSprite.alignment = "center"
    self.animState = nil ---@type string?
    self.dirAnim = DirAnim()
    self.faceDir = 0.0

    self.collision = true
    self.touchMonitor = true
    self.colGroup = Const.COLGROUP_PLAYER
    self.colMask = bit.bor(Const.COLGROUP_DEFAULT, Const.COLGROUP_INTERACT_AREA)
    self.renderSprite = self.squidSprite
    self.renderOx = 6
    self.renderOy = 4

    self.cancelFire = false
    self.canInteract = true
    self.canFire = true
    self.fireCharge = 0
    self.ammo = 1
    self.dead = false
    self.moveSpeed = 1.5

    self.isDisguised = false
    self.disguiseEquipTimer = nil ---@type number?
    self.equippedItem = nil ---@type game.Entity?

    -- create gun sight
    self.gunSight = newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight:setColor(1, 1, 0)

    self._lastInteractable = nil  ---@type game.Entity?
    self._fireDirX = 0.0
    self._fireDirY = 0.0

    self.godMode = false
    self.chargeSound = nil ---@type game.Sound

    self.persistentData = true

    self.msg:subscribe("addedToWorld", self._addedToWorld)
    self.msg:subscribe("removingFromWorld", self._removingFromWorld)
    self.msg:subscribe("hit", self._hit)
end

function Player:_addedToWorld()
    self.world.player = self
    self.world:addEntity(self.gunSight)

    self.chargeSound = self.world.sndmgr:newSound("charge_aim")
    self.chargeSound.src:setVolume(0.4)
end

function Player:_removingFromWorld()
    if self.world.player == self then
        self.world.player = nil
    end

    self.gunSight:remove()
    self.chargeSound:release()
    self.chargeSound = nil
end

function Player:update()
    local world = softassert(self.world)
    if not world then return end

    local lastAnimState = self.animState
    self.animState = "idle"

    if self.dead then
        self.xVel = self.xVel * 0.9
        self.yVel = self.yVel * 0.9
        self.animState = "death"
        self:_animationUpdate(lastAnimState)
        return
    end

    self.canInteract = true
    self.canFire = not self.isDisguised
    local canMove = self.fireCharge == 0
    if self.disguiseEquipTimer then
        self.canFire = false
        self.canInteract = false
        canMove = false

        self.disguiseEquipTimer = self.disguiseEquipTimer - 1
        if self.disguiseEquipTimer <= 0 then
            self.isDisguised = true
            self.renderSprite = self.mutantSprite
            self.disguiseEquipTimer = nil
        elseif self.world:isInputPressed("interact") then
            self.disguiseEquipTimer = nil
            self:_removeDisguise()
        end
    end

    if canMove then
        local inputX, inputY = Input.players[1]:get("move")
        if inputX ~= 0 or inputY ~= 0 then
            inputX, inputY = math.normalize(inputX, inputY)
            self.animState = "walk"
            self.faceDir = math.atan2(inputY, inputX)
        end

        self.xVel = inputX * self.moveSpeed
        self.yVel = inputY * self.moveSpeed
    else
        self.xVel = 0
        self.yVel = 0
    end

    self:_weaponUpdate()
    self:_interactUpdate()
    self:_animationUpdate(lastAnimState)

    if self.chargeSound then
        if self.fireCharge > 0 then
            local t = math.clamp01(self.fireCharge / FIRE_CHARGE_MIN)
            self.chargeSound.src:setPitch(math.lerp(0.5, 1.0, t))
            if not self.chargeSound.src:isPlaying() then
                self.chargeSound.src:play()
            end
        else
            self.chargeSound.src:stop()
        end
    end
end

---@return number?
function Player:_getAimDirection()
    local world = self.world

    -- update sights. this is in post-update so that the mouse position reading
    -- doesn't lag behind the camera update.
    local fireDx, fireDy ---@type number, number
    local fireAng ---@type number
    local device = Input.players[1]

    if Input.isJoystick(1) then
        local joystick = device.config.joystick
        fireDx = joystick:getGamepadAxis("rightx")
        fireDy = joystick:getGamepadAxis("righty")

        local deadzone = device.config.deadzone
        if math.length(fireDx, fireDy) < deadzone then
            fireDx = 0.0
            fireDy = 0.0
        end
    else
        local mouseX = world.camX + App.mouseX
        local mouseY = world.camY + App.mouseY
        fireDx = mouseX - (world.camX + App.scrW / 2)
        fireDy = mouseY - (world.camY + App.scrH / 2)
    end

    if fireDx * fireDx + fireDy * fireDy == 0 then
        return nil
    end

    fireAng = math.atan2(fireDy, fireDx)
    fireAng = math.round(fireAng / ANGLE_SNAP) * ANGLE_SNAP
    return fireAng
end

function Player:postUpdate()
    local world = softassert(self.world)
    if not world then return end

    if self.dead then return end

    local centerX, centerY = self:getCenterPos()

    if self.fireCharge > 0 then
        -- update sights. this is in post-update so that the mouse position reading
        -- doesn't lag behind the camera update.
        local fireAng = self:_getAimDirection() or 0.0
        fireAng = math.round(fireAng / ANGLE_SNAP) * ANGLE_SNAP

        local fireDx = math.cos(fireAng)
        local fireDy = math.sin(fireAng)

        self._fireDirX, self._fireDirY = fireDx, fireDy
        self.faceDir = fireAng
        self.gunSight:updateSight(centerX, centerY, fireDx, fireDy)
    end

    if self.equippedItem then
        self.equippedItem.x = self.x + 2
        self.equippedItem.y = self.y - 6
    end
end

function Player:render()
    Lg.push()
    Lg.setColor(1, 1, 1)

    Lg.translate(self.renderOx, self.renderOy)
    self.renderSprite:draw(math.round(self.x), math.round(self.y))

    if self.equippedItem then
        drawEntity(self.equippedItem, self.alwaysDrawOverTilemap)
    end

    Lg.pop()

    if Debug.enabled then
        Lg.rectangle("line", math.round(self.x), math.round(self.y),
                     math.round(self.width), math.round(self.height))
    end
end

function Player:equipDisguise()
    if self.isDisguised or self.equippedItem then return false end

    self.disguiseEquipTimer = 120

    return true
end

---@param item game.Entity
---@return boolean
function Player:pickUpItem(item)
    if self.equippedItem then
        return false
    end

    item:remove()
    self.equippedItem = item

    return true
end

function Player:_weaponUpdate()
    local world = assert(self.world)

    if self.ammo == 0 or not self.canFire then
        if self.fireCharge > 0 and world:isInputDown("fire") then
            self.cancelFire = true
        end
        self.fireCharge = 0
        self.gunSight.visible = false
        return
    end

    local isKeyboard = Input.players[1]:getActiveDevice() == "kbm"
    local isAiming = false
    local wantsCancel = false
    if isKeyboard then
        isAiming = world:isInputDown("fire")
        wantsCancel = world:isInputPressed("interact")
    else
        local aimDir = self:_getAimDirection()
        isAiming = (not not aimDir) and world:isInputDown("fire")
        if (not aimDir) and self.fireCharge > 0 then
            wantsCancel = not aimDir
            isAiming = true
        end
    end

    if world:isInputReleased("fire") or not isKeyboard then
        self.cancelFire = false
    end

    if not self.cancelFire and isAiming then
        self.canInteract = false

        if wantsCancel then
            self.fireCharge = 0
            self.gunSight.visible = false
            self.cancelFire = true
        else
            self.animState = "aim"
            self.fireCharge = self.fireCharge + 1
            self.gunSight.visible = true
            if world.curFrame % 6 < 3 then
                self.gunSight.a = 0.0
            else
                self.gunSight.a = 0.8
            end
            -- self.gunSight.visible = world.curFrame % 3 == 0

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
            self.world.sndmgr:play("knife_throw")
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

    self._lastAimDir = aimDir
end

function Player:_interactUpdate()
    local nearestInteract = nil
    local nearestInteractDist = 100

    if self.canInteract then
        local cx, cy = self:getCenterPos()

        for _, ent in ipairs(self:getOverlappingEntities()) do
            if ent:hasTag("interactable") then
                local ecx, ecy = ent:getCenterPos()
                local dist = math.distance(cx, cy, ecx, ecy)
                if dist < nearestInteractDist then
                    nearestInteract = ent
                    nearestInteractDist = dist
                end
            end
        end

        for _, ent in ipairs(self.world:findEntitiesWithTag("playerPickup")) do
            local ecx, ecy = ent:getCenterPos()
            local dist = math.distance(cx, cy, ecx, ecy)
            if dist < 16 and dist < nearestInteractDist then
                nearestInteract = ent
                nearestInteractDist = dist
            end
        end
    end

    if nearestInteract ~= self._lastInteractable then
        if self._lastInteractable then
            self._lastInteractable:publish("interactFocusChanged", false)
        end
        if nearestInteract then
            nearestInteract:publish("interactFocusChanged", true)
        end

        self._lastInteractable = nearestInteract
    end

    if self.canInteract and self.world:isInputPressed("interact") then
        if nearestInteract then
            nearestInteract:publish("interact", self)
        else
            self:_emptyInteract()
        end
    end
end

---@param lastAnimState string?
function Player:_animationUpdate(lastAnimState)
    local spr = self.renderSprite
    if not spr then return end

    if self.animState == "death" or self.animState == "aim" then
        self.dirAnim:setOctoDir(spr, self.animState, self.faceDir)
    else
        self.dirAnim:setDirection(spr, self.faceDir)
        if self.animState ~= lastAnimState then
            self.dirAnim:play(spr, self.animState)
        end
    end

    spr:update(App.tickLength)
end

function Player:_emptyInteract()
    if self.equippedItem then
        self:dropItem()
    elseif self.isDisguised then
        self:_removeDisguise()
    end
end

function Player:_removeDisguise()
    self.isDisguised = false
    self.renderSprite = self.squidSprite

    local ent = self.world:newEntity("disguise_pickup", self:getCenterPos())
    if ent then
        self.world:addEntity(ent)
    end

    return ent
end

function Player:dropItem()
    if self.equippedItem then
        local w, h = self.equippedItem.width, self.equippedItem.height
        self.equippedItem.x = math.round(self:getCenterX() - w / 2)
        self.equippedItem.y = math.round(self:getCenterY() - h / 2)
        self.world:addEntity(self.equippedItem)
        self.equippedItem = nil
    end
end

function Player:prepareForCheckpoint(checkpoint)
    self:dropItem()

    local strayBullets = self.world:findEntitiesWithTag("strayPlayerBullet")
    for _, bullet in ipairs(strayBullets) do
        self.ammo = self.ammo + 1
        bullet:remove()
    end

    local disguise = self.world:findEntitiesWithTag("disguisePickup")[1]
    if disguise then
        disguise.x = checkpoint:getCenterX() - disguise.width / 2
        disguise.y = checkpoint:getCenterY() - disguise.height / 2
    end
end

---@param hitVx number
---@param hitVy number
function Player:_hit(hitVx, hitVy)
    hitVx, hitVy = math.normalize(hitVx, hitVy)
    if self.godMode then return end

    -- local snd = self.world.sndmgr:play("player_collapse")
    -- snd.src:setVolume(0.4)

    -- Die . Now.
    self.dead = true
    self.msg:unsubscribe("hit", self._hit)

    -- self.faceDir = math.atan2(hitVy, hitVx)
    self.xVel = hitVx * 3
    self.yVel = hitVy * 3
    self.faceDir = math.atan2(hitVy, hitVx)
    self.zIndex = -10

    self.gunSight:remove()

    -- drop equipped item and disguise
    if self.equippedItem or self.isDisguised then
        local itemDropX = -hitVx
        local itemDropY = -hitVy

        -- if dropping both item and disguise, then their launch angle will be
        -- somewhat separated...
        if self.isDisguised then
            local pickup = self:_removeDisguise()
            local disguiseDropX = itemDropX
            local disguiseDropY = itemDropY

            if self.equippedItem then
                local separation = math.rad(20)
                disguiseDropX, disguiseDropY =
                    math.rotate(disguiseDropX, disguiseDropY, separation)
                itemDropX, itemDropY =
                    math.rotate(itemDropX, itemDropY, -separation)
            end
            
            pickup:launch(disguiseDropX, disguiseDropY)
        end

        if self.equippedItem then
            local w, h = self.equippedItem.width, self.equippedItem.height
            self.equippedItem.x = math.round(self:getCenterX() - w / 2)
            self.equippedItem.y = math.round(self:getCenterY() - h / 2)
            self.world:addEntity(self.equippedItem)
            self.equippedItem:launch(itemDropX, itemDropY)
            self.equippedItem = nil
        end
    end

    self:publish("died")
end

function Player:savePersistentData(data)
    Player.__super.savePersistentData(self, data)

    data.x, data.y = self.x, self.y
    data.ammo = self.ammo
    data.isDisguised = self.isDisguised
end

function Player:loadPersistentData(data)
    Player.__super.loadPersistentData(self, data)
    self.x, self.y = data.x, data.y
    self.ammo = data.ammo
    
    if data.isDisguised then
        self.disguiseEquipTimer = 0 -- bruh
    end
end

return Player
local Const = require("game.consts")
local Resmgr = require("game.resmgr")

---@class game.Camera: batteries.Class
---@overload fun(world:game.World):game.Camera
local Camera = batteries.class()

---@class game.Camera.SightAlert: batteries.Class
---@overload fun():game.Camera.SightAlert
---@field pooled fun(self:any, ...):game.Camera.SightAlert
---@field release fun(self:game.Camera.SightAlert)
local SightAlert = batteries.class()
batteries.make_pooled(SightAlert, 16)

---@param world game.World
function Camera:new(world)
    self.world = world
    self.x = world.player:getCenterX()
    self.y = world.player:getCenterY()

    self.offsetX = 0.0
    self.offsetY = 0.0

    self.sightAlerts = {} ---@type game.Camera.SightAlert[]
    self.ammoCount = 0

    self.uiIcons = Resmgr.newSprite("/res/game_ui_icons.json")
end

function Camera:update()
    local world = self.world
    local player = world.player --[[@as game.entities.Player]]
    local playerCx, playerCy = player:getCenterPos()

    self.ammoCount = 0

    if not player.dead then
        self.ammoCount = player.ammo

        for _, ent in ipairs(world:findEntitiesWithTag("enemy")) do
            local entCx, entCy = ent:getCenterPos()

            local dx = entCx - playerCx
            local dy = entCy - playerCy
            local raycastHit = world:raycast(playerCx, playerCy, dx, dy, Const.COLGROUP_DEFAULT)
            if not raycastHit then
                local alert = self:_getSightAlertForEntity(ent)
                if not alert then
                    alert = SightAlert.pooled()
                    table.insert(self.sightAlerts, alert)
                end

                alert.dirX, alert.dirY = math.normalize(dx, dy)
                alert.ent = ent
                alert.life = 0
            end
        end
    end

    -- update alerts things
    for _, obj in ipairs(self.sightAlerts) do
        obj:update()
    end
    for i=#self.sightAlerts, 1, -1 do
        local obj = self.sightAlerts[i]
        if not obj:isAlive() then
            table.remove(self.sightAlerts, i)
            obj:release()
        end
    end

    self:_updateCamera()
end

---@param ent game.Entity
function Camera:_getSightAlertForEntity(ent)
    for _, obj in ipairs(self.sightAlerts) do
        if obj.ent == ent then
            return obj
        end
    end

    return nil
end

function Camera:_updateCamera()
    local world = self.world
    local player = world.player --[[@as game.entities.Player]]

    local playerCx = math.round(player.x) + player.width / 2
    local playerCy = math.round(player.y) + player.height / 2

    local targetOx = 0.0
    local targetOy = 0.0
    local approachSpeed = 0.1

    local gunSight = player.gunSight ---@type game.entities.GunSight?
    if gunSight and not gunSight.world then
        gunSight = nil
    end

    if player.fireCharge > 0 and gunSight and self.world:isInputDown("camSwitch") then
        local gunSight = player.gunSight
        local posAccumX = 0.0
        local posAccumY = 0.0
        local posAccumDivider = 1

        for i=1, #gunSight.lines, 2 do
            local x, y = gunSight.lines[i], gunSight.lines[i+1]

            posAccumX = posAccumX + (x - playerCx)
            posAccumY = posAccumY + (y - playerCy)
            posAccumDivider = posAccumDivider + 1
        end

        local focusX = posAccumX / posAccumDivider
        local focusY = posAccumY / posAccumDivider

        targetOx = focusX
        targetOy = focusY
        approachSpeed = 0.05
    else
        local mouseOfsX = math.round(App.mouseX) - (App.scrW / 2)
        local mouseOfsY = math.round(App.mouseY) - (App.scrH / 2)

        targetOx = mouseOfsX / 4
        targetOy = mouseOfsY / 4
    end

    self.offsetX = self.offsetX + (targetOx - self.offsetX) * approachSpeed
    self.offsetY = self.offsetY + (targetOy - self.offsetY) * approachSpeed
    self.x = playerCx + self.offsetX
    self.y = playerCy + self.offsetY
end

function Camera:drawUI()
    -- draw alert signs
    self.uiIcons:play("alert")
    for _, obj in ipairs(self.sightAlerts) do
        obj:draw(self.uiIcons)
    end

    -- draw knife counter
    self.uiIcons:play("knife")
    Lg.setColor(1, 1, 1)
    for i=1, self.ammoCount do
        local x = (i-1) * 10 + 8
        local y = App.scrH - 8

        self.uiIcons:draw(x, y)
    end

    -- draw mouse cursor
    Lg.setColor(1, 1, 1)
    Lg.setLineWidth(1.0)
    Lg.rectangle("line", App.mouseX - 4, App.mouseY - 4, 8, 8)
end

--------------------------------------------------------------------------------

local SIGHT_ALERT_LIFE = 40
local SIGHT_ALERT_SCREEN_OFS = 24

function SightAlert:new()
    self.dirX = 0.0
    self.dirY = 0.0
    self.life = 0
    self.ent = nil ---@type game.Entity
end

function SightAlert:isAlive()
    return self.life < SIGHT_ALERT_LIFE and not self.ent.dead
end

function SightAlert:update()
    self.life = self.life + 1
end

---@param spr pklove.Sprite
function SightAlert:draw(spr)
    local alpha = 1.0 - math.clamp01(self.life / SIGHT_ALERT_LIFE)
    Lg.setColor(alpha, alpha, alpha, alpha)

    local scx = App.scrW / 2
    local scy = App.scrH / 2
    local drawX = scx + self.dirX * SIGHT_ALERT_SCREEN_OFS
    local drawY = scy + self.dirY * SIGHT_ALERT_SCREEN_OFS

    spr:draw(drawX, drawY)
end

--------------------------------------------------------------------------------

return Camera
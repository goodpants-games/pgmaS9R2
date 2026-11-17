local Resmgr = require("game.resmgr")
local Util = require("game.util")

---@class game.entities.Tutorial: game.Entity
local Tutorial = batteries.class {
    extends = require("game.entity")
}

---@param x number
---@param y number
function Tutorial:new(x, y)
    self:super(x, y, 0, 0)
    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/tutorials.json"))

    self.alwaysDrawOverTilemap = true
    self.zIndex = 1000

    self._updateFunc = nil
end

function Tutorial:loadProperties(id, props, entLookup)
    local animName = Util.propCheck(props, "id", "string", id, self.typeName)
    if not animName then return end

    self.render.sprite:play(animName)

    if animName == "pick_up_disguise" then
        local targetId = Util.propCheck(props, "target", "object", id, self.typeName)
        if not targetId then return end

        local target = entLookup(targetId)
        if not target then
            warn(("object %i 'tutorial': could not dereference target id"):format(id))
            return
        end

        self.visible = false
        target.msg:subscribe_once("died", function()
            self.visible = true
            self._updateFunc = function()
                if self.world.player.isDisguised then
                    self._updateFunc = nil
                    self:remove()
                end
            end
        end)
    
    elseif animName == "remove_disguise" then
        local lastDisguised = false
        self._updateFunc = function()
            local player = assert(self.world.player)
            if not player.isDisguised and lastDisguised then
                if player:getCenterX()/16 > 23 then
                    self:remove()
                    self._updateFunc = nil
                end
            end
            lastDisguised = player.isDisguised
        end
    
    elseif animName == "aim" then
        self.msg:subscribe_once("addedToWorld", function()
            local plr = assert(self.world.player)
            local lastAmmoCount = plr.ammo
            self._updateFunc = function()
                if plr.ammo ~= lastAmmoCount then
                    lastAmmoCount = plr.ammo
    
                    if plr.ammo == 0 then
                        self.render.sprite:play("knife_grab")
                    else
                        self.render.sprite:play("aim")
                    end
                end
            end
        end)
    end
end

function Tutorial:update()
    if self._updateFunc then
        self._updateFunc()
    end
    self.render.sprite:update(App.tickLength)
end

return Tutorial
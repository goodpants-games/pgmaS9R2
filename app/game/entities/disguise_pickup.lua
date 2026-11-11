local Util = require("game.util")
local Const = require("game.consts")
local Resmgr = require("game.resmgr")

---@class game.entities.DisguisePickup: game.entities.Entity
local DisguisePickup = batteries.class {
    extends = require("game.entities.base")
}

function DisguisePickup:new(x, y)
    self:super(Util.centeredRect(x, y, 12, 12))
    self:addTag("interactable")
    self:addTag("disguisePickup")
    
    self.collision = true
    self.colGroup = Const.COLGROUP_INTERACT_AREA
    self.colMask = Const.COLGROUP_PLAYER

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/disguise_pickup.json"))
    self.render.ox = 5
    self.render.oy = 5
    self.zIndex = -20

    self.msg:subscribe("interact", self._interact)
end

function DisguisePickup:_interact(plr)
    if plr:equipDisguise() then
        self:remove()
    end
end

return DisguisePickup
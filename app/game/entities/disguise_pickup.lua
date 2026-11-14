local Util = require("game.util")
local Resmgr = require("game.resmgr")

---@class game.entities.DisguisePickup: game.entities.BasePickup
local DisguisePickup = batteries.class {
    extends = require("game.entities.base_pickup")
}

function DisguisePickup:new(x, y)
    self:super(Util.centeredRect(x, y, 12, 12))
    self:addTag("disguisePickup")

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/disguise_pickup.json"))
    self.render.ox = 5
    self.render.oy = 5
    self.zIndex = -20
end

function DisguisePickup:_interact(plr)
    if plr:equipDisguise() then
        self:remove()
    end
end

return DisguisePickup
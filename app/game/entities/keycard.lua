local Util = require("game.util")
local Const = require("game.consts")
local Resmgr = require("game.resmgr")

---@class game.entities.Keycard: game.entities.BasePickup
local Keycard = batteries.class {
    extends = require("game.entities.base_pickup")
}

function Keycard:new(x, y)
    self:super(Util.centeredRect(x, y, 12, 12))
    self:addTag("keycard")

    self.auth = 0

    self.restitution = 0.5

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/keycard.json"))
    self.render.ox = 5
    self.render.oy = 5
    self.zIndex = -20
end

function Keycard:update()
    self.render.sprite.cel = self.auth + 2
    Keycard.__super.update(self)
end

return Keycard
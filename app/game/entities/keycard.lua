local Util = require("game.util")
local Const = require("game.consts")
local Resmgr = require("game.resmgr")

---@class game.entities.Keycard: game.entities.Entity
local Keycard = batteries.class {
    extends = require("game.entities.base")
}

function Keycard:new(x, y)
    self:super(Util.centeredRect(x, y, 12, 12))
    self:addTag("interactable")

    self.auth = 0

    self.zVel = 0.0
    self.zGrav = -0.3
    
    self.collision = true
    self.restitution = 0.5 
    self.colGroup = Const.COLGROUP_INTERACT_AREA
    self.colMask = bit.bor(Const.COLGROUP_DEFAULT, Const.COLGROUP_PLAYER)

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/keycard.json"))
    self.render.ox = 5
    self.render.oy = 5
    self.zIndex = -20

    self.msg:subscribe("interact", self._interact)
end

function Keycard:update()
    self.xVel = self.xVel * 0.9
    self.yVel = self.yVel * 0.9

    self.zVel = self.zVel + self.zGrav
    self.zOffset = self.zOffset + self.zVel
    if self.zOffset < 0 then
        self.zOffset = 0
        self.zVel = self.zVel * -0.4
    end
end

---@param plr game.entities.Player
function Keycard:_interact(plr)
    if not softassert(plr:hasTag("player")) then
        return
    end
    
    print("player picked up keycard")
    plr:pickUpItem(self)
end

return Keycard
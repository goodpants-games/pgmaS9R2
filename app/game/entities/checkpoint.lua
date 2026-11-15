local Util = require("game.util")
local Const = require("game.consts")
local Resmgr = require("game.resmgr")

---@class game.entities.Checkpoint: game.Entity
local Checkpoint = batteries.class {
    extends = require("game.entity")
}

function Checkpoint:new(x, y)
    self:super(Util.centeredRect(x, y, 16, 16))
    self:addTag("interactable")

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/checkpoint_pad.json"))
    self.render.ox = 8
    self.render.oy = 8
    self.zIndex = -100

    self.collision = true
    self.colGroup = Const.COLGROUP_INTERACT_AREA

    self.msg:subscribe("interact", self._interact)
end

---@param txt string
function Checkpoint:_popupText(txt)
    local x = self:getCenterX()
    local y = self:getCenterY() - 32
    local ent = Util.newEntity("text_popup", x, y, txt)
    if not ent then return end

    self.world:addEntity(ent)
end

function Checkpoint:_interact(ent)
    if ent.equippedItem then return end
    
    self:_popupText("Checkpoint saved!")
    self.world:saveCheckpoint()
end

return Checkpoint
local Util = require("game.util")
local Const = require("game.consts")

---@class game.entities.Checkpoint: game.Entity
local Checkpoint = batteries.class {
    extends = require("game.entity")
}

function Checkpoint:new(x, y)
    self:super(Util.centeredRect(x, y, 16, 16))
    self:addTag("interactable")

    self.render = Util.RectRenderer(0.2, 1.0, 0.2)
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

function Checkpoint:_interact()
    self:_popupText("Checkpoint saved!")
    self.world:saveCheckpoint()
end

return Checkpoint
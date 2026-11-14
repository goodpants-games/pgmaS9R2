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

function Checkpoint:_interact()
    print("checkpoint interacted")
    self.world:saveCheckpoint()
end

return Checkpoint
local Util = require("game.util")
local Const = require("game.consts")
local Resmgr = require("game.resmgr")

---@class game.entities.Checkpoint: game.Entity
local Checkpoint = batteries.class {
    extends = require("game.entity")
}

function Checkpoint:new(x, y)
    self:super(Util.centeredRect(x, y, 16, 16))

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/checkpoint_pad.json"))
    self.render.ox = 8
    self.render.oy = 8
    self.zIndex = -100

    self.collision = true
    self.touchMonitor = true
    self.monitorOnly = true
    self.colGroup = 0
    self.colMask = Const.COLGROUP_PLAYER

    self.msg:subscribe("touched", self._touched)
end

---@param txt string
function Checkpoint:_popupText(txt)
    local x = self:getCenterX()
    local y = self:getCenterY() - 32
    local ent = Util.newEntity("text_popup", x, y, txt)
    if not ent then return end

    self.world:addEntity(ent)
end

---@param plr game.Entity
function Checkpoint:_touched(plr)
    if not plr:hasTag("player") then
        return 
    end
    ---@cast plr game.entities.Player
    
    if self.world:getCheckpointId() == self.tiledId then
        return
    end
    
    plr:prepareForCheckpoint(self)
    self:_popupText("Checkpoint saved!")
    self.world:saveCheckpoint(self)
end

function Checkpoint:update()
    if not self.tiledId then return end

    if self.tiledId == self.world:getCheckpointId() then
        self.render.sprite.cel = 3
    else
        self.render.sprite.cel = 1
    end
end

return Checkpoint
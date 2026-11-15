local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")

---@class game.entities.ElevatorButton: game.Entity
local ElevatorButton = batteries.class {
    extends = require("game.entity")
}

function ElevatorButton:new(x, y)
    self:super(x - 7, y, 15, 16)
    self:addTag("interactable")

    self.collision = true
    self.monitorOnly = true
    self.colGroup = Const.COLGROUP_INTERACT_AREA
    self.colMask = 0

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/elevator_button.json"))
    self.render.sprite.alignment = "topleft"
    self.render.ox = -1
    self.render.oy = -7

    ---@type game.entities.ElevatorDoor?
    self.target = nil
    self.clearLevelOnUse = false

    self.hasFocus = false

    self.msg:subscribe("interactFocusChanged", self._interactFocusChanged)
    self.msg:subscribe("interact", self._interact)
end

function ElevatorButton:loadProperties(id, props, entLookup)
    local target = Util.propCheck(props, "target", "object", id, "keycard_reader")
    if target == nil then return end

    local obj = entLookup(target)
    if obj then
        self.target = obj --[[@as any]]
    else
        warn(("{object id %i 'keycard_reader'}: ent lookup failed"):format(id))
    end

    local clearLevel = Util.propCheck(props, "clear_level", "boolean", id, self.typeName)
    if clearLevel == nil then return end
    self.clearLevelOnUse = clearLevel
end

---@param status boolean
function ElevatorButton:_interactFocusChanged(status)
    self.hasFocus = status
end

---@param plr game.entities.Player
function ElevatorButton:_interact(plr)
    if self.target then
        self.target:activate()
    end

    if self.clearLevelOnUse then
        Sceneman.currentScene.transitionToNextLevel()
    end
end

function ElevatorButton:update()
    self.render.sprite.cel = self.hasFocus and 2 or 1
end

return ElevatorButton
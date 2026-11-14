local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")

local HITBOX_Y_OFS = 8

---@class game.entities.LevelPortal: game.Entity
local LevelPortal = batteries.class {
    extends = require("game.entity")
}

function LevelPortal:new(x, y)
    self:super(x - 8, y - 8 + HITBOX_Y_OFS, 48, 16)
    self.collision = false
    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/elevator.json"))
    self.render.sprite.alignment = "topleft"
    self.render.oy = -16 - HITBOX_Y_OFS
    self.zIndex = -5000

    self.mode = "end" ---@type "start"|"end"
end

function LevelPortal:loadProperties(id, props)
    local mode = Util.propCheck(props, "mode", "string", id, self.typeName)
    if not mode then return end

    if not (mode == "start" or mode == "end") then
        warn(("obj %i: invalid mode '%s'"):format(id, mode))
        return
    end

    self.mode = mode

    if self.mode == "end" then
        self.collision = true
        self.colGroup = Const.COLGROUP_INTERACT_AREA
        self:addTag("interactable")
        self.msg:subscribe("interact", self._interact)
    end
end

function LevelPortal:_interact()
    Sceneman.currentScene.transitionToNextLevel()
end

return LevelPortal
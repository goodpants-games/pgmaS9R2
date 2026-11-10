local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.entities.Computer: game.entities.Entity
local Computer = batteries.class {
    extends = require("game.entities.base")
}

function Computer:new(x, y)
    self:super(x - 7, y, 15, 16)
    self.collision = true
    self.touchMonitor = true
    self.colGroup = 0
    self.colMask = Const.COLGROUP_PLAYER

    self.tileX = math.floor((x - 8) / TILE_SIZE)
    self.tileY = math.floor((y - 8) / TILE_SIZE)

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/computer.json"))
    self.render.sprite.alignment = "topleft"

    self.render.oy = -24

    ---@type game.entities.Door?
    self.target = nil

    self.hasFocus = false

    self.msg:subscribe("addedToWorld", self._added)
    self.msg:subscribe("touched", self._touched)
    self.msg:subscribe("touchEnded", self._touchEnded)
end

function Computer:loadProperties(id, props, entLookup)
    local target = Util.propCheck(props, "target", "object", id, "computer")
    if target == nil then return end

    self.target = softassert( entLookup(target.id) ) --[[@as any]]
end

function Computer:_added()
    self.world:setCol(self.tileX, self.tileY, 1)
end

---@param toucher game.entities.Entity
function Computer:_touched(toucher)
    print("computer Touche")

    if not toucher:hasTag("player") then
        return
    end

    self.hasFocus = true
end

---@param toucher game.entities.Entity
function Computer:_touchEnded(toucher)
    print("computer touch ene")
    if not toucher:hasTag("player") then
        return
    end

    self.hasFocus = false
end

function Computer:update()
    if self.hasFocus and self.world:isInputPressed("pickUp") then
        if self.target then
            self.target:activate()
        end
    end
end

return Computer
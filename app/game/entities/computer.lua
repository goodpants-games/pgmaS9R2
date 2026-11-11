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

    ---@type game.entities.Door[]
    self.targets = {}

    self.hasFocus = false

    self.msg:subscribe("addedToWorld", self._added)
    self.msg:subscribe("touched", self._touched)
    self.msg:subscribe("touchEnded", self._touchEnded)
end

function Computer:loadProperties(id, props, entLookup)
    if props.target then
        local target = Util.propCheck(props, "target", "object", id, "computer")
        if target == nil then return end

        self.targets[1] = softassert( entLookup(target) ) --[[@as any]]
    end

    if props.targets then
        local targets = Util.propCheck(props, "targets", "list[object]", id, "computer")
        if targets == nil then return end

        for _, target in ipairs(targets) do
            table.insert(self.targets, softassert(entLookup(target)))
        end
    end

    print(("read %i targets"):format(#self.targets))
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
        for _, target in ipairs(self.targets) do
            target:activate()
        end
    end
end

return Computer
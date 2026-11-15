local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.entities.ElevatorDoor: game.Entity
local ElevatorDoor = batteries.class {
    extends = require("game.entity")
}

function ElevatorDoor:new(x, y)
    self:super(x - 8, y - 8, 0, 0)
    self.collision = false
    self.monitorOnly = true
    self.colGroup = 0
    self.colMask = bit.bor(Const.COLGROUP_NPC, Const.COLGROUP_PLAYER)
    self.touchMonitor = false

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/elevator_door.json"))
    self.render.sprite.alignment = "topleft"
    self.closed = true
    self.closeTimer = 60
    self.autoOpenTimer = nil ---@type integer?

    self.render.oy = -32
    self.width = 32
    self.height = 16
    self:_setAnim(true)
    self.render.sprite:stop()

    self.msg:subscribe("addedToWorld", self._added)
    self.persistentData = true
end

function ElevatorDoor:loadProperties(id, props)
    local autoOpen = Util.propCheck(props, "auto_open", "boolean", id, self.typeName)
    if autoOpen == nil then return end

    if autoOpen then
        self.autoOpenTimer = 30
    end
end

function ElevatorDoor:_setCollision(colId)
    local tx = math.floor(self.x / TILE_SIZE)
    local ty = math.floor(self.y / TILE_SIZE)

    self.world:setCol(tx, ty, colId)
    self.world:setCol(tx + 1, ty, colId)
end

function ElevatorDoor:_added()
    self:_setCollision(self.closed and 1 or 0)
end

---@param invert boolean?
function ElevatorDoor:_setAnim(invert)
    local animName = (self.closed ~= not not invert) and "close" or "open"
    self.render.sprite:play(animName)
end

function ElevatorDoor:activate()    
    self.closed = not self.closed
    if self.closed then
        self:_setCollision(1)
        self.closeTimer = 0
    else
        self:_setCollision(0)
        self.closeTimer = 240
        self.autoOpenTimer = nil
    end

    self:_setAnim()
end

function ElevatorDoor:update()
    -- handle auto-open timer
    if self.autoOpenTimer then
        self.autoOpenTimer = self.autoOpenTimer - 1
        if self.autoOpenTimer <= 0 then
            self.autoOpenTimer = nil

            if self.closed then
                self:activate()
            end
        end
    end

    -- handle close timer
    if self.closeTimer ~= 0 then
        self.closeTimer = self.closeTimer - 1
        if self.closeTimer == 0 then
            if not self.closed then
                self:activate()
            end
        end
    end

    self.render.sprite:update(App.tickLength)
end

function ElevatorDoor:loadPersistentData(data)
    self.autoOpenTimer = nil
end

return ElevatorDoor
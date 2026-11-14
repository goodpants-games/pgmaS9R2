local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.entities.Door: game.Entity
local Door = batteries.class {
    extends = require("game.entity")
}

function Door:new(x, y)
    self:super(x - 8, y - 8, 0, 0)
    self.collision = false
    self.monitorOnly = true
    self.colGroup = 0
    self.colMask = bit.bor(Const.COLGROUP_NPC, Const.COLGROUP_PLAYER)
    self.touchMonitor = false

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/door.json"))
    self.render.sprite.alignment = "topleft"
    self.closed = true
    self.closeAfterEntry = false

    ---@type string?
    self.direction = nil
    -- self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/enemy1.json"))
    -- self.render.sprite.alignment = "topleft"

    self.msg:subscribe("addedToWorld", self._added)

    self.persistentData = true
end

function Door:loadProperties(id, props)
    local direction = Util.propCheck(props, "direction", "string", id, "door")
    if direction == nil then return end
    if not (direction == "horizontal" or direction == "vertical") then
        softerror("door direction must be 'horziontal' or 'vertical'!")
        return
    end

    local closed = Util.propCheck(props, "closed", "boolean", id, "door")
    if closed == nil then return end

    local closeAfterEntry = false
    if props.close_after_entry then
        closeAfterEntry =
            Util.propCheck(props, "close_after_entry", "boolean", id, "door") --[[@as boolean]]
    end
    
    self.closed = props.closed
    self.closeAfterEntry = closeAfterEntry
    self.direction = direction

    if self.closeAfterEntry then
        self.collision = true
        self.touchMonitor = true
        self.msg:subscribe("touchEnded", self._touchEnded)

        self.render.sprite = Resmgr.newSprite("/res/sprites/door2.json")
        self.render.sprite.alignment = "topleft"
    end

    if self.direction == "vertical" then
        self.render.ox = -11
        self.render.oy = -16
        self.width = 16
        self.height = 32
        self.zIndex = -1
    elseif self.direction == "horizontal" then
        self.render.oy = -12
        self.width = 32
        self.height = 16
    end

    self:_setAnim(true)
    self.render.sprite:stop()
end

function Door:_setCollision(colId)
    local tx = math.floor(self.x / TILE_SIZE)
    local ty = math.floor(self.y / TILE_SIZE)

    if self.direction == "horizontal" then
        self.world:setCol(tx, ty, colId)
        self.world:setCol(tx + 1, ty, colId)
    elseif self.direction == "vertical" then
        self.world:setCol(tx, ty, colId)
        self.world:setCol(tx, ty + 1, colId)
    end
end

function Door:_added()
    self:_setCollision(self.closed and 1 or 0)
end

---@param invert boolean?
function Door:_setAnim(invert)
    local postfix = (self.closed ~= not not invert) and "_close" or "_open"
    self.render.sprite:play(self.direction .. postfix)
end

function Door:_touchEnded(oent)
    if not oent then
        return
    end

    if not self.closed then
        self:activate()
    end
end

function Door:activate()    
    self.closed = not self.closed
    if self.closed then
        self:_setCollision(1)
    else
        self:_setCollision(0)
    end

    self:_setAnim()
end

function Door:update()
    self.render.sprite:update(App.tickLength)
end

function Door:savePersistentData(data)
    Door.__super.savePersistentData(self, data)
    data.closed = self.closed
end

function Door:loadPersistentData(data)
    self.closed = data.closed

    self:_setAnim(true)
    self.render.sprite:stop()
end

return Door
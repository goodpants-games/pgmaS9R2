local Util = require("game.util")
local Resmgr = require("game.resmgr")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.entities.Door: game.entities.Entity
local Door = batteries.class {
    extends = require("game.entities.base")
}

function Door:new(x, y)
    self:super(x - 8, y - 8, 32, 32)
    self.collision = false
    self.touchMonitor = false

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/door.json"))
    self.render.sprite.alignment = "topleft"
    self.closed = true

    ---@type string?
    self.direction = nil
    -- self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/enemy1.json"))
    -- self.render.sprite.alignment = "topleft"

    self.msg:subscribe("addedToWorld", self._added)
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
    
    self.closed = props.closed
    self.direction = direction
    self:_setAnim(true)
    self.render.sprite:stop()
end

function Door:_setCollision(colId)
    local tx = math.floor(self.x / TILE_SIZE)
    local ty = math.floor(self.y / TILE_SIZE)

    if self.direction == "horizontal" then
        self.world:setCol(tx, ty + 1, colId)
        self.world:setCol(tx + 1, ty + 1, colId)
    end
end

function Door:_added()
    print("direction is ", self.direction)
    self:_setCollision(self.closed and 1 or 0)
end

---@param invert boolean?
function Door:_setAnim(invert)
    local postfix = (self.closed ~= not not invert) and "_close" or "_open"

    print("play anim", self.direction .. postfix)
    self.render.sprite:play(self.direction .. postfix)
end

function Door:activate()
    print("activated!")
    
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

return Door
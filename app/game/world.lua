local Tiled = require("tiled")
local Input = require("input")
local Consts = require("game.consts")
local Collision = require("game.collision")
local Util = require("game.util")

local TILE_SIZE = Consts.TILE_SIZE
local BUTTON_INPUTS = {"left", "right", "down", "up", "fire"}

---@class game.World: batteries.Class
---@overload fun():game.World
local World = batteries.class()

function World:new()
    self.map = Tiled.loadMap("/res/maps/test.lua")

    self.camX = 0.0
    self.camY = 0.0
    self.mouseX = 0.0
    self.mouseY = 0.0

    ---@type game.entities.Entity[]
    self.entities = {}
    ---@type game.entities.Entity?
    self.player = nil
    
    ---@private
    self._needEntityRemoval = false

     -- store button input states for the current and last frame
    -- self.buttonInputs[1] = current frame  (updated in rawUpdate)
    -- self.buttonInputs[2] = previous frame
    self.buttonInputs = {}
    for i=1, 2 do
        local t = {}
        for _, v in pairs(BUTTON_INPUTS) do
            t[v] = false
        end
        self.buttonInputs[i] = t
    end

    self:_loadMap()

    -- collision map is the first found tile layer
    local colMap
    for _, layer in ipairs(self.map.layers) do
        if layer.type == "tilelayer" then
            colMap = layer
            break
        end
    end

    if softassert(colMap, "map had no collision layer!") then
        local colMapGet = colMap.get
        ---@private
        self._getCol = function(tx, ty)
            return colMapGet(colMap, tx, ty)
        end
    else
        self._getCol = function() return nil end
    end
end

function World:update()
    local player = self.player

    self.mouseX = App.mouseX + self.camX
    self.mouseY = App.mouseY + self.camY

    for _, ent in ipairs(self.entities) do
        if ent.update then
            ent:update()
        end
    end

    self:_moveEntities()

    while self._needEntityRemoval do
        self._needEntityRemoval = false

        for i=#self.entities, 1, -1 do
            local ent = self.entities[i]
            if ent._removeOnFrameEnd then
                ent._removeOnFrameEnd = false
                ent.msg:publish("removingFromWorld", ent)
                ent.world = nil
                table.remove(self.entities, i)
            end
        end
    end

    if player then
        self.camX = (player.x + player.width / 2) - App.scrW / 2
        self.camY = (player.y + player.height / 2) - App.scrH / 2
    end

    self.mouseX = App.mouseX + self.camX
    self.mouseY = App.mouseY + self.camY

    for _, ent in ipairs(self.entities) do
        if ent.postUpdate then
            ent:postUpdate()
        end
    end

    for _, btn in ipairs(BUTTON_INPUTS) do
        self.buttonInputs[2][btn] = self.buttonInputs[1][btn]
    end
end

function World:draw()
    Lg.push()
    Lg.translate(-math.round(self.camX), -math.round(self.camY))

    self.map:draw(0, 0)

    for _, ent in ipairs(self.entities) do
        ent:draw()
    end

    Lg.pop()

    Lg.setColor(1, 1, 1)
    Lg.setLineWidth(1.0)
    Lg.rectangle("line", App.mouseX - 4, App.mouseY - 4, 8, 8)
end

---@param dt number
function World:rawUpdate(dt)
    local device = Input.players[1]

    for _, btn in ipairs(BUTTON_INPUTS) do
        self.buttonInputs[1][btn] = device:down(btn)
    end
end

function World:release()

end

---@param entType string
---@param x number
---@param y number
---@param ... any
---@return game.entities.Entity?
function World:newEntity(entType, x, y, ...)
    return Util.newEntity(entType, x, y, ...)
end

---@param ent game.entities.Entity
---@return boolean wasAdded
function World:addEntity(ent)
    if not table.index_of(self.entities, ent) then
        table.insert(self.entities, ent)
        ent.world = self
        ent.msg:publish("addedToWorld", ent)
        return true
    else
        return false
    end
end

---@param ent game.entities.Entity
function World:removeEntity(ent)
    if ent.world == self then
        ent._removeOnFrameEnd = true
        self._needEntityRemoval = true
    end
end

---@param btn string
---@return boolean
function World:isInputPressed(btn)
    return self.buttonInputs[1][btn] and not self.buttonInputs[2][btn]
end

---@param btn string
---@return boolean
function World:isInputReleased(btn)
    return not self.buttonInputs[1][btn] and self.buttonInputs[2][btn]
end

---@param btn string
---@return boolean
function World:isInputDown(btn)
    return self.buttonInputs[1][btn]
end

---Perform a raycast on the world. The length of the given direction vector
---dictates the maximum length the raycast will search for.
---@param x number X component of raycast origin.
---@param y number Y component of raycast origin.
---@param dx number X component of raycast direction.
---@param dy number Y component of raycast direction.
---@param colFlags integer? Collision group filter bitmask. If not given, nothing will be filtered.
---@return number? distance, number? nx, number? ny, game.entities.Enemy? entity
function World:raycast(x, y, dx, dy, colFlags)
    if not colFlags then
        colFlags = Consts.COLGROUP_ALL
    end

    -- check collisions with tiles
    if bit.band(colFlags, 0x1) then
        local dist, nx, ny = Collision.tileRaycast(x, y, dx, dy, self._getCol)
        if dist then
            return dist, nx, ny
        end
    end
end

--------------------------------------------------------------------------------

function World:_loadMap()
    for _, layer in ipairs(self.map.layers) do
        if layer.type == "objectgroup" then
            ---@cast layer pklove.tiled.ObjectLayer
            for _, obj in ipairs(layer.objects) do
                if obj.shape ~= "rectangle" then
                    softerror("tiled object shape should be a rectangle!")
                    goto continue
                end

                local cx = obj.x + obj.width / 2
                local cy = obj.y + obj.height / 2

                local ent = self:newEntity(obj.type, cx, cy)
                if not ent then
                    print("error: could not load entity")
                    goto continue
                end

                self:addEntity(ent)
                
                ::continue::
            end
        end
    end
end

function World:_moveEntities()
    -- first, move all X
    for _, ent in ipairs(self.entities) do
        ent.x = ent.x + ent.xVel
    end

    -- then, perform X collision
    for _, ent in ipairs(self.entities) do
        if ent.collision then
            local colX, colY, colW, colH, colEnt =
                Collision.gameCollision(ent.x, ent.y, ent.width, ent.height,
                                        self._getCol)
            if colX then
                local dir
                if ent.xVel > 0 then
                    ent.x = colX - ent.width
                    dir = -1
                else
                    ent.x = colX + colW
                    dir = 1
                end

                ent.xVel = ent.xVel * -ent.restitution
                ent.msg:publish("touched", ent, colEnt, dir, 0)
            end
        end
    end

    -- first, move all Y
    for _, ent in ipairs(self.entities) do
        ent.y = ent.y + ent.yVel
    end

    -- then, perform Y collision
    for _, ent in ipairs(self.entities) do
        if ent.collision then
            local colX, colY, colW, colH, colEnt =
                Collision.gameCollision(ent.x, ent.y, ent.width, ent.height,
                                        self._getCol)
            if colY then
                local dir
                if ent.yVel > 0 then
                    ent.y = colY - ent.height
                    dir = -1
                else
                    ent.y = colY + colH
                    dir = 1
                end
    
                ent.yVel = ent.yVel * -ent.restitution
                ent.msg:publish("touched", ent, colEnt, 0, dir)
            end
        end
    end
end

return World
local Tiled = require("tiled")
local Input = require("input")
local Consts = require("game.consts")

local TILE_SIZE = Consts.TILE_SIZE
local BUTTON_INPUTS = {"left", "right", "down", "up", "fire"}

---@class game.World: batteries.Class
---@overload fun():game.World
local World = batteries.class()

function World:new()
    self.map = Tiled.loadMap("/res/maps/test.lua")

    self.camX = 0.0
    self.camY = 0.0

    ---@type game.entities.Entity[]
    self.entities = {}
    ---@type game.entities.Entity?
    self.player = nil

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
end

function World:update()
    local player = self.player

    for _, ent in ipairs(self.entities) do
        if ent.update then
            ent:update()
        end
    end

    self:_moveEntities()

    for i=#self.entities, 1, -1 do
        local ent = self.entities[i]
        if ent._removeOnFrameEnd then
            ent.msg:publish("removingFromWorld", ent)
            ent.world = nil
            table.remove(self.entities, i)
        end
    end

    if player then
        self.camX = (player.x + player.width / 2) - App.scrW / 2
        self.camY = (player.y + player.height / 2) - App.scrH / 2
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
    local s, ctor = pcall(require, "game.entities." .. entType)
    if not s then
        softerror(("could not create entity '%s'\n%s"):format(entType, ctor))
        return nil
    end

    return ctor(x, y, ...)
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
---@return boolean wasRemoved
function World:removeEntity(ent)
    local idx = table.index_of(self.entities, ent)
    if idx then
        ent.msg:publish("removingFromWorld", ent)
        ent.world = nil
        table.remove(self.entities, idx)
        return true
    else
        return false
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

---@param x number
---@param y number
---@param w number
---@param h number
---@param map pklove.tiled.Map
---@return integer? colX, integer? colY, integer? colW, integer? colH, any? colEnt
local function gameCollision(x, y, w, h, map)
    local layer = map.layers[1] --[[@as pklove.tiled.TileLayer]]
    
    local sx = math.floor(x / TILE_SIZE)
    local sy = math.floor(y / TILE_SIZE)
    local ex = math.ceil((x + w) / TILE_SIZE) - 1
    local ey = math.ceil((y + h) / TILE_SIZE) - 1
    local cx = x + w / 2
    local cy = y + h / 2

    local collideX, collideY, collideW, collideH
    local minDist = math.huge

    -- first, check tile collisions
    for ty=sy, ey do
        for tx=sx, ex do
            local t = layer:get(tx, ty)
            if t ~= nil and t ~= 0 then
                local tcx = (tx + 0.5) * TILE_SIZE
                local tcy = (ty + 0.5) * TILE_SIZE
                local dx = tcx - cx
                local dy = tcy - cy
                local distsq = dx * dx + dy * dy
                if distsq < minDist then
                    collideX = tx * TILE_SIZE
                    collideY = ty * TILE_SIZE
                    collideW = TILE_SIZE
                    collideH = TILE_SIZE
                end
            end
        end
    end

    -- then, check entity collisions
    -- for _, ent in ipairs(ents) do
    --     if ent == entToIgnore or not ent.collide then
    --         goto continue
    --     end
        

    --     ::continue::
    -- end

    return collideX, collideY, collideW, collideH, nil
end

function World:_moveEntities()
    local map = self.map

    -- first, move all X
    for _, ent in ipairs(self.entities) do
        ent.x = ent.x + ent.xVel
    end

    -- then, perform X collision
    for _, ent in ipairs(self.entities) do
        if ent.collision then
            local colX, colY, colW, colH, colEnt =
                gameCollision(ent.x, ent.y, ent.width, ent.height,
                              map)
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
                gameCollision(ent.x, ent.y, ent.width, ent.height,
                              map)
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
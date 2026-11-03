local scene = Sceneman.scene()
local fontres = require("fontres")
local Tiled = require("tiled")
local Input = require("input")
local self

local TILE_SIZE = 16
local BUTTON_INPUTS = {"left", "right", "down", "up", "fire"}
local entityTypeInit = {}

local function createEnt(type, x, y, ...)
    local ent = {
        x = x,
        y = y,
        w = 0,
        h = 0,
        xVel = 0,
        yVel = 0,

        color = {
            r = 1,
            g = 1,
            b = 1,
        }
    }

    if type ~= nil then
        local init = entityTypeInit[type]
        if not init then
            softerror(("unknown entity type '%s'"):format(type))
            return nil
        end

        init(ent, x, y, ...)
    end

    return ent
end

function scene.load()
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.map = Tiled.loadMap("/res/maps/test.lua")
    self.camX = 0
    self.camY = 0

    self.ents = {}

    -- TODO: store button inputs using the BUTTON_INPUTS set for the current
    --       and previous frame. updating is done in rawUpdate
    -- self.buttonInputs = {}
    -- for i=1, 2 do
    --     local t = {}
    --     for _, v in pairs(buttonInputs) do
    --         t[v] = false
    --     end
    --     self.buttonInputs[i] = t
    -- end

    -- load entities from map
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

                local ent = createEnt(obj.type, cx, cy)
                if not ent then
                    print("error: could not load entity")
                    goto continue
                end

                if obj.type == "player" then
                    table.insert(self.ents, 1, ent)
                else
                    table.insert(self.ents, ent)
                end
                
                ::continue::
            end
        end
    end
end

function scene.unload()
    self = nil
end

---@param x number
---@param y number
---@param w number
---@param h number
---@return integer? colX, integer? colY, integer? colW, integer? colH
local function rectTileCollision(x, y, w, h)
    local layer = self.map.layers[1] --[[@as pklove.tiled.TileLayer]]
    
    local sx = math.floor(x / TILE_SIZE)
    local sy = math.floor(y / TILE_SIZE)
    local ex = math.ceil((x + w) / TILE_SIZE) - 1
    local ey = math.ceil((y + h) / TILE_SIZE) - 1
    local cx = x + w / 2
    local cy = y + h / 2

    local collideX, collideY, collideW, collideH
    local minDist = math.huge

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

    return collideX, collideY, collideW, collideH
end

local function moveEnts()
    for _, ent in ipairs(self.ents) do
        local colX, colY, colW, colH

        ent.x = ent.x + ent.xVel
        colX, colY, colW, colH = rectTileCollision(ent.x, ent.y, ent.w, ent.h)
        if colX then
            if ent.xVel > 0 then
                ent.x = colX - ent.w
            else
                ent.x = colX + colW
            end

            ent.xVel = 0.0
        end

        ent.y = ent.y + ent.yVel
        colX, colY, colW, colH = rectTileCollision(ent.x, ent.y, ent.w, ent.h)
        if colY then
            if ent.yVel > 0 then
                ent.y = colY - ent.h
            else
                ent.y = colY + colH
            end

            ent.yVel = 0.0
        end
    end
end

local function bool2int(v)
    return v and 1 or 0
end

function scene.rawUpdate(dt)
    local device = Input.players[1]
end

function scene.update()
    local player = self.ents[1]

    for _, ent in ipairs(self.ents) do
        if ent.update then
            ent:update()
        end
    end

    moveEnts()

    self.camX = (player.x + player.w/2) - App.scrW / 2
    self.camY = (player.y + player.h/2) - App.scrH / 2
end

function scene.draw()
    Lg.push()
    Lg.translate(-math.round(self.camX), -math.round(self.camY))

    self.map:draw(0, 0)

    for _, ent in ipairs(self.ents) do
        local color = ent.color
        Lg.setColor(color.r, color.g, color.b)
        Lg.rectangle("fill", ent.x, ent.y, ent.w, ent.h)
    end

    Lg.pop()

    Lg.setColor(1, 1, 1)
    Lg.setLineWidth(1.0)
    Lg.rectangle("line", App.mouseX - 4, App.mouseY - 4, 8, 8)
end










--------------------------------------------------------------------------------
-- ENTITY TYPES
--------------------------------------------------------------------------------

local scndat = self

local function centeredRect(x, y, w, h)
    return x - w/2, y - h/2, w, h
end

--------------------------------------------------------------------------------
-- PLAYER
local function playerUpdate(self)
    local device = Input.players[1]

    self.xVel = 2 * (bool2int(device:down("right")) - bool2int(device:down("left")))
    self.yVel = 2 * (bool2int(device:down("down")) - bool2int(device:down("up")))
end

function entityTypeInit.player(ent, x, y)
    ent.x, ent.y, ent.w, ent.h = centeredRect(x, y, 14, 14)
    local col = ent.color
    col.r, col.g, col.b = 0, 1, 0

    ent.update = playerUpdate
end

--------------------------------------------------------------------------------
-- ENEMY
function entityTypeInit.enemy(ent, x, y)
    ent.x, ent.y, ent.w, ent.h = centeredRect(x, y, 14, 14)
    local col = ent.color
    col.r, col.g, col.b = 1, 0, 0
end

--------------------------------------------------------------------------------
-- PROJECTILE
function entityTypeInit.projectile(self, x, y)
    self.x, self.y, self.w, self.h = centeredRect(x, y, 4, 4)
    local col = self.color
    col.r, col.g, col.b = 0.1, 0.1, 0.1
end

--------------------------------------------------------------------------------

return scene
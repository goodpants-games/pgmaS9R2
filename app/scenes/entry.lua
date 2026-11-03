local scene = Sceneman.scene()
local fontres = require("fontres")
local Tiled = require("tiled")
local Input = require("input")
local self

local TILE_SIZE = 16

function scene.load()
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.map = Tiled.loadMap("/res/maps/test.lua")
    self.camX = 0
    self.camY = 0

    self.ents = {}

    local plr = {
        x = 2 * TILE_SIZE,
        y = 2 * TILE_SIZE,
        w = 14,
        h = 14,
        xVel = 0,
        yVel = 0,
    }
    table.insert(self.ents, plr)
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

function scene.update()
    local player = self.ents[1]
    local device = Input.players[1]
    
    player.xVel = 2 * (bool2int(device:down("right")) - bool2int(device:down("left")))
    player.yVel = 2 * (bool2int(device:down("down")) - bool2int(device:down("up")))

    moveEnts()

    self.camX = (player.x + player.w/2) - App.scrW / 2
    self.camY = (player.y + player.h/2) - App.scrH / 2
end

function scene.draw()
    Lg.push("all")
    Lg.translate(-math.round(self.camX), -math.round(self.camY))

    self.map:draw(0, 0)

    for _, ent in ipairs(self.ents) do
        Lg.setColor(1, 0, 0)
        Lg.rectangle("fill", ent.x, ent.y, ent.w, ent.h)
    end

    Lg.pop()
end


return scene
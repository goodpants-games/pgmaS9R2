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

        restitution = 0,

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

local function isButtonPressed(btn)
    return self.buttonInputs[1][btn] and not self.buttonInputs[2][btn]
end
local function isButtonReleased(btn)
    return not self.buttonInputs[1][btn] and self.buttonInputs[2][btn]
end
local function isButtonDown(btn)
    return self.buttonInputs[1][btn]
end

function scene.load()
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.map = Tiled.loadMap("/res/maps/test.lua")
    self.camX = 0
    self.camY = 0

    self.ents = {}

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

local function rectRectCollision(x0, y0, w0, h0, x1, y1, w1, h1)
    return x0 < x1 + w1 and
           y0 < y1 + h1 and
           x0 + w0 > x1 and
           y0 + h0 > y1
end

local function moveEnts()
    for _, ent in ipairs(self.ents) do
        local colX, colY, colW, colH

        ent.x = ent.x + ent.xVel
        colX, colY, colW, colH = rectTileCollision(ent.x, ent.y, ent.w, ent.h)
        if colX then
            local dir
            if ent.xVel > 0 then
                ent.x = colX - ent.w
                dir = -1
            else
                ent.x = colX + colW
                dir = 1
            end

            ent.xVel = ent.xVel * -ent.restitution
            if ent.onTouch then
                ent:onTouch(nil, dir, 0)
            end
        end

        ent.y = ent.y + ent.yVel
        colX, colY, colW, colH = rectTileCollision(ent.x, ent.y, ent.w, ent.h)
        if colY then
            local dir
            if ent.yVel > 0 then
                ent.y = colY - ent.h
                dir = -1
            else
                ent.y = colY + colH
                dir = 1
            end

            ent.yVel = ent.yVel * -ent.restitution
            if ent.onTouch then
                ent:onTouch(nil, 0, dir)
            end
        end
    end

    -- collision detection between entities
    --[[
    for _, ent1 in pairs(self.ents) do
        for _, ent2 in pairs(self.ents) do
            if ent1 == ent2 then
                goto continue
            end

            local didCollide = rectRectCollision(

            )

            ::continue::
        end
    end
    --]]
end

local function bool2int(v)
    return v and 1 or 0
end

function scene.rawUpdate(dt)
    local device = Input.players[1]

    for _, btn in ipairs(BUTTON_INPUTS) do
        self.buttonInputs[1][btn] = device:down(btn)
    end
end

function scene.update()
    local player = self.ents[1]

    for _, ent in ipairs(self.ents) do
        if ent.update then
            ent:update()
        end
    end

    moveEnts()

    for i=#self.ents, 1, -1 do
        if self.ents[i].slatedForDeletion then
            table.remove(self.ents, i)
        end
    end

    self.camX = (player.x + player.w/2) - App.scrW / 2
    self.camY = (player.y + player.h/2) - App.scrH / 2

    for _, btn in ipairs(BUTTON_INPUTS) do
        self.buttonInputs[2][btn] = self.buttonInputs[1][btn]
    end
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

local function scndat() return self end

local function centeredRect(x, y, w, h)
    return x - w/2, y - h/2, w, h
end

--------------------------------------------------------------------------------
-- PLAYER
local function playerUpdate(self)
    local device = Input.players[1]

    self.xVel = 2 * (bool2int(isButtonDown("right")) - bool2int(isButtonDown("left")))
    self.yVel = 2 * (bool2int(isButtonDown("down")) - bool2int(isButtonDown("up")))

    if isButtonPressed("fire") then
        local centerX = self.x + self.w/2
        local centerY = self.y + self.h/2
        local mouseX = scndat().camX + App.mouseX
        local mouseY = scndat().camY + App.mouseY

        local fireDx = mouseX - centerX
        local fireDy = mouseY - centerY
        local fireDirLen = math.sqrt(fireDx * fireDx + fireDy * fireDy)
        if fireDirLen > 0 then
            fireDx = fireDx / fireDirLen
            fireDy = fireDy / fireDirLen
        end

        local proj = createEnt("projectile", self.x + self.w/2, self.y + self.h/2)
        proj.xVel = fireDx * 4
        proj.yVel = fireDy * 4

        table.insert(scndat().ents, proj)
    end
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
local function projectileTouched(self, other, normalX, normalY)
    print("proj touched!")
    self.life = self.life - 1
    if self.life <= 0 then
        self.slatedForDeletion = true
    end
end


function entityTypeInit.projectile(self, x, y)
    self.x, self.y, self.w, self.h = centeredRect(x, y, 4, 4)
    local col = self.color
    col.r, col.g, col.b = 0.1, 0.1, 0.1

    self.life = 4
    self.restitution = 1

    self.onTouch = projectileTouched
end

--------------------------------------------------------------------------------

return scene
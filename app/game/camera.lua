local Pathfind = require("game.pathfind")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.Camera: batteries.Class
---@overload fun(world:game.World):game.Camera
local Camera = batteries.class()

---@param world game.World
function Camera:new(world)
    self.world = world
    self.x = world.player:getCenterX()
    self.y = world.player:getCenterY()

    self.offsetX = 0.0
    self.offsetY = 0.0
end

function Camera:update()
    local world = self.world
    local player = world.player --[[@as game.entities.Player]]

    local playerCx = math.round(player.x) + player.width / 2
    local playerCy = math.round(player.y) + player.height / 2

    local targetOx = 0.0
    local targetOy = 0.0
    local approachSpeed = 0.1

    if player.fireCharge > 0 and player.gunSight and player.gunSight.world then
        local gunSight = player.gunSight
        local posAccumX = 0.0
        local posAccumY = 0.0
        local posAccumDivider = 1

        for i=1, #gunSight.lines, 2 do
            local x, y = gunSight.lines[i], gunSight.lines[i+1]

            posAccumX = posAccumX + (x - playerCx)
            posAccumY = posAccumY + (y - playerCy)
            posAccumDivider = posAccumDivider + 1
        end

        local focusX = posAccumX / posAccumDivider
        local focusY = posAccumY / posAccumDivider

        targetOx = focusX
        targetOy = focusY
        approachSpeed = 0.05
        
        -- focus on centerpoint between player and any enemies the player may
        -- be targeting...
        -- local posAccumX = 0.0
        -- local posAccumY = 0.0
        -- local posAccumDivider = 1

        -- local playerTx = math.floor(playerCx / TILE_SIZE)
        -- local playerTy = math.floor(playerCy / TILE_SIZE)

        -- for _, ent in ipairs(world.entities) do
        --     if ent:hasTag("enemy") then
        --         local cx, cy = ent:getCenterPos()
        --         local relPosX = cx - playerCx
        --         local relPosY = cy - playerCy

        --         local entX = math.floor(cx / TILE_SIZE)
        --         local entY = math.floor(cy / TILE_SIZE)

        --         local eucDist = math.length(relPosX, relPosY)
        --         if eucDist < 240 then
        --             local path = Pathfind.pathfind(world, playerTx, playerTy, entX, entY, nil)
        --             local traverseLen = path and #path / 2 or math.huge

        --             if traverseLen < 20 then
        --                 posAccumX = posAccumX + relPosX
        --                 posAccumY = posAccumY + relPosY
        --                 posAccumDivider = posAccumDivider + 1
        --             end
        --         end
        --     end
        -- end

        -- local focusX = posAccumX / posAccumDivider
        -- local focusY = posAccumY / posAccumDivider

        -- targetOx = focusX
        -- targetOy = focusY
    else
        local mouseOfsX = math.round(App.mouseX) - (App.scrW / 2)
        local mouseOfsY = math.round(App.mouseY) - (App.scrH / 2)

        targetOx = mouseOfsX / 4
        targetOy = mouseOfsY / 4
    end

    self.offsetX = self.offsetX + (targetOx - self.offsetX) * approachSpeed
    self.offsetY = self.offsetY + (targetOy - self.offsetY) * approachSpeed
    self.x = playerCx + self.offsetX
    self.y = playerCy + self.offsetY
end

return Camera
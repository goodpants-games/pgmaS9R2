local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local bool2int     = require("game.util").bool2int
local newEntity    = require("game.util").newEntity

---@class game.entities.Player: game.entities.Entity
local Player = batteries.class {
    extends = require("game.entities.base")
}

function Player:new(x, y)
    self:super(centeredRect(x, y, 14, 14))
    self.collision = true
    self.render = RectRenderer(0.0, 1.0, 0.0)

    self.msg:subscribe("addedToWorld", self._addedToWorld)
    self.msg:subscribe("removingFromWorld", self._removingFromWorld)

    -- create test entity
    self.testEnt = newEntity("base", 0, 0, 6, 6)
    self.testEnt.render = RectRenderer(1.0, 1.0, 1.0)
end

function Player:_addedToWorld()
    self.world.player = self
    self.world:addEntity(self.testEnt)
end

function Player:_removingFromWorld()
    if self.world.player == self then
        self.world.player = nil
    end

    self.testEnt:remove()
end

function Player:update()
    local world = softassert(self.world)
    if not world then return end

    self.xVel = 2 * (bool2int(world:isInputDown("right")) - bool2int(world:isInputDown("left")))
    self.yVel = 2 * (bool2int(world:isInputDown("down")) - bool2int(world:isInputDown("up")))

    local centerX = self.x + self.width/2
    local centerY = self.y + self.height/2

    if world:isInputPressed("fire") then
        local mouseX = world.camX + App.mouseX
        local mouseY = world.camY + App.mouseY

        local fireDx = mouseX - centerX
        local fireDy = mouseY - centerY
        local fireDirLen = math.sqrt(fireDx * fireDx + fireDy * fireDy)
        if fireDirLen > 0 then
            fireDx = fireDx / fireDirLen
            fireDy = fireDy / fireDirLen
        end

        local proj = world:newEntity("projectile", self.x + self.width/2, self.y + self.height/2)
        if proj then
            proj.xVel = fireDx * 4
            proj.yVel = fireDy * 4
            world:addEntity(proj)
        end
    end

    local rayDx = world.mouseX - centerX
    local rayDy = world.mouseY - centerY
    local dist, nx, ny =
        self.world:raycast(centerX, centerY,
                           rayDx, rayDy)
    if dist then
        local rayLen = math.length(rayDx, rayDy)
        local px = centerX + (rayDx / rayLen) * dist
        local py = centerY + (rayDy / rayLen) * dist

        self.testEnt.x = px - self.testEnt.width / 2
        self.testEnt.y = py - self.testEnt.height / 2
    end
end

return Player
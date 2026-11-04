local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local bool2int     = require("game.util").bool2int

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
end

function Player:_addedToWorld()
    self.world.player = self
end

function Player:_removingFromWorld()
    if self.world.player == self then
        self.world.player = nil
    end
end

function Player:update()
    local world = softassert(self.world)
    if not world then return end

    self.xVel = 2 * (bool2int(world:isInputDown("right")) - bool2int(world:isInputDown("left")))
    self.yVel = 2 * (bool2int(world:isInputDown("down")) - bool2int(world:isInputDown("up")))

    if world:isInputPressed("fire") then
        local centerX = self.x + self.width/2
        local centerY = self.y + self.height/2
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
        proj.xVel = fireDx * 4
        proj.yVel = fireDy * 4

        table.insert(world.entities, proj)
    end
end

return Player
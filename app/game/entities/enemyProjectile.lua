local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")

---@class game.entities.EnemyProjectile: game.Entity
local EnemyProjectile = batteries.class {
    extends = require("game.entity")
}

function EnemyProjectile:new(x, y)
    self:super(centeredRect(x, y, 2, 2))
    self.collision = true
    self.touchMonitor = true
    self.colGroup = 0
    self.colMask = bit.bor(Const.COLGROUP_PLAYER)

    self.restitution = 1.0
    self.bouncesLeft = 2

    self.msg:subscribe("touched", self._touched)
end

function EnemyProjectile:_touched(oent, nx, ny)
    if oent then
        Sceneman.switchScene("entry")
    else
        self.bouncesLeft = self.bouncesLeft - 1
        if self.bouncesLeft <= 0 then
            self:remove()
        end
    end
end

function EnemyProjectile:render()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    Lg.setColor(0.5, 0, 0)
    Lg.circle("fill", cx, cy, 3)
end

return EnemyProjectile
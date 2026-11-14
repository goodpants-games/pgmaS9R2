---@class game.entities.NpcPath: game.Entity
local NpcPath = batteries.class {
    extends = require("game.entity")
}

function NpcPath:new(x, y, poly)
    self:super(x, y, 0, 0)
    self.points = {}

    self.closed = poly.closed
    for _, point in ipairs(poly.points) do
        table.insert(self.points, point.x)
        table.insert(self.points, point.y)
    end
end

function NpcPath:getPointCount()
    return #self.points / 2
end

---@param index integer 1-based index
function NpcPath:getPoint(index)
    local i = (index-1) * 2 + 1
    return self.points[i], self.points[i+1]
end

return NpcPath
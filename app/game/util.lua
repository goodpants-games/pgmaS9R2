local Util = {}

-- Rectangle Renderer --
---@class game.RectRenderer: batteries.Class
---@overload fun(r:number?, g:number?, b:number?):game.RectRenderer
local RectRenderer = batteries.class()
Util.RectRenderer = RectRenderer

function RectRenderer:new(r, g, b)
    self.r = r or 1.0
    self.g = g or 1.0
    self.b = b or 1.0
end

---@param ent game.entities.Entity
function RectRenderer:draw(ent)
    Lg.setColor(self.r, self.g, self.b)
    Lg.rectangle("fill", ent.x, ent.y, ent.width, ent.height)
end
------------------------

function Util.centeredRect(x, y, w, h)
    return x - w/2, y - h/2, w, h
end

function Util.bool2int(v)
    return v and 1 or 0
end

return Util
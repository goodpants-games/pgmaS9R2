local Util = {}

------------------------------ RectRenderer ------------------------------------

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

------------------------------ entity construction -----------------------------

local entityTypes

local function loadEntityTypes()
    entityTypes = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems("/game/entities/")) do
        local name = string.match(f, "^([%w_]+)%.lua$")
        if name then
            entityTypes[name] = require("game.entities." .. name)
        end
    end
end

---@param entType string
---@param x number
---@param y number
---@param ... any
---@return game.entities.Entity?
function Util.newEntity(entType, x, y, ...)
    if not entityTypes then
        loadEntityTypes()     
    end

    local ctor = entityTypes[entType]
    if not ctor then
        softerror(("entity type '%s' is unknown"):format(entType))
        return nil
    end

    return ctor(x, y, ...)
end

--------------------------------- miscellaneous --------------------------------

function Util.centeredRect(x, y, w, h)
    return x - w/2, y - h/2, w, h
end

function Util.bool2int(v)
    return v and 1 or 0
end

---unordered pairing function of two unsigned integers
---@param a integer
---@param b integer
function Util.upair2u(a, b)
    if a > b then
        a, b = b, a
    end
    return (a * a + a) / 2 + b
end

return Util
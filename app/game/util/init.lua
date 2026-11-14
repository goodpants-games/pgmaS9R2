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

---@param ent game.Entity
function RectRenderer:draw(ent)
    Lg.setColor(self.r, self.g, self.b)
    Lg.rectangle("fill", ent.x, ent.y, ent.width, ent.height)
end

-------------------------------- SpriteRenderer ---------------------------------

---@class game.SpriteRenderer: batteries.Class
---@overload fun(spr:pklove.Sprite):game.SpriteRenderer
local SpriteRenderer = batteries.class()
Util.SpriteRenderer = SpriteRenderer

---@param spr pklove.Sprite
function SpriteRenderer:new(spr)
    self.sprite = spr

    self.ox = 0.0
    self.oy = 0.0
    self.r = 1.0
    self.g = 1.0
    self.b = 1.0
end

function SpriteRenderer:draw(ent)
    Lg.setColor(self.r, self.g, self.b)
    self.sprite:draw(math.round(ent.x) + self.ox, math.round(ent.y) + self.oy)

    if Debug.enabled then
        Lg.rectangle("line", math.round(ent.x), math.round(ent.y), math.round(ent.width), math.round(ent.height))
    end
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
---@return game.Entity?
function Util.newEntity(entType, x, y, ...)
    if not entityTypes then
        loadEntityTypes()     
    end

    local ctor = entityTypes[entType]
    if not ctor then
        softerror(("entity type '%s' is unknown"):format(entType))
        return nil
    end

    local ent = ctor(x, y, ...)
    ent.typeName = entType
    return ent
end

local PROP_CHECK_ERR_FMTSTR = "{object %i '%s'} property '%s': %s"

function Util.propCheck(props, name, expectedType, id, className)
    if expectedType == "float" or expectedType == "int" then
        expectedType = "number"
    end

    local v = props[name]
    if v == nil then
        warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, "does not exist"))
        return
    end

    if expectedType == "color" then
        if not type(v) == "string" then
            warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, "expected color string"))
            return
        end
        if not (v:len() == 9 and v:sub(1,1) == "#") then
            warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, "invalid color string"))
            return
        end

        local hex = tonumber(v:sub(2), 16)
        return batteries.colour.unpack_rgba(hex)
    end

    if expectedType == "object" then
        if not (type(v) == "table" and v.id) then
            warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, "expected object ref"))
            return
        end
        return v.id
    end

    if expectedType:sub(1, 5) == "list[" then
        if not type(v) == "table" then
            warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, "expected list"))
            return
        end 

        local subType = expectedType:sub(6,-2)
        if subType == "object" then
            for _, subv in ipairs(v) do
                if not type(subv) == "number" then
                    warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, "expected list[object]"))
                    return
                end
            end
        else
            for k, _ in ipairs(v) do
                if Util.propCheck(v, k, expectedType, id, className) == nil then
                    return
                end
            end
        end

        return v
    end

    if not type(v) == expectedType then
        local errstr = ("expected %s, got %s"):format(expectedType, type(v))
        warn(PROP_CHECK_ERR_FMTSTR:format(id, className, name, errstr))
        return
    end

    return v
end

--------------------------------- miscellaneous --------------------------------

---@param ent game.Entity
---@param overTilemapFilter boolean
function Util.drawEntity(ent, overTilemapFilter)
    if not ent.visible then return end

    local renderer = ent.render
    if renderer and ent.alwaysDrawOverTilemap == overTilemapFilter then
        Lg.push()
        Lg.translate(0, math.round(-ent.zOffset))

        if type(renderer) == "function" then
            renderer(ent)
        else
            renderer:draw(ent)
        end

        Lg.pop()
    end
end

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

---pairing function of two unsigned integers
---@param a integer
---@param b integer
function Util.pair2u(a, b)
    return ((a + b) * (a + b + 1)) / 2 + b
end

return Util
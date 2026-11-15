---@class game.util.DirAnim: batteries.Class
---@overload fun():game.util.DirAnim
local DirAnim = batteries.class()

DirAnim.DIRECTIONS = {"r", "d", "l", "u"}

---@alias game.util.DirAnim.Direction
---| "r"
---| "l"
---| "d"
---| "u"

---@param ang number
---@param dirCount integer
local function getAngleInt(ang, dirCount)
    ang = math.normalise_angle(ang - math.pi) + math.pi
    return math.round(ang / math.tau * dirCount) % dirCount
end

local function fuzzyEq(a, b)
    return math.abs(a - b) < 1e-8
end

function DirAnim:new()
    ---@type game.util.DirAnim.Direction
    self.direction = "r"
    ---@type string?
    self.curAnim = nil
end

---@param sprite pklove.Sprite
---@param angle number
function DirAnim:setDirection(sprite, angle)
    angle = math.normalise_angle(angle)

    local dir
    if fuzzyEq(angle, math.pi/4) or fuzzyEq(angle, 3*math.pi/4) then
        dir = "d"
    elseif fuzzyEq(angle, -math.pi/4) or fuzzyEq(angle, -3*math.pi/4) then
        dir = "u"
    else
        local angInt = getAngleInt(angle, 4)
        dir = DirAnim.DIRECTIONS[angInt+1]
    end

    if self.direction == dir then
        return
    end
    
    self.direction = dir

    if self.curAnim then
        local timeAccum = sprite._timeAccum ---@diagnostic disable-line
        local af = sprite:getAnimFrame()
        local fullAnimName = self.curAnim .. "_" .. self.direction
        local s = pcall(sprite.play, sprite, fullAnimName)
        if not s then
            warn("could not play animation", fullAnimName)
        end

        if af then
            sprite.cel = sprite.cel + af - 1
            sprite._timeAccum = timeAccum ---@diagnostic disable-line
        end
    end
end

---@param sprite pklove.Sprite
---@param animName string
function DirAnim:play(sprite, animName)
    local fullAnimName = animName .. "_" .. self.direction
    local s = pcall(sprite.play, sprite, fullAnimName)
    if not s then
        warn("could not play animation " .. fullAnimName)
    end

    self.curAnim = animName
end

---@param sprite pklove.Sprite
---@param animName string
---@param ang number
function DirAnim:setOctoDir(sprite, animName, ang)
    local angInt = getAngleInt(-ang + math.pi/2, 8)
    local celStart = sprite.res.animations[animName].from
    if sprite.curAnim then
        sprite:stop()
    end

    sprite.cel = celStart + angInt
    self.curAnim = nil
end

return DirAnim
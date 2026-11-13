---@class game.util.DirAnim: batteries.Class
---@overload fun():game.util.DirAnim
local DirAnim = batteries.class()

---@alias game.util.DirAnim.Direction
---| "r"
---| "l"
---| "d"
---| "u"

function DirAnim:new()
    ---@type game.util.DirAnim.Direction
    self.direction = "r"
    ---@type string?
    self.curAnim = nil
end

---@param sprite pklove.Sprite
---@param dir game.util.DirAnim.Direction
function DirAnim:setDirection(sprite, dir)
    if self.direction == dir then
        return
    end
    
    self.direction = dir

    if self.curAnim then
        local af = sprite:getAnimFrame()
        sprite:play(self.curAnim .. "_" .. self.direction)
        sprite.cel = sprite.cel + af - 1
    end
end

---@param sprite pklove.Sprite
---@param animName string
function DirAnim:play(sprite, animName)
    sprite:play(animName .. "_" .. self.direction)
    self.curAnim = animName
end

return DirAnim
local Sprite = require("sprite")

local ResourceManager = {}
local cache = {}

function ResourceManager.clear()
    for _, v in pairs(cache) do
        if v.release then
            v:release()
        end
    end
    cache = {}
end

---@param path string
---@return pklove.SpriteResource
function ResourceManager.getSpriteRes(path)
    local res = cache[path]
    if not res then
        res = Sprite.loadResource(path)
        cache[path] = res
    end
    assert(Sprite.isSpriteResource(res), "not a SpriteResource")
    ---@cast res pklove.SpriteResource
    return res
end

---@param path string
---@return love.Image
function ResourceManager.getImage(path)
    local res = cache[path]
    if not res then
        res = Lg.newImage(path)
        cache[path] = res
    end
    assert(res.typeOf and res:typeOf("Image"), "not an Image")
    ---@cast res love.Image
    return res
end

function ResourceManager.newSprite(name)
    local res = ResourceManager.getSpriteRes(name)
    return Sprite.new(res)
end

return ResourceManager
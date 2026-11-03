--[[
    sprite: atlas/animation loader.
    dependencies:
      - https://github.com/rxi/json.lua/
        (or something with a compatible decoder API.)

    loading/managing sprite resources
    ----
    call module.loadResource(path) to load a sprite resource. sprite resource
    data is contained in a separate png and json file, in the json format used
    by aseprite. the path given must be the path to the json file. it looks at
    the given png image path inside the json file to load the atlas texture.

    you can also use module.loadResourceFromMemory(data, atlas) to create
    resources. data is the deserialized JSON data as a Lua table, and atlas is
    the love Image containing the texture atlas.

    to create a sprite, call module.load(resourceOrPath) with either a resource
    table returned from loadResource, or the path to the resource file to load.

    you can clone a sprite with sprite:clone(). the cloned sprite will share the
    same resources as the original sprite. sprite resources can also be released
    with sprite:release(). it will release the resource only if it is the only
    sprite not yet garbage-collected that is using it.
    
    you may also use this library to load sprite resources from basic
    spritesheets, using the module.loadSpriteSheet(atlas, params) function.
    atlas is the love Image, and params is a table of the following format:
        {
            celWidth: integer
            celHeight: integer
            celDuration: number?, frame duration of each cel in milliseconds.
                         if not given, defaults to 0.
            rows: integer
            cols: integer
            originX: integer?, left side of the subtexture within the atlas.
            originY: integer?, top side of the subtexture within the atlas.
            spacingX: integer?, horizontal spacing between each cel.
            spacingY: integer?, vertical spacing between each cel.
            paddingX: integer?, number of horizontal pixels of inner padding per
                      cel.
            paddingY: integer?, number of vertical pixels of inner padding per
                      cel.
        }
    
    the resource (obviously) is created with no animations. if you want to add
    animations, refer to the "object structure" section of this documentation.


    rendering
    ----
    once you have a sprite, you can render it using the following two functions:
        sprite:draw(x, y, r, sx, sy, ox, oy, kx, ky)
        sprite:drawCel(index, x, y, r, sx, sy, ox, oy, kx, ky)
    
    x and y is where the cel will be drawn. r is rotation, sx and sy is scale,
    kx and ky is shear factor, ox and oy is the origin offset. all of those
    parameters are optional. sprite.draw draws the current frame of the
    animation, and drawCel draws the index of a specific cel (indexed from 1).

    you may also change the alignment of the sprite. that is, if (x, y) when
    drawing is the center or the top-left of the sprite. each sprite and sprite
    resource has an alignment field, which can be "center", "topleft", or nil.
    if it nil, then it will inherit the alignment. that means sprites will
    refer to the sprite resource's alignment, and sprite resources will refer to
    the alignment defined in module.fallbackAlignment. the default fallback
    alignment is "topleft".

    the global fields module.defaultSpriteAlignment and
    module.defaultResourceAlignment also exist. when creating new sprites
    or sprite resources, their alignment fields will be set to these fields
    respectively. they are nil (inherit) by default.


    animations
    ----
    play animations with sprite:play(animName).
    stop playback with sprite:stop().
    check if an animation exists with sprite:hasAnim(animName).
    update the animation on each frame with sprite:update(dt).


    object structure
    ----
    each sprite object also has certain properties you can inspect:
        - sprite.curAnim: a string describing the name of the currently playing
                          animation. nil if no animation is playing.
        - sprite.cel: an integer describing the current cel that should be
                      displayed
        - sprite.res: the sprite resource data
    
    in addition, each sprite resource has these properties:
        - res.atlas: the sprite atlas, as a love Image.
        - res.animations: key-value table of animation names paired with
                          animation data in the following format:
            {
                from: integer, index of first cel in the animation
                to: integer, index of last cel in the animation
                loopCount: integer, number of times animation should loop before
                           stopping
                loopPoint: integer, start index of looping portion of the cel.
                           always present.
            }
        - res.cels: the cel list. each item is a table in the following format:
            {
                quad: the love Quad.
                ox: X offset to use when rendering from the top-left.
                oy: Y offset to use when rendering from the top-left
                cx: X offset to use when rendering from the center.
                cy: Y offset to use when rendering from the center.
                duration: the duration of the cel in milliseconds
            }


    creating animations in aseprite
    ----
    animations are created using the aseprite tags feature. the name of the tag
    is the name of the animation. the repeat property of the tag works as
    expected in-game as well.

    this library has the ability to represent loop points -- points the
    animation returns to when it loops that is different than the start point of
    the animation. however, aseprite has no mechanism for representing this, so
    there is a workaround:
    
    if you were to create two tags that share an end point but have different
    start points, those two tags become part of the same animation. the long tag
    is the one whose name gets associated with the animation, and its start
    point becomes the animation's initial frame. the start point of the short
    tag, which is therefore the tag with the later start point, is the point the
    animation returns to when it loops.

    confusing explanation? maybe a visual will help:

    A     B                C
    +--------[jump]--------+
    |     +---[jump-loop]--+
    |     |                |

    animation name: jump
    A: start point
    B: point animation returns to when it loops
    C: end point

    note the tag named "jump-loop" can be named anything, it only detects which
    tag is the looping area from shared end points.


    atlas data format
    ----
    this is what the atlas data table (aka, the aseprite .json export format)
    should look like. note that the meta field is optional.

    {
        frames: Cel[],
        meta = {
            frameTags: Tag[]
        }
    }

    type Cel = {
        filename: string,
            this field is ignored.
        
        frame: {x: number, y: number, w: number, h: number},
            these are the coordinates that will be passed to
            love.graphics.newQuad

        rotated: boolean,
            aseprite always sets this to false. nonetheless, this atlas loader
            does not support rotated frames.
        
        trimmed: boolean,
            true if the cel or sprite was exported with trimming enabled. this
            field is ignored.
        
        spriteSourceSize: {x: number, y: number, w: number, h: number},
            (x, y) is the top-left corner of the cel relative to the cel's
            original frame. this will be (0, 0) if the cel/sprite is not
            trimmed. this is not dependent on cel padding. (w, h) is the inner
            size of the frame according to cel padding.
        
        sourceSize: {w: number, h: number},
            the original size of the cel. it will be different than the frame
            size and the size of spriteSourceSize if the cel or sprite was
            trimmed, or if the cel was padded.
        
        duration: number
            frame duration, in milliseconds.
    }

    type Tag = {
        name: string,
        from: integer,
            cel index. 0-indexed
        to: integer,
            cel index. inclusive, 0-indexed
        repeat: integer?
            if omitted, the animation will repeat infinitely.
    }
    
    
    copyright notice
    ----
    
    Copyright (c) 2025-2026 pkhead

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
       claim that you wrote the original software. If you use this software
       in a product, an acknowledgment in the product documentation would be
       appreciated but is not required.
    2. Altered source versions must be plainly marked as such, and must not be
       misrepresented as being the original software.
    3. This notice may not be removed or altered from any source distribution.
--]]

local JSON = require("json")

local module = {}
module._version = "0.2.1"

---@alias pklove.SpriteAlignment "topleft"|"center"

---@class pklove.SpriteSheetLoadParams
---@field celWidth number
---@field celHeight number
---@field celDuration number? Frame duration of each cel in milliseconds.
---@field rows number
---@field cols number
---@field originX number?
---@field originY number?
---@field spacingX number? Horizontal spacing between each cel.
---@field spacingY number? Vertical spacing between each cel.
---@field paddingX number? Number of horizontal pixels of inner padding per cel.
---@field paddingY number? Number of vertical pixels of inner padding per cel.

---If a drawn Sprite and its SpriteResource both have alignment set to nil, then
---it should use this alignment instead.
---@type pklove.SpriteAlignment
module.fallbackAlignment = "topleft"

---All SpriteResources created henceforth will have this set as their alignment.
---Set to `nil` to indicate that it should inherit from
---`SpriteModule.fallbackAlignment` on a per-draw basis.
---@type pklove.SpriteAlignment?
module.defaultResourceAlignment = nil

---All Sprites created henceforth will have this set as their alignment. Set
---to `nil` to indicate that it should inherit the alignment from the sprite
---resource on a per-draw basis.
---@type pklove.SpriteAlignment?
module.defaultSpriteAlignment = nil

---If this is a positive non-zero number, the position of rendered sprite cels
---are rounded to a grid of this resolution, in pixels.
---@type number
module.pixelSnapping = 1

---@class pklove.SpriteResource
---@field _refs {[pklove.Sprite]: boolean}
---@field atlas love.Image
---@field cels {quad: love.Quad, cx: number, cy: number, ox: number, oy: number, duration: number}[]
---@field animations {[string]:{from: integer, to: integer, loopCount: integer, loopPoint: integer}}
---@field alignment pklove.SpriteAlignment?
local SpriteResource = {}
SpriteResource.__index = SpriteResource

---@class pklove.Sprite
---@field private _timeAccum number
---@field private _loopCount integer
---@field private _animChanged boolean
---@field cel integer
---@field res pklove.SpriteResource
---@field alignment pklove.SpriteAlignment?
local Sprite = {}
Sprite.__index = Sprite

local function pathSplit(path)
    local res = {}
    local i = 1

    while true do
        local idx = string.find(path, "/", i, true)
        if idx == nil then
            table.insert(res, string.sub(path, i))
            break
        end

        table.insert(res, string.sub(path, i, idx-1))
        i = idx + 1
    end
    
    return res
end

local function pathNormalize(path)
    local stack = {}
    local depth = 0

    for _, v in pairs(path) do
        if v == ".." then
            if depth <= 0 then
                stack[#stack+1] = v
            else
                stack[#stack] = nil
            end

            depth = depth - 1
        elseif v ~= "." then
            stack[#stack+1] = v
            depth = depth + 1
        end
    end

    if #stack == 0 then
        return "."
    else
        return table.concat(stack, "/")
    end
end

local function round(n)
    if n < 0 then
		return math.ceil(n - 0.5)
	end
	return math.floor(n + 0.5)
end

---Load an Aseprite export from preloaded data.
---@param data table The Aseprite export data; the JSON data converted into a Lua table.
---@param atlas love.Image The image atlas.
---@return pklove.SpriteResource
function module.loadResourceFromMemory(data, atlas)
    local resource = setmetatable({}, SpriteResource)
    
    -- used for release call
    resource._refs = setmetatable({}, {
        __mode = "k"
    })

    resource.atlas = atlas

    -- load cels
    resource.cels = {}
    for _, cel in ipairs(data.frames) do
        local frame = cel.frame

        -- frame render offset (top-left)
        local ox = -cel.spriteSourceSize.x
        local oy = -cel.spriteSourceSize.y

        -- frame render offset (center)
        local cx = cel.sourceSize.w / 2 - cel.spriteSourceSize.x
        local cy = cel.sourceSize.h / 2 - cel.spriteSourceSize.y

        table.insert(resource.cels, {
            quad = love.graphics.newQuad(frame.x, frame.y, frame.w, frame.h, atlas:getWidth(), atlas:getHeight()),
            ox = ox,
            oy = oy,
            cx = cx,
            cy = cy,
            duration = cel.duration
        })
    end

    -- load animation data
    resource.animations = {}
    if data.meta and data.meta.frameTags then
        for _, anim in ipairs(data.meta.frameTags) do
            resource.animations[anim.name] = {
                from = anim.from + 1,
                to = anim.to + 1,
                loopCount = tonumber(anim["repeat"]) or 0,
                loopPoint = anim.from + 1
            }
        end

        -- custom loop points
        for _, start_anim in pairs(resource.animations) do
            for _, loop_anim in pairs(resource.animations) do
                -- if two animations share the same endpoint but have different starting points,
                -- the longer one is the original animation, and the shorter one is the loop section
                if start_anim ~= loop_anim and start_anim.to == loop_anim.to and start_anim.from < loop_anim.from then
                    start_anim.loopPoint = loop_anim.from
                end
            end
        end
    end

    resource.alignment = module.defaultResourceAlignment

    return resource
end

---Load an Aseprite export from its JSON file.
---@param jsonPath string Path to the JSON file.
---@return pklove.SpriteResource
function module.loadResource(jsonPath)
    local jsonData, err = love.filesystem.read(jsonPath)
    if not jsonData then
        error(err)
    end

    local data = JSON.decode(jsonData)
    
    -- load atlas texture
    local pngPath ---@type string
    do
        local path = pathSplit(jsonPath)
        local imagePath = pathSplit(data.meta.image)
        table.remove(path)
        for _, v in ipairs(imagePath) do
            table.insert(path, v)
        end

        pngPath = pathNormalize(path)
    end

    local atlas = love.graphics.newImage(pngPath)
    
    return module.loadResourceFromMemory(data, atlas)
end

---Load a resource from a spritesheet.
---@param atlas love.Image
---@param params pklove.SpriteSheetLoadParams
function module.loadSpriteSheet(atlas, params)
    local celWidth = assert(params.celWidth, "parameters did not have required 'celWidth' property")
    local celHeight = assert(params.celHeight, "parameters did not have required 'celHeight' property")
    local celDuration = params.celDuration or 0
    local rows = assert(params.rows, "parameters did not have required 'rows' property")
    local cols = assert(params.cols, "parameters did not have required 'cols' property")
    local originX = params.originX or 0
    local originY = params.originY or 0
    local spacingX = params.spacingX or 0
    local spacingY = params.spacingY or 0
    local paddingX = params.paddingX or 0
    local paddingY = params.paddingY or 0

    local data = {}
    data.frames = {}

    local i = 1
    for r=1, rows do
        for c=1, cols do
            local celX = (c-1) * (celWidth + spacingX) + originX
            local celY = (r-1) * (celHeight + spacingY) + originY

            data.frames[i] = {
                filename = tostring(i),
                frame = {
                    x = celX + paddingX,
                    y = celY + paddingY,
                    w = celWidth - paddingX,
                    h = celHeight - paddingY
                },
                rotated = false,
                trimmed = false,
                spriteSourceSize = {
                    x = paddingX,
                    y = paddingY,
                    w = celWidth - paddingX,
                    h = celHeight - paddingY
                },
                sourceSize = {
                    w = celWidth,
                    h = celHeight
                },
                duration = celDuration
            }

            i = i + 1
        end
    end

    return module.loadResourceFromMemory(data, atlas)
end

---Create a sprite from a sprite resource. (see loadResource or loadResourceFromMemory)
---@param pathOrResource pklove.SpriteResource|string A sprite resource or the path to it.
function module.new(pathOrResource)
    local resource
    if type(pathOrResource) == "string" then
        resource = module.loadResource(pathOrResource)
    else
        resource = pathOrResource
    end

    ---@class pklove.Sprite
    local self = setmetatable({}, Sprite)
    self.res = resource
    self.cel = 1
    resource._refs[self] = true

    ---(Read-only) The name of the currently playing animation.
    self.curAnim = nil ---@type string?

    self.alignment = module.defaultSpriteAlignment
    
    self._timeAccum = 0
    self._loopCount = 0
    self._animChanged = false

    return self
end

---@param sprite any?
---@return boolean
function module.isSprite(sprite)
    return type(sprite) == "table" and getmetatable(sprite) == Sprite
end

---@param spriteRes any?
---@return boolean
function module.isSpriteResource(spriteRes)
    return type(spriteRes) == "table" and
           getmetatable(spriteRes) == SpriteResource
end

---Release this SpriteResource.
function SpriteResource:release()
    if self.cels then
        for _, cel in pairs(self.cels) do
            cel.quad:release()
        end
    end
    
    if self.atlas then
        self.atlas:release()
    end

    self.cels = nil
    self.atlas = nil
    self.animations = nil
end

--- Release the resources associated with the sprite.
--- 
--- This will unlink it with the resource, and if it is the
--- only sprite remaining using it, will release the resource
--- as well. It uses a weak table to detect if no other Sprites are referencing
--- the resource.
function Sprite:release()
    self.res._refs[self] = nil

    if not next(self.res._refs) then
        self.res:release()
    end

    self.res = nil
end

--- Clone the sprite, keeping frame and animation data linked
function Sprite:clone()
    local clone = setmetatable({}, Sprite)

    for i, v in pairs(self) do
        clone[i] = v
    end

    clone.res._refs[clone] = true
    return clone
end

---Update the sprite animation
---@param dt number Delta-time in seconds
---@return boolean new True if the animation switched to a new cel
function Sprite:update(dt)
    if not self.curAnim then
        return false
    end

    local newCel = false
    local cel = self.res.cels[self.cel]
    local curAnim = self.res.animations[self.curAnim]
    
    self._timeAccum = self._timeAccum + dt
    local celDuration = cel.duration / 1000;
    while self._timeAccum >= celDuration do
        self._timeAccum = self._timeAccum - celDuration
        
        if self.cel >= curAnim.to then
            self._loopCount = self._loopCount + 1

            if curAnim.loopCount > 0 and self._loopCount >= curAnim.loopCount then
                self:stop()
                break
            else
                self.cel = curAnim.loopPoint
                newCel = true
            end
        else
            self.cel = self.cel + 1
            newCel = true
        end
    end

    if self._animChanged then
        self._animChanged = false
        return true
    else
        return newCel
    end
end

---Play an animation
---@param animName string
function Sprite:play(animName)
    if self.res.animations[animName] == nil then
        error(("unknown animation '%s'"):format(animName), 2)
    end

    self._loopCount = 0
    self._timeAccum = 0
    self._animChanged = true
    self.curAnim = animName
    self.cel = self.res.animations[animName].from
end

---Stop currently playing animation, if any
function Sprite:stop()
    self.curAnim = nil
end

---Return true if the sprite has an animation
---@param animName string
function Sprite:hasAnim(animName)
    return self.res.animations[animName] ~= nil
end

---Get the index of the current frame relative to the start of the animation.
---@return integer? animFrame The current frame, starting from 1. Returns nil if no animation is playing.
function Sprite:getAnimFrame()
    if not self.curAnim then
        return nil
    end

    return self.cel - self.res.animations[self.curAnim].from + 1
end

---Draw a specific cel of the sprite
---@param index integer Index of the cel to draw
---@param x number The X coordinate of the sprite's center
---@param y number The Y coordinate of the sprite's center
---@param r? number Rotation in radians
---@param sx? number X scale factor
---@param sy? number Y scale factor
---@param ox? number X origin offset
---@param oy? number Y origin offset
---@param kx? number X skew factor
---@param ky? number Y skew factor
function Sprite:drawCel(index, x, y, r, sx, sy, ox, oy, kx, ky)
    local cel = self.res.cels[index]

    local align = self.alignment
    if not align then
        align = self.res.alignment
        if not align then
            align = module.fallbackAlignment
        end
    end

    if ox == nil then ox = 0 end
    if oy == nil then oy = 0 end
    
    if align == "topleft" then
        ox, oy = ox + cel.ox, oy + cel.oy
    elseif align == "center" then
        ox, oy = ox + cel.cx, oy + cel.cy
    else
        error(("invalid sprite alignment '%s'. expected: 'center', 'topleft"):format(tostring(align)))
    end

    local pixelSnapping = module.pixelSnapping
    if pixelSnapping > 0 then
        ox = round(ox / pixelSnapping) * pixelSnapping
        oy = round(oy / pixelSnapping) * pixelSnapping
        x = round(x / pixelSnapping) * pixelSnapping
        y = round(y / pixelSnapping) * pixelSnapping
    end

    love.graphics.draw(self.res.atlas, cel.quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draw the sprite
---@param x number The X coordinate of the sprite's center
---@param y number The Y coordinate of the sprite's center
---@param r? number Rotation in radians
---@param sx? number X scale factor
---@param sy? number Y scale factor
---@param kx? number X skew factor
---@param ky? number Y skew factor
function Sprite:draw(x, y, r, sx, sy, kx, ky)
    self:drawCel(self.cel, x, y, r, sx, sy, kx, ky)
end

return module

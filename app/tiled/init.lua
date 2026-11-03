--[[
    tiled map loader


    loading maps
    ----
    call tiled.loadMap(mapPath, mapSettings) to load a map, where mapPath is the
    path to the lua export of the map file. mapSettings is an optional table
    which will be explained later. it returns a map object, which is directly
    based off the root table of the lua export.

    the mapSettings table may contain the following fields:
        - loadTexture:
            a function which, given a path to an image file, should return a
            loaded love.graphics Image. the same path is permitted (and
            recommended) to return the same Image object. if not provided, it
            will use a default function which keeps an internal cache.

            IMPORTANT: with a user-provided function, loaded textures are not
            released when the map is. it is expected that you will release them
            yourself. this is so you can reuse the same cache across multiple
            map loads.

    map structure
    ----
    this is a non-comprehensive list of fields accessible in map objects:
        - map.width: the width of the map in tiles.
        - map.height: the height of the map in tiles.
        - map.tilewidth: the width, in pixels, of each individaul tile.
        - map.tileheight: the height, in pixels, of each individual tile.
        - map.properties: table of custom properties.
        - map.tilesets: list of tilesets present in the level.
        - map.layers: list of map layers
    
    method list:
        - map:release(): releases all gpu resources loaded by the map
        - map:draw()
        - map:getTileInfo(globalId): returns a table containing tile info, like
                                     the tile's tileset and local IDs.
        - map:getLayerByName(layerName)
        - map:getLayersByClass(class)
        - map:getBackgroundColor(): returns 4 numbers corresponding to r,g,b,a
          values to pass into love.graphics.setBackgroundColor
    
    layers
    ----
    these are the fields available in layer objects:
        - layer.type: a string
        - layer.name
        - layer.class: user-given layer class
        - layer.visible
        - layer.id
        - layer.opacity
        - layer.offsetx
        - layer.offsety
        - layer.parallaxx
        - layer.parallaxy
        - layer.properties: custom property tabl
    
    tile layers have their layer.type set to "tilelayer", and have these
    methods:
        - layer:release(): releases all gpu resources needed to render the tile
                           layer. (this is called by map:release)
        - layer:get(x, y)
        - layer:getFlags(x, y)
        - layer:syncGraphics(): (re)creates the SpriteBatches used to draw the
                                TileLayer
        - layer:draw(): automatically calls syncGraphics if not loaded
        - layer:getTintColor(): returns four numbers corresponding to r,g,b,a
                                values to pass into love.graphics.setColor
        - layer:pushTransform()

    object layers have their layer.type set to "objectgroup".
    they have an extra field named "objects", which contains a list of all
    objects. they also have these methods:
        - layer:getObjectByName(name)
        - layer:getObjectByType(type)
    

    known limitations:
    ----
    
    - no infinite worlds
    - tile layer rendering renders the whole thing to a SpriteBatch,
      maybe chunk them and do frustum culling.
    - no image or group layers (yet)
    - only orthogonal maps
    - no zstd compression
    - only atlas tilesets, not "collection of images"
    - no background color
    - tile stretch mode not read

    - idk if it works with Worlds it probably does idk
    - i never tested it with autotiling


    copyright notice
    ----
    
    Copyright (c) 2025 pkhead

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

local module_root = (...):gsub("%.init$", "")

local bit = require(module_root .. ".bitcompat")
local Path = require(module_root .. ".path")
local readBase64 = require(module_root .. ".base64")
local table_new = require(module_root .. ".tablecompat").new

local tiled = {}
tiled._version = "0.2.1"

---@class pklove.tiled.Layer
---@field type string
---@field name string
---@field class string
---@field visible boolean
---@field id integer
---@field opacity number
---@field offsetx number
---@field offsety number
---@field parallaxx number
---@field parallaxy number
---@field tintcolor number[]?
---@field properties table
---@field draw fun(self:pklove.tiled.Layer)
local Layer = {}
Layer.__index = Layer

---@class pklove.tiled.Tileset
---@field name string
---@field filename string? nil if this is an embedded tileset
---@field firstgid integer
---@field class string
---@field tilewidth integer
---@field tileheight integer
---@field spacing integer
---@field margin integer
---@field columns integer
---@field image string
---@field imagewidth integer
---@field imageheight integer
---@field objectalignment string
---@field tilerendersize string
---@field fillmode string
---@field tileoffset {x: integer, y: integer}
---@field grid {orientation: string, width: integer, height: integer}
---@field properties table
---@field wangsets table
---@field tilecount integer
---@field tiles table

---@class pklove.tiled.Tile
---@field textureId integer
---@field tilesetId integer
---@field id integer
---@field quad love.Quad

---@class pklove.tiled.Map
---@field class string
---@field orientation string
---@field renderorder string
---@field width integer
---@field height integer
---@field tilewidth integer
---@field tileheight integer
---@field backgroundcolor number[]
---@field tilesets pklove.tiled.Tileset[]
---@field layers pklove.tiled.Layer[]
---@field textures love.Image[]
---@field properties table
---@field _globalTiles pklove.tiled.Tile[]
---@field package _textureLoadCache {[string]: love.Image}?
local Map = {}
Map.__index = Map

---@class pklove.tiled.TileLayer: pklove.tiled.Layer
---@field width integer
---@field height integer
---@field encoding string
---@field data integer[]
---@field _drawBatches love.SpriteBatch[]?
---@field _map pklove.tiled.Map
local TileLayer = setmetatable({}, Layer)
TileLayer.__index = TileLayer

---@alias pklove.tiled.Object table

---@class pklove.tiled.ObjectLayer: pklove.tiled.Layer
---@field objects pklove.tiled.Object[]
local ObjectLayer = setmetatable({}, Layer)
ObjectLayer.__index = ObjectLayer

---@class pklove.tiled.ImageLayer: pklove.tiled.Layer
---@field repeatx boolean
---@field repeaty boolean
---@field image string
local ImageLayer = setmetatable({}, Layer)
ImageLayer.__index = ImageLayer

---@class pklove.tiled.GroupLayer: pklove.tiled.Layer
---@field layers pklove.tiled.Layer[]
local GroupLayer = setmetatable({}, Layer)
GroupLayer.__index = GroupLayer

---@class pklove.tiled.LoadSettings
---@field loadTexture ?fun(path:string):love.Image Function for loading textures. Loaded textures may be cached. They are not released when the Map is released.

local function tfind(t, v)
    for i, _v in pairs(t) do
        if v == _v then
            return i
        end
    end

    return nil
end

---User-provided function to map a relative path defined in a .tmx or .tsx
---export to a useable and normalized path for loading.
---@type (fun(cwd:string, path:string):string)|nil
tiled.mapPath = nil

local function defaultMapPath(cwd, path)
    return Path.normalize(Path.join(cwd, path))
end

---@param fileDir string
---@param map pklove.tiled.Map
---@param tileset pklove.tiled.Tileset
---@param loadSettings pklove.tiled.LoadSettings
local function loadTileset(fileDir, map, tileset, loadSettings)
    local globalTiles = map._globalTiles
    local loadedTextures = map.textures

    local texPath = (tiled.mapPath or defaultMapPath)(fileDir, tileset.image)
    local texture = loadSettings.loadTexture(texPath)

    local tilesetIndex = assert( tfind(map.tilesets, tileset) )
    local textureIndex = tfind(loadedTextures, texture)
    if textureIndex == nil then
        table.insert(loadedTextures, texture)
        textureIndex = #loadedTextures
    end

    local rowCount = tileset.tilecount / tileset.columns

    local localId = 1
    for row=1, rowCount do
        local y = tileset.margin + (tileset.tileheight + tileset.spacing) * (row - 1)
        for col=1, tileset.columns do
            local x = tileset.margin + (tileset.tilewidth + tileset.spacing) * (col - 1)

            local q = love.graphics.newQuad(x, y, tileset.tilewidth, tileset.tileheight, texture)
            table.insert(globalTiles, {
                textureId = textureIndex,
                tilesetId = tilesetIndex,
                id = localId,
                quad = q
            })
            localId = localId + 1
        end
    end
    
    assert(localId - 1 == tileset.tilecount)
end

local function parseTileData(tileLayer)
    if tileLayer.encoding == "lua" then
        -- nothing needs to be done here
    
    elseif tileLayer.encoding == "base64" then
        local mapData = readBase64(tileLayer.data)

        if tileLayer.compression ~= nil then
            if tileLayer.compression ~= "gzip" and tileLayer.compression ~= "zlib" then
                error(("incompatible tile layer compression format: %s"):format(tileLayer.compression))
            end

            mapData = love.data.decompress("string", tileLayer.compression, mapData) --[[@as string]]
        end

        local size = tileLayer.width * tileLayer.height
        assert(string.len(mapData) == size * 4, "invalid tile layer data")

        local dat ---@type integer[]
        dat = table_new(size, 0)

        local offset = 1
        for i=1, size do
            dat[i] = love.data.unpack("<I4", mapData, offset) --[[@as integer]]
            offset = offset + 4
        end

        tileLayer.data = dat
    
    else
        error("unknown tile layer encoding:" .. tostring(tileLayer.compression))
    end
end

---@param map pklove.tiled.Map
---@param layerList pklove.tiled.Layer[]
local function assignLayerMts(map, layerList)
    for _, layer in pairs(layerList) do
        if layer.type == "tilelayer" then
            ---@cast layer pklove.tiled.TileLayer
            setmetatable(layer, TileLayer)
            parseTileData(layer)
            layer._map = map
        elseif layer.type == "objectgroup" then
            setmetatable(layer, ObjectLayer)
        elseif layer.type == "imagelayer" then
            setmetatable(layer, ImageLayer)
        elseif layer.type == "group" then
            ---@cast layer pklove.tiled.GroupLayer
            setmetatable(layer, GroupLayer)
            assignLayerMts(map, layer.layers)
        else
            print(("warning: unknown layer type '%s'"):format(layer.type))
            setmetatable(layer, Layer)
        end
    end
end

---Load a lua-exported map from a given path
---@param mapPath string The path to the lua-exported map.
---@param loadSettings pklove.tiled.LoadSettings? Settings to use when loading the map
---@return pklove.tiled.Map
function tiled.loadMap(mapPath, loadSettings)
    if loadSettings == nil then
        loadSettings = {}
    end

    local map = love.filesystem.load(mapPath)()
    ---@cast map pklove.tiled.Map
    setmetatable(map, Map)

    -- use default loadTexture function if not user-provided
    if loadSettings.loadTexture == nil then
        map._textureLoadCache = {}

        ---@param texturePath string
        function loadSettings.loadTexture(texturePath)
            local texture = map._textureLoadCache[texturePath]
            if texture == nil then
                texture = love.graphics.newImage(texturePath)
                map._textureLoadCache[texturePath] = texture
            end
            return texture
        end
    end

    map._globalTiles = {}
    map.textures = {}

    -- load the tilesets
    local funcMapPath = tiled.mapPath or defaultMapPath
    local mapBaseDir = Path.getDirName(mapPath) --[[@as string]]
    for i, tilesetDecl in ipairs(map.tilesets) do
        if tilesetDecl.filename ~= nil then
            local path = funcMapPath(mapBaseDir, tilesetDecl.filename)
            local tileset = love.filesystem.load(path)()
            tileset.firstgid = tilesetDecl.firstgid
            
            -- replace embedded tileset in map data with actual loaded tileset
            map.tilesets[i] = tileset
            tileset.filename = tilesetDecl.filename

            local dirname = Path.getDirName(path) --[[@as string]]
            loadTileset(dirname, map, tileset, loadSettings)
        else
            -- embedded
            loadTileset(mapBaseDir, map, tilesetDecl, loadSettings)
        end
    end

    -- assign metatables to each layer
    assignLayerMts(map, map.layers)

    return map
end

local function sortRenderList(a, b)
    return a.t.tilesetId < b.t.tilesetId
end

-- tile gid flags
local FLIPPED_HORIZONTALLY_FLAG  = 0x80000000
local FLIPPED_VERTICALLY_FLAG    = 0x40000000
local FLIPPED_DIAGONALLY_FLAG    = 0x20000000
local ROTATED_HEXAGONAL_120_FLAG = 0x10000000
local ALL_TILE_FLAGS = bit.bor(FLIPPED_HORIZONTALLY_FLAG, FLIPPED_VERTICALLY_FLAG, FLIPPED_DIAGONALLY_FLAG, ROTATED_HEXAGONAL_120_FLAG)

---@param map pklove.tiled.Map
---@param tileLayer pklove.tiled.TileLayer
---@return love.SpriteBatch[]
local function renderTileLayer(map, tileLayer)
    local data = tileLayer.data

    ---@type {x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, t: pklove.tiled.Tile}[]
    local renderList = {}

    local dataIndex = 1
    for y=0, tileLayer.height - 1 do
        for x=0, tileLayer.width - 1 do
            local tileId = data[dataIndex]
            if tileId ~= 0 then
                local hFlip = bit.band(tileId, FLIPPED_HORIZONTALLY_FLAG) ~= 0
                local vFlip = bit.band(tileId, FLIPPED_VERTICALLY_FLAG) ~= 0
                local dFlip = bit.band(tileId, FLIPPED_DIAGONALLY_FLAG) ~= 0
                local hRot = bit.band(tileId, ROTATED_HEXAGONAL_120_FLAG) ~= 0
    
                tileId = bit.band(tileId, bit.bnot(ALL_TILE_FLAGS))

                local tile = map._globalTiles[tileId]
                local tileset = map.tilesets[tile.tilesetId]

                local drawX = (x+0.5) * map.tilewidth
                local drawY = (y+1) * map.tileheight - tileset.tileheight + map.tileheight / 2
                local sx, sy = 1, 1

                if dFlip then
                    sx = -sx
                end

                if hFlip then
                    sx = -sx
                end

                if vFlip then
                    sy = -sy
                end

                table.insert(renderList, {
                    x = drawX,
                    y = drawY,
                    r = dFlip and math.pi / 2 or 0,
                    sx = dFlip and sy or sx,
                    sy = dFlip and sx or sy,
                    ox = tileset.tilewidth / 2,
                    oy = tileset.tileheight / 2,

                    t = tile
                })
            end

            dataIndex=dataIndex+1
        end
    end

    table.sort(renderList, sortRenderList)

    local batches = {}

    local start = 1
    local end_ = 1
    while end_ <= #renderList do
        local texId = renderList[start].t.textureId
        while end_ <= #renderList and texId == renderList[end_].t.textureId do
            end_ = end_ + 1
        end

        local batch = love.graphics.newSpriteBatch(map.textures[texId], end_ - start, "static")
        table.insert(batches, batch)

        for i=start, end_ - 1 do
            local t = renderList[i]
            batch:add(t.t.quad, t.x, t.y, t.r, t.sx, t.sy, t.ox, t.oy)
        end

        start = end_
        end_ = start
    end

    return batches
end

---Obtain the 2x2 representation of the graphics transform matrix as well as its translation
---@return number e1_1
---@return number e1_2
---@return number e2_1
---@return number e2_2
---@return number tx
---@return number ty
local function getGraphics2x2Matrix()
    local tx, ty = love.graphics.transformPoint(0, 0)
    local sxx, sxy = love.graphics.transformPoint(1, 0)
    sxx = sxx - tx
    sxy = sxy - ty
    local syx, syy = love.graphics.transformPoint(0, 1)
    syx = syx - tx
    syy = syy - ty

    return sxx, syx, sxy, syy, tx, ty
end

---@param map pklove.tiled.Map
---@param tileLayer pklove.tiled.TileLayer
local function drawTileLayer(map, tileLayer)
    if not tileLayer.visible then return end

    if tileLayer._drawBatches == nil then
        tileLayer:syncGraphics()
    end

    tileLayer:pushTransform()

    -- apply tint color
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    love.graphics.setColor(tileLayer:getTintColor())

    -- draw the tile layer!
    for _, batch in ipairs(tileLayer._drawBatches) do
        love.graphics.draw(batch, 0, 0)
    end

    love.graphics.setColor(oldR, oldG, oldB, oldA)

    love.graphics.pop()
end

function Map:release()
    for _, layer in ipairs(self.layers) do
        if layer.type == "tilelayer" then
            ---@cast layer pklove.tiled.TileLayer
            layer:release()
        end
    end

    -- for _, tex in ipairs(self._loadedTextures) do
    --     tex:release()
    -- end
    self.textures = nil

    for _, t in ipairs(self._globalTiles) do
        t.quad:release()
    end
    self._globalTiles = nil

    if self._textureLoadCache then
        for _, tex in pairs(self._textureLoadCache) do
            tex:release()
        end
        self._textureLoadCache = nil
    end
end

-- ---Draw a given tile layer owned by the map.
-- ---@param tileLayer pklove.tiled.TileLayer The tile layer to draw.
-- function Map:drawTileLayer(tileLayer)
--     drawTileLayer(self, tileLayer)
-- end

---Draw each layer. Do note that parallax does work with love's graphics transformation state.
---@param x number? X position to draw the map. Defaults to 0.
---@param y number? Y position to draw the map. Defaults to 0.
---@param sx number? X scaling factor. Defaults to 1.
---@param sy number? Y scaling factor. Defaults to 1.
function Map:draw(x, y, sx, sy)
    x = x or 0
    y = y or 0
    sx = sx or 1
    sy = sy or 1

    love.graphics.push("transform")
    love.graphics.translate(x, y)
    love.graphics.scale(sx, sy)

    for _, layer in ipairs(self.layers) do
        layer:draw()
    end

    love.graphics.pop()
end

---Returns true if the map has a set background color.
function Map:hasBackgroundColor()
    return self.backgroundcolor ~= nil
end

---Returns the tint color of the layer.
---@return number r Red component in the range [0, 1].
---@return number g Green component in the range [0, 1].
---@return number b Blue component in the range [0, 1].
---@return number a Alpha component in the range [0, 1],
function Map:getBackgroundColor()
    if self.backgroundcolor == nil then
        return 0, 0, 0, 0
    end

    local r, g, b =
        self.backgroundcolor[1] / 255,
        self.backgroundcolor[2] / 255,
        self.backgroundcolor[3] / 255

    local a
    if self.backgroundcolor[4] == nil then
        a = 1
    else
        a = self.backgroundcolor[4] / 255
    end

    return r, g, b, a
end

---Get a layer by name.
---@param name string The name of the requested layer.
---@return pklove.tiled.Layer? layer The layer, or nil if not found.
function Map:getLayerByName(name)
    for _, layer in ipairs(self.layers) do
        if layer.name == name then
            return layer
        end
    end

    return nil
end

---Get a list of layers from their class name.
---@param class string The class name to search.
---@return pklove.tiled.Layer[] layers The list of layers.
function Map:getLayersByClass(class)
    local out = {}
    for _, obj in ipairs(self.layers) do
        if obj.class == class then
            out[#out+1] = obj
        end
    end
    return out
end

---Get info of a tile from global ID
---@param globalId integer The global ID of a tile.
---@return pklove.tiled.Tile tile Tile information.
function Map:getTileInfo(globalId)
    return self._globalTiles[globalId]
end

do
    local tempTransform = love.math.newTransform()

    ---Push layer transform properties to love's transform stack.
    function Layer:pushTransform()
        love.graphics.push()

        local useParallax = not (self.parallaxx == 1 and self.parallaxy == 1)
        if useParallax then
            local cx = love.graphics.getWidth() / 2
            local cy = love.graphics.getHeight() / 2

            local m00, m01, m10, m11, tx, ty = getGraphics2x2Matrix()
            tx = (tx - cx) * self.parallaxx + cx
            ty = (ty - cy) * self.parallaxy + cy

            tempTransform:setMatrix(
                m00, m01, 0, tx,
                m10, m11, 0, ty,
                0,   0,   1, 0,
                0,   0,   0, 1
            )

            love.graphics.origin()
            love.graphics.applyTransform(tempTransform)
        end

        love.graphics.translate(self.offsetx, self.offsety)
    end
end

---Returns the tint color of the layer.
---@return number r Red component in the range [0, 1].
---@return number g Green component in the range [0, 1].
---@return number b Blue component in the range [0, 1].
---@return number a Alpha component in the range [0, 1],
function Layer:getTintColor()
    if self.tintcolor == nil then
        return 1, 1, 1, 1
    end

    local r, g, b =
        self.tintcolor[1] / 255,
        self.tintcolor[2] / 255,
        self.tintcolor[3] / 255

    local a
    if self.tintcolor[4] == nil then
        a = 1
    else
        a = self.tintcolor[4] / 255
    end

    return r, g, b, a
end

---Get an object by name.
---@param name string The name of the requested object.
---@return pklove.tiled.Object? layer The object, or nil if not found.
function ObjectLayer:getObjectByName(name)
    for _, obj in ipairs(self.objects) do
        if obj.name == name then
            return obj
        end
    end

    return nil
end

---Get a list of objects from their class/type name.
---@param type string The type name to search.
---@return pklove.tiled.Object[] objects The list of objects.
function ObjectLayer:getObjectsByType(type)
    local out = {}
    for _, obj in ipairs(self.objects) do
        if obj.type == type then
            out[#out+1] = obj
        end
    end
    return out
end

function ObjectLayer:draw()
    -- no-op
end

---Releases resources associated with rendering this tile layer.
function TileLayer:release()
    if self._drawBatches then
        for _, batch in ipairs(self._drawBatches) do
            batch:release()
        end
        self._drawBatches = nil
    end
end

---Get a tile.
---@param x integer The X position of the tile, starting from 0.
---@param y integer The Y position of the tile, starting from 0.
---@return integer|nil tile The global ID of the tile, or nil if out of bounds.
function TileLayer:get(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return nil
    end
    
    local i = y * self.width + x
    local tileId = self.data[i + 1]
    tileId = bit.band(tileId, bit.bnot(ALL_TILE_FLAGS))

    return tileId
end

---Get the flags of a tile.
---@param x integer The X position of the tile, starting from 0.
---@param y integer The Y position of the tile, starting from 0.
---@return boolean hFlip, boolean vFlip, boolean dFlip, boolean hRot
function TileLayer:getFlags(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return false, false, false, false
    end
    
    local i = y * self.width + x
    local tileId = self.data[i + 1]
    
    local hFlip = bit.band(tileId, FLIPPED_HORIZONTALLY_FLAG) ~= 0
    local vFlip = bit.band(tileId, FLIPPED_VERTICALLY_FLAG) ~= 0
    local dFlip = bit.band(tileId, FLIPPED_DIAGONALLY_FLAG) ~= 0
    local hRot = bit.band(tileId, ROTATED_HEXAGONAL_120_FLAG) ~= 0
    
    return hFlip, vFlip, dFlip, hRot
end

---Load/reload the internal SpriteBatches used to draw the TileLayer.
function TileLayer:syncGraphics()
    if self._drawBatches then
        for _, batch in ipairs(self._drawBatches) do
            batch:release()
        end
    end

    self._drawBatches = renderTileLayer(self._map, self)
end

---Draw the tile layer.
function TileLayer:draw()
    drawTileLayer(self._map, self)
end

---Draw the group layer.
function GroupLayer:draw()
    self:pushTransform()
    for _, layer in ipairs(self.layers) do
        layer:draw()
    end
    love.graphics.pop()
end

---Draw the image layer.
function ImageLayer:draw()
    --error("ImageLayer draw not yet implemented")
end

return tiled
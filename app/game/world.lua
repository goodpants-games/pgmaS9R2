local Tiled = require("tiled")
local Input = require("input")
local Consts = require("game.consts")
local Collision = require("game.collision")
local Util = require("game.util")
local EnemyConductor = require("game.enemy_conductor")
local Camera = require("game.camera")

local TILE_SIZE = Consts.TILE_SIZE
local BUTTON_INPUTS = {"left", "right", "down", "up", "fire", "interact", "camSwitch"}
local ENTITY_RENDER_TAG = "__gtag_render"
local ENTITY_POINTCOL = "__gtag_pointCol"
local ENTITY_OLDX = "__g_oldX"
local ENTITY_OLDY = "__g_oldY"

---@class game.World: batteries.Class
---@overload fun():game.World
local World = batteries.class()

function World:new()
    self.map = nil ---@type pklove.tiled.Map
    self.curFrame = 0

    self._nonCollidableTiles = {}
    self._wallTiles = {}
    
    -- store button input states for the current and last frame
    -- self.buttonInputs[1] = current frame  (updated in rawUpdate)
    -- self.buttonInputs[2] = previous frame
    self.buttonInputs = {}
    for i=1, 2 do
        local t = {}
        for _, v in pairs(BUTTON_INPUTS) do
            t[v] = false
        end
        self.buttonInputs[i] = t
    end

    self.camX = 0.0
    self.camY = 0.0
    self.mouseX = 0.0
    self.mouseY = 0.0

    ---@type game.Entity[]
    self.entities = {}
    ---@type game.Entity?
    self.player = nil

    self.mapWidth = 0
    self.mapHeight = 0
    self.colMap = {}
    self.aiFlags = {} ---@type integer[][]

    ---@private
    ---@type game.Entity[]
    self._renderOrder = {}

    ---@private
    ---@type game.Entity[]
    self._collisionEntities = {}
    
    ---@private
    self._needEntityRemoval = false
    self._didColMapChange = false

    local isCol = self.isCol
    ---@private
    self._getCol = function(tx, ty)
        return isCol(self, tx, ty)
    end

    self.msg = batteries.pubsub()

    self:reset("/res/maps/test.lua")
end

function World:update()
    Debug.draw:push()
    Debug.draw:translate(-math.round(self.camX), -math.round(self.camY))

    self.mouseX = App.mouseX + self.camX
    self.mouseY = App.mouseY + self.camY

    if self._didColMapChange then
        self._didColMapChange = false
        self.msg:publish("collisionMapChanged")
    end

    for _, ent in ipairs(self.entities) do
        if ent.update then
            ent:update()
        end
    end

    self:_collectColEnts()
    self:_moveEntities()
    self:_entityCollisions()
    self.camera:update()

    self:_flushEntRemovals()

    self.camX = math.round(self.camera.x) - App.scrW / 2
    self.camY = math.round(self.camera.y) - App.scrH / 2
    self.mouseX = App.mouseX + self.camX
    self.mouseY = App.mouseY + self.camY

    for _, ent in ipairs(self.entities) do
        if ent.postUpdate then
            ent:postUpdate()
        end
    end

    -- update render list
    for _, ent in ipairs(self.entities) do
        if ent.render then
            if not ent[ENTITY_RENDER_TAG] then
                ent[ENTITY_RENDER_TAG] = true
                table.insert(self._renderOrder, ent)
            end
        else
            if ent[ENTITY_RENDER_TAG] then
                ent[ENTITY_RENDER_TAG] = nil
                table.remove_value(self._renderOrder, ent)
            end
        end
    end
    self:_sortObjects()

    -- update death respawn timer
    if self._respawnTimer then
        self._respawnTimer = self._respawnTimer - 1
        if self._respawnTimer <= 0 then
            self._respawnTimer = nil
            self:reset()
        end
    end

    self.curFrame = self.curFrame + 1
    for _, btn in ipairs(BUTTON_INPUTS) do
        self.buttonInputs[2][btn] = self.buttonInputs[1][btn]
    end

    Debug.draw:pop()
end

function World:_sortObjects()
    local objList = self._renderOrder

    -- sort render list by z index
    table.sort(objList, function(a, b)
        return a.zIndex < b.zIndex
    end)

    -- sort sprites with equal zIndex by their Y position
    if objList[1] then
        local function yposLess(a, b)
            return a:getCenterY() < b:getCenterY()
        end
        local sort = batteries.sort._insertion_sort_impl
        local lastZIdx = objList[1].zIndex
        local lastIdx = 1
        local objCount = #objList

        for i=2, objCount do
            local obj = objList[i]
            if obj.zIndex ~= lastZIdx then
                sort(objList, lastIdx, i-1, yposLess)
                lastIdx = i
                lastZIdx = obj.zIndex
            end
        end
        
        if lastIdx ~= objCount then
            sort(objList, lastIdx, objCount, yposLess)
        end
    end
end

---@param overTilemapFilter boolean
function World:_drawObjects(overTilemapFilter)
    for _, ent in ipairs(self._renderOrder) do
        Util.drawEntity(ent, overTilemapFilter)
    end
end

function World:draw()
    Lg.setColor(batteries.colour.unpack_rgb(0x39afd6))
    Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)
    
    -- draw world
    Lg.push()
    Lg.translate(-math.round(self.camX), -math.round(self.camY))

    for _, layer in ipairs(self.map.layers) do
        -- draw objects immediately before top layer
        if layer.name == "__top" then
            self:_drawObjects(false)
        end

        layer:draw()
    end

    self:_drawObjects(true)

    Lg.pop()

    -- draw UI
    self.camera:drawUI()
end

---@param dt number
function World:rawUpdate(dt)
    local device = Input.players[1]

    for _, btn in ipairs(BUTTON_INPUTS) do
        self.buttonInputs[1][btn] = device:down(btn)
    end
end

function World:release()
    
end

---@param entType string
---@param x number
---@param y number
---@param ... any
---@return game.Entity?
function World:newEntity(entType, x, y, ...)
    return Util.newEntity(entType, x, y, ...)
end

---@param ent game.Entity
---@return boolean wasAdded
function World:addEntity(ent)
    if not table.index_of(self.entities, ent) then
        table.insert(self.entities, ent)
        ent.world = self
        ent.msg:publish("addedToWorld", ent)
        return true
    else
        return false
    end
end

---@param ent game.Entity
function World:removeEntity(ent)
    if ent.world == self then
        ent._removeOnFrameEnd = true
        self._needEntityRemoval = true
    end
end

---@param name string
---@return game.Entity?
function World:findEntityByName(name)
    for _, ent in ipairs(self.entities) do
        if ent.name == name then
            return ent
        end
    end

    return nil
end

---@param tag string
---@return game.Entity[]
function World:findEntitiesWithTag(tag)
    local res = {}
    for _, ent in ipairs(self.entities) do
        if ent:hasTag(tag) then
            table.insert(res, ent)
        end
    end
    return res
end

---Returns `true` if the tile at (x, y) is collidable, `nil` if out of bounds,
---or `false` otherwise.
---@param x integer
---@param y integer
---@return boolean?
function World:isCol(x, y)
    if x < 0 or y < 0 or x >= self.mapWidth or y >= self.mapHeight then
        return nil
    end

    return self.colMap[y+1][x+1] ~= 0
end

---@param x integer
---@param y integer
---@param n integer
function World:setCol(x, y, n)
    if x < 0 or y < 0 or x >= self.mapWidth or y >= self.mapHeight then
        return
    end

    self.colMap[y+1][x+1] = n
    self._didColMapChange = true
end

---@param btn string
---@return boolean
function World:isInputPressed(btn)
    return self.buttonInputs[1][btn] and not self.buttonInputs[2][btn]
end

---@param btn string
---@return boolean
function World:isInputReleased(btn)
    return not self.buttonInputs[1][btn] and self.buttonInputs[2][btn]
end

---@param btn string
---@return boolean
function World:isInputDown(btn)
    return self.buttonInputs[1][btn]
end

---Perform a tile-only raycast on the world. The length of the given direction
---vector dictates the maximum length the raycast will search for.
---@param x number X component of raycast origin.
---@param y number Y component of raycast origin.
---@param dx number X component of raycast direction.
---@param dy number Y component of raycast direction.
---@return number? distance, number? nx, number? ny
function World:tileRaycast(x, y, dx, dy)
    local resultDist, resultNx, resultNy

    local hd, hdx, hdy = Collision.tileRaycast(x, y, dx, dy, self._getCol)
    if hd then
        resultDist, resultNx, resultNy = hd, -hdx, -hdy
    end

    return resultDist, resultNx, resultNy
end

---Perform a raycast on the world. The length of the given direction vector
---dictates the maximum length the raycast will search for.
---@param x number X component of raycast origin.
---@param y number Y component of raycast origin.
---@param dx number X component of raycast direction.
---@param dy number Y component of raycast direction.
---@param colFlags integer? Collision group filter bitmask. If not given, nothing will be filtered.
---@return number? distance, number? nx, number? ny, game.entities.Enemy? entity
function World:raycast(x, y, dx, dy, colFlags)
    if not colFlags then
        colFlags = Consts.COLGROUP_ALL
    end

    local resultDist, resultNx, resultNy

    -- check collisions with tiles (the tilemap is on collision layer 1)
    if bit.band(colFlags, 0x1) ~= 0 then
        local hd, hdx, hdy = Collision.tileRaycast(x, y, dx, dy, self._getCol)
        if hd then
            resultDist, resultNx, resultNy = hd, -hdx, -hdy
        end
    end

    -- check collisions with entities
    for _, ent in ipairs(self.entities) do
        if ent.collision and bit.band(ent.colGroup, colFlags) ~= 0 then
            local hd, hnx, hny = Collision.rayRectIntersection(
                x, y, dx, dy,
                ent.x, ent.y, ent.width, ent.height
            )
            if hd and (not resultDist or hd < resultDist) then
                resultDist, resultNx, resultNy = hd, hnx, hny
            end
        end
    end

    return resultDist, resultNx, resultNy
end

---@param newMap string?
function World:reset(newMap)
    self:_clearEntities()

    if newMap then
        self.map = Tiled.loadMap(newMap)
        self:_loadMap()
    else
        self:_loadMapObjects()
    end

    self.enemyConductor = EnemyConductor(self)
    self.camera = Camera(self)

    self._respawnTimer = nil ---@type integer?

    self.player.msg:subscribe("died", function()
        print("start respawn timer")
        self._respawnTimer = 60
    end)
end

--------------------------------------------------------------------------------

function World:_loadMap()
    -- load tileset data
    table.clear(self._wallTiles)
    table.clear(self._nonCollidableTiles)

    local aiFlagsTileset = nil ---@type pklove.tiled.Tileset

    for _, tileset in ipairs(self.map.tilesets) do
        if tileset.class ~= "meta" then
            local firstgid = tileset.firstgid
            for _, tile in ipairs(tileset.tiles) do
                local gid = firstgid + tile.id

                if tile.type == "top" or tile.type == "bg" then
                    self._nonCollidableTiles[gid] = true
                elseif tile.type == "wall" then
                    self._wallTiles[gid] = true
                end
            end
        elseif tileset.name == "ai_flags_tileset" then
            aiFlagsTileset = tileset
        end
    end

    local mapWidth, mapHeight = self.map.width, self.map.height
    self.mapWidth = mapWidth
    self.mapHeight = mapHeight

    -- load ai flags
    self.aiFlags = {}
    local aiFlagsLayer = self.map:getLayerByName("AIFlags") --[[@as pklove.tiled.TileLayer]]
    if aiFlagsLayer then
        local invalidTilesetErr = false
        
        for y=0, mapHeight-1 do
            local row = {}
            self.aiFlags[y+1] = row
            for x=0, mapWidth-1 do
                local gid = aiFlagsLayer:get(x, y)

                if gid and gid ~= 0 then
                    local tinfo = self.map:getTileInfo(gid)
                    local tset = self.map.tilesets[tinfo]
                    if tset == aiFlagsTileset then
                        row[x+1] = 0
                        invalidTilesetErr = true
                    else
                        row[x+1] = tinfo.id
                    end
                end
            end
        end

        if invalidTilesetErr then
            warn("ai flags layer had one or more tiles not from the AI flags tileset")
        end

        self.map:removeLayer(aiFlagsLayer)
    else
        for y=0, mapHeight-1 do
            local row = {}
            self.aiFlags[y+1] = row
            for x=0, mapWidth-1 do
                row[x+1] = 0
            end
        end
    end

    -- init collision map
    self.colMap = {}
    for y=1, self.mapHeight do
        local row = {}
        self.colMap[y] = row
        for x=1, self.mapWidth do
            row[x] = 0
        end
    end

    -- read tile layers
    local topLayer = self.map:createLayer("tilelayer", mapWidth, mapHeight) --[[@as pklove.tiled.TileLayer]]
    topLayer.name = "__top"

    for _, layer in ipairs(self.map.layers) do
        if layer.type ~= "tilelayer" then
            goto continue
        end
        ---@cast layer pklove.tiled.TileLayer
        if layer.name == "Background" or layer.class == "background" then
            goto continue
        end
        
        for y=1, mapHeight do
            local row = self.colMap[y]
            for x=1, mapWidth do
                local i = (y-1) * mapWidth + (x-1) + 1
                local cell = layer.data[i]
                local gid = bit.band(cell, 0x0fffffff)
                local isCol = gid ~= 0 and not self._nonCollidableTiles[gid]
                if isCol then
                    row[x] = 1
                end

                -- move "top" tiles to the top layer
                if gid ~= 0 and not self._wallTiles[gid] then
                    layer.data[i] = 0
                    topLayer.data[i] = cell
                end
            end
        end

        ::continue::
    end

    self.map:insertLayer(topLayer)

    -- initialize graphics
    for _, layer in self.map:iterLayers() do
        if layer.type == "tilelayer" then
            ---@cast layer pklove.tiled.TileLayer
            layer:syncGraphics()
        end
    end

    self:_loadMapObjects()
end

function World:_loadMapObjects()
    -- first pass: create entities
    local objects = {}
    for _, layer in ipairs(self.map.layers) do
        if layer.type == "objectgroup" then
            ---@cast layer pklove.tiled.ObjectLayer
            for _, obj in ipairs(layer.objects) do
                local ent ---@type game.Entity?
                local shape = obj.shape
                
                if shape == "rectangle" then
                    local cx = obj.x + obj.width / 2
                    local cy = obj.y + obj.height / 2

                    -- tile objects have their origin at the bottom-left instead of
                    -- the top-left. What the fuck?
                    if obj.gid then
                        cy = cy - obj.height
                    end

                    ent = self:newEntity(obj.type, cx, cy)
                
                elseif shape == "polyline" then
                    local poly = {
                        closed = false,
                        points = obj.polyline
                    }
                    ent = self:newEntity(obj.type, obj.x, obj.y, poly)

                elseif shape == "polygon" then
                    local poly = {
                        closed = true,
                        points = obj.polygon
                    }
                    ent = self:newEntity(obj.type, obj.x, obj.y, poly)
                
                else
                    warn(("object %i '%s': invalid object shape '%s'"):format(obj.id, obj.type, shape))
                end

                if not ent then
                    print("error: could not load entity")
                    goto continue
                end

                if obj.name then
                    ent.name = obj.name
                end

                table.insert(objects, { obj = obj, ent = ent })
                ::continue::
            end
        end
    end

    -- second pass: load properties
    -- loading is done in two passes because entities may reference each other
    local function entLookup(id)
        for _, entry in ipairs(objects) do
            if entry.obj.id == id then
                return entry.ent
            end
        end
    end

    for _, data in ipairs(objects) do
        local obj, ent = data.obj, data.ent

        if ent.loadProperties then
            ent:loadProperties(obj.id, obj.properties, entLookup)
        end
    end

    -- third pass: add each entity to the world
    for _, data in ipairs(objects) do
        self:addEntity(data.ent)
    end
end

function World:_clearEntities()
    for _, ent in ipairs(self.entities) do
        ent:remove()
    end

    self:_flushEntRemovals()
    self.player = nil
end

function World:_flushEntRemovals()
    while self._needEntityRemoval do
        self._needEntityRemoval = false

        for i=#self.entities, 1, -1 do
            local ent = self.entities[i]
            if ent._removeOnFrameEnd then
                ent._removeOnFrameEnd = false
                ent.msg:publish("removingFromWorld", ent)
                ent.world = nil

                if ent[ENTITY_RENDER_TAG] then
                    ent[ENTITY_RENDER_TAG] = nil
                    table.remove_value(self._renderOrder, ent)
                end
                table.remove(self.entities, i)
            end
        end
    end
end

function World:_collectColEnts()
    local colEnts = self._collisionEntities
    table.clear(colEnts)

    for _, ent in ipairs(self.entities) do
        if ent.collision then
            colEnts[#colEnts+1] = ent
            ent[ENTITY_OLDX] = ent.x
            ent[ENTITY_OLDY] = ent.y

            if ent.width == 0.0 and ent.height == 0.0 then
                ent[ENTITY_POINTCOL] = true
            else
                ent[ENTITY_POINTCOL] = nil
            end
        end
    end
end

function World:_moveEntities()
    local colEnts = self._collisionEntities

    -- first, move all X
    for _, ent in ipairs(self.entities) do
        ent.x = ent.x + ent.xVel
    end

    -- then, perform X collision
    for _, ent in ipairs(colEnts) do
        if ent.monitorOnly or ent[ENTITY_POINTCOL] then
            goto continue
        end
        if bit.band(ent.colMask, Consts.COLGROUP_DEFAULT) == 0 then
            goto continue
        end

        local oldX, oldY = ent[ENTITY_OLDX], ent[ENTITY_OLDY]
        local colX, _, colW, _, colEnt =
            Collision.gameCollision(ent.x, ent.y, oldX, oldY,
                                    ent.width, ent.height, self._getCol)
        if colX then
            local dir
            if ent.xVel > 0 then
                ent.x = colX - ent.width
                dir = -1
            else
                ent.x = colX + colW
                dir = 1
            end

            ent.xVel = ent.xVel * -ent.restitution

            ent.msg:publish("touched", ent, colEnt, dir, 0)
        end

        ::continue::
    end

    -- first, move all Y
    for _, ent in ipairs(self.entities) do
        ent.y = ent.y + ent.yVel
    end

    -- then, perform Y collision
    for _, ent in ipairs(colEnts) do
        if ent.monitorOnly or ent[ENTITY_POINTCOL] then
            goto continue
        end
        if bit.band(ent.colMask, Consts.COLGROUP_DEFAULT) == 0 then
            goto continue
        end

        local oldX, oldY = ent[ENTITY_OLDX], ent[ENTITY_OLDY]
        local _, colY, _, colH, colEnt =
            Collision.gameCollision(ent.x, ent.y, oldX, oldY,
                                    ent.width, ent.height, self._getCol)
        if colY then
            local dir
            if ent.yVel > 0 then
                ent.y = colY - ent.height
                dir = -1
            else
                ent.y = colY + colH
                dir = 1
            end

            ent.yVel = ent.yVel * -ent.restitution
            ent.msg:publish("touched", ent, colEnt, 0, dir)
        end

        ::continue::
    end

    -- point objects are handled specially, instead using continuous collision
    -- detection achieved via raycasts
    for _, ent in ipairs(colEnts) do
        if not ent[ENTITY_POINTCOL] then
            goto continue
        end

        local oldX, oldY = ent[ENTITY_OLDX], ent[ENTITY_OLDY]
        local oldTx = math.floor(oldX / TILE_SIZE)
        local oldTy = math.floor(oldY / TILE_SIZE)
        if self:isCol(oldTx, oldTy) then
            goto continue
        end

        local dx = ent.x - oldX
        local dy = ent.y - oldY
        local rd, rnx, rny =
            self:raycast(oldX, oldY, dx, dy, Consts.COLGROUP_DEFAULT)
        
        if rd then
            dx, dy = math.normalize(dx, dy)
            local hitX = oldX + dx * rd
            local hitY = oldY + dy * rd
            ent.x = hitX + rnx * 0.001
            ent.y = hitY + rny * 0.001

            -- reflect:
            -- v' = v - (1+R)(v ⋅ n)
            local dot = (ent.xVel * rnx + ent.yVel * rny) * (ent.restitution + 1.0)
            ent.xVel = ent.xVel - dot * rnx
            ent.yVel = ent.yVel - dot * rny

            ent.msg:publish("touched", ent, nil, rnx, rny)
        end

        ::continue::
    end
end

function World:_entityCollisions()
    local colEnts = self._collisionEntities

    -- collect entity contacts
    local contacts = {}
    for _, ent1 in ipairs(colEnts) do
        if ent1.touchMonitor then
            -- allocate tables if not exists
            ent1._touching = ent1._touching or {}
            ent1._prevTouching = ent1._prevTouching or {}

            -- set up prevTouching and touching lists for this frame
            table.clear(ent1._prevTouching)
            table.append_inplace(ent1._prevTouching, ent1._touching)
            table.clear(ent1._touching)

            local oldX1 = ent1[ENTITY_OLDX]
            local oldY1 = ent1[ENTITY_OLDY]

            if ent1[ENTITY_POINTCOL] then
                for _, ent2 in ipairs(colEnts) do
                    if ent1 == ent2 then
                        goto continue
                    end
                    if bit.band(ent1.colMask, ent2.colGroup) == 0 then
                        goto continue
                    end

                    -- calculate AABB containing both the object's old and new
                    -- position
                    local minX, minY
                    local maxX, maxY
                    local dx = ent1.x - oldX1
                    local dy = ent1.y - oldY1

                    if dx > 0 then
                        minX, maxX = oldX1, ent1.x
                    else
                        minX, maxX = ent1.x, oldX1
                    end

                    if dy > 0 then
                        minY, maxY = oldY1, ent1.y
                    else
                        minY, maxY = ent1.y, oldY1
                    end

                    -- optimization pass: ent2 cannot be colliding with ent1 if
                    -- ent2 is not within this AABB
                    local aabb_collide = Collision.rectRectCollision(
                        minX, minY, maxX, maxY,
                        ent2.x, ent2.y, ent2.width, ent2.height)
                    if not aabb_collide then
                        goto continue
                    end
                    
                    -- calculate line intersection
                    local cd, cnx, cny = Collision.rayRectIntersection(
                        oldX1, oldY1, dx, dy,
                        ent2.x, ent2.y, ent2.width, ent2.height)
                    
                    if cd and cd * cd < dx * dx + dy * dy then
                        local key = Util.upair2u(ent1.id, ent2.id)
                        if not contacts[key] then
                            contacts[key] = { ent1, ent2 }
                        end
                    end

                    ::continue::
                end
            else
                for _, ent2 in ipairs(colEnts) do
                    if ent1 == ent2 then
                        goto continue
                    end
                    if bit.band(ent1.colMask, ent2.colGroup) == 0 then
                        goto continue
                    end

                    local did_collide = Collision.rectRectCollision(
                        ent1.x, ent1.y, ent1.width, ent1.height,
                        ent2.x, ent2.y, ent2.width, ent2.height)
                    if did_collide then
                        local key = Util.upair2u(ent1.id, ent2.id)
                        if not contacts[key] then
                            contacts[key] = { ent1, ent2 }
                        end
                    end

                    ::continue::
                end
            end
        else
            ent1._touching = nil
            ent1._prevTouching = nil
        end
    end

    -- act on contacts
    for _, contact in pairs(contacts) do
        local ea, eb = contact[1], contact[2]

        if ea.touchMonitor then
            table.insert(ea._touching, eb)
        end
        if eb.touchMonitor then
            table.insert(eb._touching, ea)
        end
    end

    -- dispatch touching/touchEnded events
    for _, ent in ipairs(colEnts) do
        if ent.touchMonitor then
            for _, oent in ipairs(ent._touching) do
                if not table.index_of(ent._prevTouching, oent) then
                    ent.msg:publish("touched", ent, oent, 0, 0)
                end
            end

            for _, oent in ipairs(ent._prevTouching) do
                if not table.index_of(ent._touching, oent) then
                    ent.msg:publish("touchEnded", ent, oent, 0, 0)
                end
            end
        end
    end
end

return World
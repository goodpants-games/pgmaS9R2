local const = require("game.consts")
local Util = require("game.util")
local Pathfind = require("game.pathfind")

local TILE_SIZE = const.TILE_SIZE

---@class game.EnemyAi: batteries.Class
---@overload fun(world:game.World):game.EnemyAi
local EnemyAI = batteries.class()

--[[
enemy AI used for searching for the perpretator when another enemy is seen
being shot.

it will be aware of the bullet's direction of impact and the position of the
shot enemy. the enemy will then calculate which tiles of the map the player
could possibly be in using this information. then it will search all those tiles
using this process:

1. find the nearest unchecked tile
2. move towards this tile
3. while it is moving towards the tile, mark all tiles within the enemy's sight
   as checked.
4. once it has finished moving towards the tile, loop back to step 1.
5. if there are no more unchecked tiles, the algorithm is finished.
--]]

---@param world game.World
function EnemyAI:new(world)
    self.world = world

    -- 0: this is a solid tile
    -- 1: Not relevant
    -- 2: I did not check this tile
    -- 3: I already checked this tile
    self.mapAwareness = {}
    for y=1, world.mapHeight do
        local row = {}
        for x=1, world.mapWidth do
            row[x] = world:isCol(x-1, y-1) and 0 or 1
        end
        self.mapAwareness[y] = row
    end

    self._debugDraws = {}

    self.yield = function() end
end

local function tappend(t, ...)
    local tinsert = table.insert
    for i=1, select("#", ...) do
        tinsert(t, (select(i, ...)))
    end
end

local function tinsert3(t, x, y, z)
    table.insert(t, x)
    table.insert(t, y)
    table.insert(t, z)
end

---Returns a coroutine.wrap which plots a pixel for every pixel touching the 
---line segment between the points
---(lx1, ly1) and (lx2, ly2).
---@param lx1 integer
---@param ly1 integer
---@param lx2 integer
---@param ly2 integer
---@return fun():(number?, number?)
function EnemyAI:_plotLine(lx1, ly1, lx2, ly2)
return coroutine.wrap(function()
    local lineLen = math.distance(lx1, ly1, lx2, ly2)
    if lineLen == 0.0 then return end

    local lineDx, lineDy = math.normalize(lx2 - lx1, ly2 - ly1)

    local dir_sign_x = math.sign2(lineDx)
    local dir_sign_y = math.sign2(lineDy)
    local tile_offset_x = (lineDx >= 0.0) and 1 or 0
    local tile_offset_y = (lineDy >= 0.0) and 1 or 0

    local cur_x = lx1
    local cur_y = ly1
    local tile_x = math.floor(cur_x)
    local tile_y = math.floor(cur_y)
    
    local t = 0.0
    local dt = 0.0
    local dt_x = ((tile_x + tile_offset_x) - cur_x) / lineDx
    local dt_y = ((tile_y + tile_offset_y) - cur_y) / lineDy

    while t < lineLen do
        coroutine.yield(tile_x, tile_y)

        if dt_x < dt_y then
            tile_x = tile_x + dir_sign_x
            dt = dt_x
            t = t + dt
            dt_x = dt_x + dir_sign_x / lineDx - dt
            dt_y = dt_y - dt
        else
            tile_y = tile_y + dir_sign_y
            dt = dt_y
            t = t + dt
            dt_x = dt_x - dt
            dt_y = dt_y + dir_sign_y / lineDy - dt
        end
    end
end)
end

---Perform breadth-first search on neighboring tiles. Provide a callback
---function for each newly discovered tile. If this callback returns true, it
---will search the tiles around that tile. If false, it will not. If it returns
---the string "stop", the search will abort.
---@param origX number Tile X position
---@param origY number Tile Y position
---@param processTile fun(x:integer, y:integer, depth:integer):(boolean|"stop")
function EnemyAI:_searchTiles(origX, origY, processTile)
    local pair2u = Util.pair2u
    local tremove = table.remove

    ---@type number[]
    local frontier = { math.floor(origX), math.floor(origY), 0 }
    ---@type {[number]:boolean}
    local visited = {}

    while frontier[1] do
        for _=1, #frontier, 3 do
            local x     = tremove(frontier, 1)
            local y     = tremove(frontier, 1)
            local depth = tremove(frontier, 1)
            
            if self.mapAwareness[y+1][x+1] ~= 0 then
                local k = pair2u(x, y)
                if not visited[k] then
                    visited[k] = true
                    local status = processTile(x, y, depth)
                    if status == "stop" then
                        return
                    end

                    if status then
                        local nd = depth + 1
                        tinsert3(frontier, x+1, y, nd)
                        tinsert3(frontier, x-1, y, nd)
                        tinsert3(frontier, x, y-1, nd)
                        tinsert3(frontier, x, y+1, nd)
                    end
                end
            end
        end
    end
end

---Raycast on world, checking only the default collision group. Returns the
---point of intersection, or nil if no hit was found.
---@param x number
---@param y number
---@param dx number
---@param dy number
---@return number? xHit Tile X position of hit
---@return number? yHit Tile Y position of hit
---@return number? normalX
---@return number? normalY
function EnemyAI:_raycast(x, y, dx, dy)
    local dist, nx, ny = self.world:raycast(x, y, dx, dy, const.COLGROUP_DEFAULT)
    if dist then
        dx, dy = math.normalize(dx, dy)
        return x + dx * dist, y + dy * dist, nx, ny
    end
end

function EnemyAI:_debugDrawTileRect(x, y)
    self:_insDebugDraw("rectLines", x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
end

function EnemyAI:_insDebugDraw(f, ...)
    table.insert(self._debugDraws, { f, ... })
end

---@param myX number
---@param myY number
---@param victimX number
---@param victimY number
---@param bulletDx number
---@param bulletDy number
function EnemyAI:beginKillerSearch(myX, myY, victimX, victimY, bulletDx, bulletDy)
    --[[
    (victimX, victimY) is the position the victim was in. (bulletDx, bulletDy)
    is the velocity of the bullet.

    trace the path of the bullet from victim's position, accounting for bullet
    reflection. find the earliest tile within this path that is not within the
    perpretator's view. search all tiles from that point in that direction.
    --]]
    bulletDx, bulletDy = math.normalize(bulletDx, bulletDy)
    bulletDx, bulletDy = -bulletDx, -bulletDy

    local origX, origY = victimX, victimY

    while true do
        local hitX, hitY, normX, normY =
            self:_raycast(origX, origY, bulletDx * 1000, bulletDy * 1000)
        if not softassert(hitX) then
            return
        end

        local ofsHitX = hitX + normX * (TILE_SIZE/8)
        local ofsHitY = hitY + normY * (TILE_SIZE/8)

        local origTx = origX / TILE_SIZE
        local origTy = origY / TILE_SIZE
        local ofsHitTx = ofsHitX / TILE_SIZE
        local ofsHitTy = ofsHitY / TILE_SIZE
        for tx, ty in self:_plotLine(origTx, origTy, ofsHitTx, ofsHitTy) do
            local x = (tx + 0.5) * TILE_SIZE
            local y = (ty + 0.5) * TILE_SIZE

            if self:_raycast(myX, myY, x - myX, y - myY) then
                print(ofsHitTx, ofsHitTy)
                self:_insDebugDraw("color", 1, 1, 0)
                self:_insDebugDraw("rect", ofsHitX, ofsHitY, 8, 8)

                self:_insDebugDraw("color", 0, 1, 0)
                self:_debugDrawTileRect(tx, ty)

                -- now, search for tiles in the direction of the unknown.

                -- first, mark any tiles currently in sight as irrelevant.
                self:markTilesInSightOf(myX, myY, 3)

                -- then, find the closest obscured tile. this will be used for
                -- the origin point of the search
                local startX, startY
                self:_searchTiles(tx, ty, function(x, y, depth)
                    if depth >= 8 then
                        warn("obscured search did too much?")
                        return "stop"
                    end

                    if self.mapAwareness[y+1][x+1] ~= 3 then
                        startX, startY = x, y
                        return "stop"
                    end

                    return true
                end)
                if not startX then
                    return
                end

                -- finally, mark all tiles in the general vicinity as
                -- unexplored, not bothering to explore past any tiles that were
                -- in sight.
                local iter = 0
                self:_searchTiles(startX, startY, function(x, y, depth)
                    iter = iter + 1
                    if iter == 4 then
                        self.yield()
                        iter = 0
                    end

                    if self.mapAwareness[y+1][x+1] == 3 then
                        return false
                    end

                    if depth > 20 then
                        return false
                    end
                    self.mapAwareness[y+1][x+1] = 2
                    return true
                end)
                
                return
            end
        end

        -- reflect:
        -- v' = v - 2r(v ⋅ r)
        local dot = bulletDx * normX + bulletDy * normY
        bulletDx = bulletDx - 2 * normX * dot
        bulletDy = bulletDy - 2 * normY * dot

        origX = hitX + normX * 1
        origY = hitY + normY * 1

        self:_insDebugDraw("color", 1, 0, 1)
        self:_insDebugDraw("rect", origX, origY, 8, 8)
    end
end

function EnemyAI:beginChaseSearch(myX, myY, lastKnownX, lastKnownY)
    local lastKnownTx = math.floor(lastKnownX / TILE_SIZE)
    local lastKnownTy = math.floor(lastKnownY / TILE_SIZE)

    -- first, mark any tiles currently in sight as irrelevant.
    self:markTilesInSightOf(myX, myY, 3)

    -- then, find the closest obscured tile. this will be used for
    -- the origin point of the search
    self:_insDebugDraw("color", 0, 1, 0)
    self:_debugDrawTileRect(lastKnownTx, lastKnownTy)

    local startX, startY
    self:_searchTiles(lastKnownTx, lastKnownTy, function(x, y, depth)
        if depth >= 8 then
            warn("obscured search did too much?")
            return "stop"
        end

        if self.mapAwareness[y+1][x+1] ~= 3 then
            startX, startY = x, y
            return "stop"
        end

        return true
    end)
    if not startX then
        return
    end

    -- finally, mark all tiles in the general vicinity as
    -- unexplored, not bothering to explore past any tiles that were
    -- in sight.
    local iter = 0
    self:_searchTiles(startX, startY, function(x, y, depth)
        iter = iter + 1
        if iter == 4 then
            self.yield()
            iter = 0
        end

        -- if self.mapAwareness[y+1][x+1] == 3 then
        --     return false
        -- end

        if depth > 20 then
            return false
        end
        self.mapAwareness[y+1][x+1] = 2
        return true
    end)

    self:markTilesInSightOf(myX, myY, 1)
end

function EnemyAI:markTilesInSightOf(origX, origY, markId, limitPerFrame)
    limitPerFrame = limitPerFrame or math.huge
    --[[
        perform a breadth-first search of each tile starting from O (origin
        position).

        on each querying tile T, if a raycast between the center of tile T and
        O is obstructed, then do not process that tile.
    --]]
    local origTx = math.floor(origX / TILE_SIZE)
    local origTy = math.floor(origY / TILE_SIZE)

    local limitCount = 0
    self:_searchTiles(origTx, origTy, function(tx, ty)
        limitCount = limitCount + 1
        if limitCount == limitPerFrame then
            limitCount = 0
            self.yield()
        end

        local x = (tx + 0.5) * TILE_SIZE
        local y = (ty + 0.5) * TILE_SIZE
        local dx = origX - x
        local dy = origY - y
        local hit = self.world:tileRaycast(x, y, dx, dy)

        if hit then
            return false
        else
            self.mapAwareness[ty+1][tx+1] = markId
            return true
        end
    end)
end

---@class game.EnemyAI.SearchBehavior
---@field getPointOfInterest (fun(ent:game.entities.Entity):(x:number,y:number))?
---@field beginMove fun(ent:game.entities.Entity, x:number, y:number)
---@field isCurrentlyMoving fun(ent:game.entities.Entity):boolean

local function searchCoroSightCoro(self)
    self:markTilesInSightOf( coroutine.yield() )
end

---@param ent game.entities.Entity
---@param behavior game.EnemyAI.SearchBehavior
function EnemyAI:searchCoroutine(ent, behavior)
    local world = ent.world

    ---@type game.pathfind.ExtraParams
    local pathfindParams = {
        coroutineLimit = 20,
        cost = function(_,_, tx, ty)
            -- discourage going too close to walls, to make it seem more natural
            if world:isCol(tx-1, ty) or world:isCol(tx+1, ty) or
               world:isCol(tx, ty-1) or world:isCol(tx, ty+1)
            then
                return 3
            end

            return 1
        end
    }

    while true do
        local startTx = math.floor(ent:getCenterX() / TILE_SIZE)
        local startTy = math.floor(ent:getCenterY() / TILE_SIZE)

        local interestTx, interestTy
        if behavior.getPointOfInterest then
            local ix, iy = behavior.getPointOfInterest(ent)
            interestTx = math.floor(ix / TILE_SIZE)
            interestTy = math.floor(iy / TILE_SIZE)
        else
            interestTx, interestTy = startTx, startTy
        end

        -- find closest unexplored tile (id 2)
        local endTx, endTy

        local limitCounter = 0
        self:_searchTiles(interestTx, interestTy, function(x, y, depth)
            -- only process 40 tiles per frame
            limitCounter = limitCounter + 1
            if limitCounter == 40 then
                coroutine.yield()
                limitCounter = 0
            end

            if self.mapAwareness[y+1][x+1] == 2 then
                endTx, endTy = x, y
                return "stop"
            end
            return true
        end)

        if not endTx then
            print("no more unexplored tiles")
            break
        end

        print("calculate path...")
        -- find path from here to that tile
        local path = Pathfind.pathfind(ent.world, startTx, startTy, endTx, endTy, pathfindParams)
        if not path then
            softerror("could not find path?")
            return
        end
        Pathfind.simplifyPath(path, world)

        print("begin path traversal...")

        local sightCoro
        -- make entity traverse path
        for i=1, #path, 2 do
            local tx, ty = path[i], path[i+1]
            local x = (tx + 0.5) * TILE_SIZE
            local y = (ty + 0.5) * TILE_SIZE

            behavior.beginMove(ent, x, y)
            while behavior.isCurrentlyMoving(ent) do
                -- debug draw path
                for i=1, #path, 2 do
                    local tx, ty = path[i], path[i+1]
                    local x = (tx + 0.5) * TILE_SIZE
                    local y = (ty + 0.5) * TILE_SIZE
                    Debug.draw:color(0, 0, 0)
                    Debug.draw:rect(x, y, 4, 4)
                end

                -- mark any unexplored tiles currently in view as explored. but
                -- this is a coroutine so that it is limited to processing only
                -- 20 tiles per frame, because it is very expensive due to the
                -- raycasting.
                if not sightCoro then
                    sightCoro = coroutine.create(searchCoroSightCoro)
                    coroutine.sresume(sightCoro, self)
                    local stat = coroutine.sresume(sightCoro, ent.x, ent.y, 1, 20)
                    if not stat then
                        sightCoro = nil
                    end
                end
                if sightCoro then
                    if not coroutine.sresume(sightCoro) then
                        sightCoro = nil
                    end
                end

                coroutine.yield()
            end
        end
    end
end

function EnemyAI:fillAwareness(markId)
    local w = #self.mapAwareness[0]
    local h = #self.mapAwareness
    for y=1, h do
        local row = self.mapAwareness[y]
        for x=1, w do
            if row[x] ~= 0 then
                row[x] = markId
            end
        end
    end
end

function EnemyAI:update()
    for y=1, #self.mapAwareness do
        for x=1, #self.mapAwareness[1] do
            local cell = self.mapAwareness[y][x]
            if cell >= 2 then
                if cell == 2 then
                    Debug.draw:color(1, 0, 0)
                else
                    Debug.draw:color(0.5, 0, 0)
                end
                
                Debug.draw:rectLines((x-1) * TILE_SIZE, (y-1) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            end
        end
    end

    for _, call in ipairs(self._debugDraws) do
        Debug.draw[call[1]](Debug.draw, unpack(call, 2))
    end
end

return EnemyAI
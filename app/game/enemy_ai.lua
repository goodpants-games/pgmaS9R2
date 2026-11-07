local const = require("game.consts")
local Util = require("game.util")

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
    local map = world.colMap

    -- 0: this is a solid tile
    -- 1: Not relevant
    -- 2: I did not check this tile
    -- 3: I already checked this tile
    self.mapAwareness = {}
    for y=1, map.height do
        local row = {}
        for x=1, map.width do
            local t = assert( map:get(x-1, y-1) )
            row[x] = t ~= 0 and 0 or 1
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
---@param origX integer
---@param origY integer
---@param processTile fun(x:integer, y:integer, depth:integer):boolean
function EnemyAI:_searchTiles(origX, origY, processTile)
    local pair2u = Util.pair2u
    local tremove = table.remove

    ---@type number[]
    local frontier = { math.floor(origX), math.floor(origY), 0 }
    ---@type {[number]:boolean}
    local visited = {}

    -- for y=1, #self.mapAwareness do
    --     for x=1, #self.mapAwareness[1] do
    --         if self.mapAwareness[y][x] ~= 0 then
    --             processTile(x-1, y-1)
    --         end
    --     end
    -- end

    while frontier[1] do
        for _=1, #frontier, 3 do
            local x = tremove(frontier, 1)
            local y = tremove(frontier, 1)
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

function EnemyAI:_markTilesFromDirection(origX, origY, origDx, origDy, markId)
    --[[
        p = (origX, origY) is the position of the dead enemy.
        d = (origDx, origDy) is the direction of the bullet, as a normalized
        vector.

        obtain vector r, which is perpendicular to d. perform two raycasts
        c1 = <p, 1000r> and c2 = <p, p - 1000r> (c1 and c2 are the intersection
        points of the raycast). mark all tiles intersecting with the line
        segment <c1, c2> as "forbidden". then, perform a breadth-first fill
        from p, killing the processing of any tiles marked as "forbidden".
    --]]
    local planeOx = origX - origDx * 20
    local planeOy = origY - origDy * 20

    local r1x, r1y = self:_raycast(planeOx, planeOy, -origDy * 1000, origDx * 1000)
    local r2x, r2y = self:_raycast(planeOx, planeOy, origDy * 1000, -origDx * 1000)

    if not softassert(r1x or r1y) then
        return
    end
    if not softassert(r2x or r2y) then
        return
    end

    self:_insDebugDraw("color", 0, 0, 1)
    self:_insDebugDraw("line", r1x, r1y, r2x, r2y)

    local r1tx, r1ty = math.floor(r1x / TILE_SIZE), math.floor(r1y / TILE_SIZE)
    local r2tx, r2ty = math.floor(r2x / TILE_SIZE), math.floor(r2y / TILE_SIZE)

    ---@type {[integer]:boolean}
    local forbidden = {}
    
    ---@cast r1tx integer
    ---@cast r2tx integer
    ---@cast r1ty integer
    ---@cast r2ty integer
    for tx, ty in self:_plotLine(r1tx, r1ty, r2tx, r2ty) do
        forbidden[Util.pair2u(tx, ty)] = true
        self:_insDebugDraw("color", 1, 1, 1)
        print(tx, ty)
        self:_debugDrawTileRect(tx, ty)
    end

    local origTx = math.floor(origX / TILE_SIZE)
    local origTy = math.floor(origY / TILE_SIZE)

    forbidden[Util.pair2u(origTx, origTy)] = nil
    self:_searchTiles(origTx, origTy, function(x, y, depth)
        self.yield()
        if depth > 20 then
            return false
        end

        if forbidden[Util.pair2u(x, y)] then
            return false
        end
        self.mapAwareness[y+1][x+1] = markId
        return true
    end)
    --]]
end

function EnemyAI:beginKillerSearch(myself, victim, bulletDx, bulletDy)
    --[[
    (origX, origY) is the position the victim was in. (origDx, origDy) is the
    velocity of the bullet.

    trace the path of the bullet from (origX, origY), accounting for bullet
    reflection. find the earliest tile within this path that is not within the
    perpretator's view. search all tiles from that point in that direction.
    (self:_markTilesFromDirection)
    --]]
    bulletDx, bulletDy = math.normalize(bulletDx, bulletDy)
    bulletDx, bulletDy = -bulletDx, -bulletDy

    local origX, origY = victim.x, victim.y
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

            if self:_raycast(myself.x, myself.y, x - myself.x, y - myself.y) then
                print("Found one!!!!!!")
                -- table.insert(self._debugDraws, { x=math.floor(hx/TILE_SIZE), y=math.floor(hy/TILE_SIZE), r=1,g=0,b=1 })

                print(ofsHitTx, ofsHitTy)
                self:_insDebugDraw("color", 1, 1, 0)
                self:_insDebugDraw("rect", ofsHitX, ofsHitY, 8, 8)

                self:_insDebugDraw("color", 0, 1, 0)
                self:_debugDrawTileRect(tx, ty)

                -- now, search for tiles in the direction of the unknown.
                -- first, mark any tiles currently in sight as irrelevant. this
                -- will make it so the AI will explore in the direction the
                -- bullet came from
                self:markTilesInSightOf(myself.x, myself.y, 0)
                self:_searchTiles(tx, ty, function(x, y, depth)
                    self.yield()
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

    --[[
    local r1tx, r1ty = self:raycast(origX, origY, -origDy * 1000, origDx * 1000)
    local r2tx, r2ty = self:raycast(origX, origY, origDy * 1000, -origDx * 1000)

    if not softassert(r1tx or r1ty) then
        return
    end

    if not softassert(r2tx or r2ty) then
        return
    end

    ---@type {[integer]:boolean}
    local forbidden = {}
    
    ---@cast r1tx integer
    ---@cast r2tx integer
    ---@cast r1ty integer
    ---@cast r2ty integer
    self:_plotLine(r1tx, r1ty, r2tx, r2ty, function(tx, ty)
        forbidden[Util.pair2u(tx, ty)] = true
        table.insert(self._debugDraws, { x=tx, y=ty, r=1,g=1,b=1 })
    end)

    local origTx = math.floor(origX / TILE_SIZE)
    local origTy = math.floor(origY / TILE_SIZE)

    forbidden[Util.pair2u(origTx, origTy)] = nil
    self:_searchTiles(origTx, origTy, function(x, y, depth)
        if depth > 20 then
            return false
        end

        if forbidden[Util.pair2u(x, y)] then
            return false
        end
        self.mapAwareness[y+1][x+1] = markId
        return true
    end)
    --]]
end

function EnemyAI:markTilesInSightOf(origX, origY, markId)
    --[[
        perform a breadth-first search of each tile starting from O (origin
        position).

        on each querying tile T, if a raycast between the center of tile T and
        O is obstructed, then do not process that tile.
    --]]
    local origTx = math.floor(origX / TILE_SIZE)
    local origTy = math.floor(origY / TILE_SIZE)
    local colFlags = const.COLGROUP_DEFAULT

    self:_searchTiles(origTx, origTy, function(tx, ty)
        local x = (tx + 0.5) * TILE_SIZE
        local y = (ty + 0.5) * TILE_SIZE
        local dx = origX - x
        local dy = origY - y
        local hit = self.world:raycast(x, y, dx, dy, colFlags)

        if hit then
            return false
        else
            self.mapAwareness[ty+1][tx+1] = markId
            return true
        end
    end)
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
    Debug.draw:color(1, 0, 0)
    for y=1, #self.mapAwareness do
        for x=1, #self.mapAwareness[1] do
            if self.mapAwareness[y][x] >= 2 then
                Debug.draw:rectLines((x-1) * TILE_SIZE, (y-1) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            end
        end
    end

    for _, call in ipairs(self._debugDraws) do
        Debug.draw[call[1]](Debug.draw, unpack(call, 2))
    end
end

return EnemyAI
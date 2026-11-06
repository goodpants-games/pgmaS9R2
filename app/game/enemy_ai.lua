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
end

local function tinsert3(t, x, y, z)
    table.insert(t, x)
    table.insert(t, y)
    table.insert(t, z)
end

---Plot a pixel for every pixel touching the line segment between the points
---(lx1, ly1) and (lx2, ly2).
---@param lx1 integer
---@param ly1 integer
---@param lx2 integer
---@param ly2 integer
---@param plot fun(tx:integer, ty:integer)
function EnemyAI:_plotLine(lx1, ly1, lx2, ly2, plot)
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
        plot(tile_x, tile_y)

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
    local frontier = { origX, origY, 0 }
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
            local x, y, depth =
                tremove(frontier, 1), tremove(frontier, 1), tremove(frontier, 1)
            if self.mapAwareness[y+1][x+1] ~= 0 then
                assert(x >= 0) assert(y >= 0)
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
function EnemyAI:raycast(x, y, dx, dy)
    local dist, nx, ny = self.world:raycast(x, y, dx, dy, const.COLGROUP_DEFAULT)
    if dist then
        dx, dy = math.normalize(dx, dy)
        return
            math.floor((x + dx * dist - nx) / TILE_SIZE),
            math.floor((y + dy * dist - ny) / TILE_SIZE),
            nx, ny
    end
end

function EnemyAI:markTilesFromDirection(origX, origY, origDx, origDy, markId)
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

    for _, pos in ipairs(self._debugDraws) do
        Debug.draw:color(pos.r, pos.g, pos.b)
        Debug.draw:rectLines(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
    end
end

return EnemyAI
local const = require("game.consts")
local Util = require("game.util")

local TILE_SIZE = const.TILE_SIZE

---@class game.EnemyAI: batteries.Class
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

    -- 0: N/A: this is a solid tile
    -- 1: I did not check this tile
    -- 2: I already checked this tile
    self.mapAwareness = {}
    for y=1, map.height do
        local row = {}
        for x=1, map.width do
            local t = assert( map:get(x, y) )
            row[x] = 0
        end
        self.mapAwareness[y] = row
    end
end

local function tinsert2(t, x, y)
    table.insert(t, x)
    table.insert(t, y)
end

---@param lx1 integer
---@param ly1 integer
---@param lx2 integer
---@param ly2 integer
---@param process fun(tx:integer, ty:integer)
function EnemyAI:_line(lx1, ly1, lx2, ly2, process)
    local lineLen = math.distance(lx1, ly1, lx2, ly2)
    if lineLen == 0.0 then return end

    local lineDx, lineDy = math.normalize(lx2 - lx1, ly2 - ly1)

    local dir_sign_x = Util.sign2(lineDx)
    local dir_sign_y = Util.sign2(lineDy)
    local tile_offset_x = (lineDx >= 0.0) and 1 or 0
    local tile_offset_y = (lineDy >= 0.0) and 1 or 0

    local cur_x = lx1
    local cur_y = ly1
    local tile_x = math.floor(cur_x / TILE_SIZE)
    local tile_y = math.floor(cur_y / TILE_SIZE)
    
    local t = 0.0
    local dt = 0.0
    local dt_x = ((tile_x + tile_offset_x) * TILE_SIZE - cur_x) / lineDx
    local dt_y = ((tile_y + tile_offset_y) * TILE_SIZE - cur_y) / lineDy

    while t < lineLen do
        process(tile_x, tile_y)

        if dt_x < dt_y then
            tile_x = tile_x + dir_sign_x
            dt = dt_x
            t = t + dt
            dt_x = dt_x + dir_sign_x * TILE_SIZE / lineDx - dt
            dt_y = dt_y - dt
        else
            tile_y = tile_y + dir_sign_y
            dt = dt_y
            t = t + dt
            dt_x = dt_x - dt
            dt_y = dt_y + dir_sign_y * TILE_SIZE / lineDy - dt
        end
    end
end

---Perform breadth-first search on neighboring tiles. Provide a callback
---function for each newly discovered tile. If this callback returns true, it
---will search the tiles around that tile.
---@param origX integer
---@param origY integer
---@param processTile fun(x:integer, y:integer):boolean
function EnemyAI:searchTiles(origX, origY, processTile)
    local upair2u = Util.upair2u
    local tremove = table.remove

    ---@type number[]
    local frontier = { origX, origY }
    ---@type {[number]:boolean}
    local visited = {}

    while frontier[1] do
        for _=1, #frontier, 2 do
            local x, y = tremove(frontier, 1), tremove(frontier, 1)

            local k = upair2u(x, y)
            if not visited[k] then
                visited[k] = true
                if processTile(x, y) then
                    tinsert2(frontier, x+1, y)
                    tinsert2(frontier, x-1, y)
                    tinsert2(frontier, x, y-1)
                    tinsert2(frontier, x, y+1)
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
---@return number? xHit
---@return number? yHit
function EnemyAI:raycast(x, y, dx, dy)
    local dist = self.world:raycast(x, y, dx, dy, const.COLGROUP_DEFAULT)
    if dist then
        dx, dy = math.normalize(dx, dy)
        return x + dx * dist, y + dy * dist
    else
        return nil, nil
    end
end

function EnemyAI:markTilesFromDirection(origX, origY, origDx, origDy)
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
    local f1x, f1y = self:raycast(origX, origY, -origDy * 1000, origDx * 1000)
    local f2x, f2y = self:raycast(origX, origY, origDy * 1000, -origDx * 1000)
end

function EnemyAI:markTilesInSightOf(origX, origY, markId)
    --[[
        perform a breadth-first search of each tile starting from O (origin
        position).

        on each querying tile T, if a raycast between the center of tile T and
        O is obstructed, then do not process that tile.
    --]]
end

return EnemyAI
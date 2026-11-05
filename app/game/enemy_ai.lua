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
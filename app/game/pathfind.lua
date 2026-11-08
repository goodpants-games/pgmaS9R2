local Util = require "game.util"
local Pqueue = require "ds.priority_queue"

---@class game.pathfind.ExtraParams
---@field cost (fun(x1:integer, y1:integer, x2:integer, y2:integer):number)?
---@field heuristic (fun(x:integer, y:integer, goalX:integer, goalY:integer):number)?
---@field coroutineLimit integer? The limit for how many nodes are allowed to be processed before yielding the coroutine.

local Point = batteries.class()
batteries.make_pooled(Point, 256)
function Point:new(x, y)
    self.x = x
    self.y = y
end

local function costIdentity(x1, y1, x2, y2)
    return 1
end

-- manhattan distance to goal position
local function heuristicIdentity(x, y, goalX, goalY)
    return math.abs(goalX - x) + math.abs(goalY - y)
end

---@param world game.World
---@param startX integer Tile start X
---@param startY integer Tile start Y
---@param endX integer Tile end X
---@param endY integer Tile end Y
---@param extraParams game.pathfind.ExtraParams?
---@return integer[]?
local function pathfind(world, startX, startY, endX, endY, extraParams)
    extraParams = extraParams or {}

    local cost = extraParams.cost or costIdentity
    local heuristic = extraParams.heuristic or heuristicIdentity

    local pair2u = Util.pair2u
    local map = world.colMap

    local frontier = Pqueue("min")
    frontier:enqueue(Point:pooled(startX, startY), 0)

    ---@type {[number]:{x:number, y:number}}
    local cameFrom = {}
    ---@type {[number]:number}
    local costSoFar = {}
    costSoFar[pair2u(startX, startY)] = 0
    
    local function procNeighbor(x, y, curK, newX, newY)
        local newCost = costSoFar[curK] + cost(x, y, newX, newY)
        local newK = pair2u(newX, newY)
        if not costSoFar[newK] or newCost < costSoFar[newK] then
            costSoFar[newK] = newCost
            local priority = newCost + heuristic(newX, newY, endX, endY)
            frontier:enqueue(Point:pooled(newX, newY), priority)
            cameFrom[newK] = Point:pooled(x, y)
        end
    end

    local found = false
    local iters = 0
    local limitCounter = 0
    while not frontier:is_empty() do
        local point = frontier:dequeue()
        local x, y = point.x, point.y
        point:release()

        if x == endX and y == endY then
            found = true
            goto endSearch
        end
        
        if map:get(x, y) == 0 then
            local k = pair2u(x, y)
            procNeighbor(x,y,k, x+1, y)
            procNeighbor(x,y,k, x-1, y)
            procNeighbor(x,y,k, x,   y-1)
            procNeighbor(x,y,k, x,   y+1)
        end

        iters = iters + 1
        if iters > 10000000 then
            softerror("max iterations exceeded")
            break
        end

        if extraParams.coroutineLimit then
            limitCounter = limitCounter + 1
            if limitCounter == extraParams.coroutineLimit then
                coroutine.yield()
                limitCounter = 0
            end
        end
    end

    ::endSearch::
    if not found then
        return nil
    end

    -- trace back path, from end to start
    local out = {}
    local x, y = endX, endY
    while true do
        -- these are inserted in reverse because the list will be reversed
        -- before returning so that it will be ordered from start to end.
        table.insert(out, y)
        table.insert(out, x)

        if x == startX and y == startY then
            break
        end

        local p = cameFrom[pair2u(x, y)]
        if not softassert(p) then break end

        x, y = p.x, p.y
    end

    return table.reverse(out)
end

return {
    pathfind = pathfind
}
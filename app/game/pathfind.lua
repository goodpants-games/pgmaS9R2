local Util = require "game.util"
local Pqueue = require "ds.priority_queue"

local TILE_SIZE = require("game.consts").TILE_SIZE

local Point = batteries.class()
batteries.make_pooled(Point, 256)
function Point:new(x, y)
    self.x = x
    self.y = y
end

---@param world game.World
---@param startX integer Tile start X
---@param startY integer Tile start Y
---@param endX integer Tile end X
---@param endY integer Tile end Y
---@param extraParams table?
---@return integer[]?
local function pathfind(world, startX, startY, endX, endY, extraParams)
    extraParams = extraParams or {}
    local pair2u = Util.pair2u
    local tremove = table.remove
    local map = world.colMap

    local frontier = Pqueue("min")
    frontier:enqueue(Point:pooled(startX, startY), 0)

    ---@type {[number]:{x:number, y:number}}
    local cameFrom = {}
    ---@type {[number]:number}
    local costSoFar = {}
    costSoFar[pair2u(startX, startY)] = 0
    
    local function procNeighbor(x, y, curK, newX, newY)
        local newCost = costSoFar[curK] + --[[cost(x, y, newX, newY)]]0
        local newK = pair2u(newX, newY)
        if not costSoFar[newK] or newCost < costSoFar[newK] then
            costSoFar[newK] = newCost
            frontier:enqueue(Point:pooled(newX, newY), newCost)
            cameFrom[newK] = Point:pooled(x, y)
        end
    end

    local found = false
    local i = 0
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

        i = i + 1
        if i > 10000000 then
            softerror("max time exceeded")
            break
        end

        if extraParams.limit then
            limitCounter = limitCounter + 1
            if limitCounter == extraParams.limit then
                coroutine.yield()
                limitCounter = 0
            end
        end
    end

    ::endSearch::
    if not found then
        return nil
    end

    local out = {}
    local x, y = endX, endY
    while true do
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
local SpriteRenderer = require("game.util").SpriteRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")
local Util = require("game.util")
local EnemyAi = require "game.enemy_ai"
local Pathfinding = require "game.pathfind"
local Resmgr = require "game.resmgr"
local DirAnim = require "game.util.dir_anim"

local ALERT_MOVE_SPEED = 1.5
local PATROL_MOVE_SPEED = 0.8

---@class game.entities.Enemy: game.Entity
local Enemy = batteries.class {
    extends = require("game.entity")
}

function Enemy:new(x, y, w, h)
    self:super(x, y, w, h)
    self:addTag("enemy")

    self.collision = true
    self.colGroup = Const.COLGROUP_NPC
    self.moveSpeed = 1.5
    self.dead = false
    self.sawDisguise = false
    self.animState = nil ---@type string?
    self.faceDir = 0 -- in radians
    self.dirAnim = DirAnim()
    self.patrolPath = nil ---@type game.entities.NpcPath

    -- sight timer stuff --
    self.sightTimer = 0
    self.noticeWait = 20 -- how many frames until enemy actually notices/registers player
    self.alertNoticeWait = 8
    self.fireTimer = 0
    self.fireWait = 30 -- how frames after notice until enemy shoots player
    self.isAlert = false

    self.gunSight = Util.newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight.maxBounces = 1

    -- movement stuff --
    self._hasMoveTarget = false
    self._moveTargetX = 0
    self._moveTargetY = 0
    self._homeX = 0.0
    self._homeY = 0.0
    self._isTrackingPlayer = false

    -- ai stuff --
    ---@type game.EnemyAi?
    self.ai = nil

    self.aiBehavior = {
        chasePlayer = true,
        investigateKills = true,
    }

    self.msg:subscribe("addedToWorld", self._added)
    self.msg:subscribe("removingFromWorld", self._removing)
    self.msg:subscribe("hit", self._hit)
    self.msg:subscribe("witnessedDeath", self._witnessedDeath)

    self.aiTask = coroutine.create(function()
        return self:_patrolRoutine()
    end)
end

function Enemy:loadProperties(id, props, entLookup)
    local dir = Util.propCheck(props, "direction", "string", id, "enemy")
    if not dir then
        return
    end

    if dir == "right" then
        self.faceDir = 0
    elseif dir == "down" then
        self.faceDir = math.pi / 2
    elseif dir == "left" then
        self.faceDir = math.pi
    elseif dir == "up" then
        self.faceDir = 3 * math.pi / 2
    end

    if props.path then
        local pathId = Util.propCheck(props, "path", "object", id, "enemy")
        if not pathId then return end

        if pathId ~= 0 then
            local path = entLookup(pathId)
            if not path then
                warn("enemy.loadProperties: could not dereference object ID")
            end

            self.patrolPath = path --[[@as any]]
        end
    end
end

function Enemy:_added()
    self._homeX, self._homeY = self:getCenterPos()
end

function Enemy:_removing()
    self.gunSight:remove()
    self._sightCoro = nil
    self.ai:release()
    self.ai = nil
end

function Enemy:_hit(hitVx, hitVy)
    hitVx, hitVy = math.normalize(hitVx, hitVy)

    -- Die . Now.
    self.dead = true
    self.msg:unsubscribe("hit", self._hit)

    self.faceDir = math.atan2(hitVy, hitVx)
    self.xVel = hitVx * 3
    self.yVel = hitVy * 3
    self.zIndex = -10

    self.gunSight:remove()
    self.gunSight = nil

    self:publish("died")
    self:removeTag("enemy")

    self.world.enemyConductor:handleEnemyDeath(self, hitVx, hitVy)
end

function Enemy:_beginMove(x, y)
    self._moveTargetX = x - self.width / 2
    self._moveTargetY = y - self.height / 2
    self._hasMoveTarget = true
end

function Enemy:_isCurrentlyMoving()
    return self._hasMoveTarget
end

function Enemy:_endMove()
    self._hasMoveTarget = false
end

-- must be called within a coroutine...
function Enemy:_moveToHome()
    local startX, startY = self:getCenterPos()

    -- go to the nearest patrol path point
    local homeX, homeY = self._homeX, self._homeY
    if self.patrolPath then
        local minDist = math.huge
        for i=1, self.patrolPath:getPointCount() do
            local x, y = self.patrolPath:getPoint(i)
            local dist = math.distance(startX, startY, x, y)
            if dist < minDist then
                minDist = dist
                homeX, homeY = x, y
            end
        end
    end

    startX = math.floor(startX / Const.TILE_SIZE)
    startY = math.floor(startY / Const.TILE_SIZE)
    local endX = math.floor(homeX / Const.TILE_SIZE)
    local endY = math.floor(homeY / Const.TILE_SIZE)
    local path = Pathfinding.pathfind(self.world, startX, startY, endX, endY)
    if not path then
        softerror("could not create path?")
        return
    end
    Pathfinding.simplifyPath(path, self.world)

    -- follow path
    for i=3, #path, 2 do
        local tx, ty = path[i], path[i+1]
        local x = (tx + 0.5) * Const.TILE_SIZE
        local y = (ty + 0.5) * Const.TILE_SIZE

        self:_beginMove(x, y)
        while self:_isCurrentlyMoving() do
            coroutine.yield()
        end
    end

    self.isAlert = false
end

function Enemy:_witnessedDeath(victim, hitVx, hitVy, isPerpretator)
    if not isPerpretator then
        return
    end

    if self:hasSightLineTo(self.world.player) then
        return
    end

    self.ai = EnemyAi(self)
    self.ai:initMapAwareness()
    self.aiTask = coroutine.create(function()
        local myOrigX, myOrigY = self:getCenterPos()
        local victimOrigX, victimOrigY = victim:getCenterPos()

        -- first, wait a bit...
        for _=1, love.math.random(20, 40) do
            coroutine.yield()
        end

        -- then, move to victim...
        self.moveSpeed = ALERT_MOVE_SPEED
        self:_beginMove(victim.x, victim.y)
        while self:_isCurrentlyMoving() do
            coroutine.yield()
        end
        
        -- initialize search for the killer
        self.isAlert = true
        self.ai.yield = coroutine.yield
        self.ai:beginKillerSearch(myOrigX, myOrigY, victimOrigX, victimOrigY, hitVx, hitVy)

        local searchBehavior = {
            beginMove = self._beginMove,
            isCurrentlyMoving = self._isCurrentlyMoving,
            endMove = self._endMove,
        }
        local coro = coroutine.create(function()
            self.ai:searchCoroutine(self, searchBehavior)
        end)

        while true do
            if not coroutine.sresume(coro) then
                break
            end
            coroutine.yield()
        end

        -- search is done... return home.
        self.ai:release()
        self.ai = nil

        for _=1, 240 do
            coroutine.yield()
        end

        self:_moveToHome()
        return self:_patrolRoutine()
    end)
end

function Enemy:hasSightLineTo(oent)
    local cx, cy = self:getCenterPos()
    local ocx, ocy = oent:getCenterPos()
    local dx = ocx - cx
    local dy = ocy - cy

    local hit = not self.world:raycast(cx, cy, dx, dy, Const.COLGROUP_DEFAULT)
    return hit, dx, dy
end

function Enemy:update()
    local world = self.world
    if not world.player then
        return
    end

    local lastAnimState = self.animState
    self.animState = "idle"
    
    if self.dead then
        self.xVel = self.xVel * 0.9
        self.yVel = self.yVel * 0.9
        self.animState = "dead"
    else
        if self._hasMoveTarget then
            self.animState = "walk"
            
            local dx,dy = self._moveTargetX - self.x, self._moveTargetY - self.y
            if math.length(dx, dy) < self.moveSpeed then
                self._hasMoveTarget = false
            else
                dx, dy = math.normalize(dx, dy)
                self.faceDir = math.atan2(dy, dx)
                self.xVel = dx * self.moveSpeed
                self.yVel = dy * self.moveSpeed
            end
        else
            self.xVel = 0
            self.yVel = 0
        end

        -- update sight
        if not self._sightCoro then
            self._sightCoro = coroutine.create(self._sightRoutine)
            coroutine.sresume(self._sightCoro, self)
        end

        if not coroutine.sresume(self._sightCoro) then
            self._sightCoro = nil
        end

        if self.aiTask then
            if not coroutine.sresume(self.aiTask) then
                self.aiTask = nil
            end
        end

        -- update sight
        local player = world.player --[[@as game.entities.Player]]
        if player then
            if not player.dead then
                local hasSight, sightDx, sightDy = self:hasSightLineTo(player)
                if hasSight then
                    local timerSpeed = 1
                    if player.isDisguised and not self.sawDisguise then
                        local dist = math.length(sightDx, sightDy)
                        if dist > 16*8 then
                            timerSpeed = 1 / 12
                        elseif dist > 16*1 then
                            timerSpeed = 1 / 8
                        end
                    end

                    self.sightTimer = self.sightTimer + timerSpeed
                    goto done
                end
            end
            self.sightTimer = 0
            ::done::
        end
        -- self:_sightUpdate()

        if self.ai then
            self.ai:update()
        end
    end

    self:_updateAnimation(lastAnimState)
end

function Enemy:_sightRoutine()
    coroutine.yield()
    local world = assert(self.world)

    -- do nothing until enemy notices player
    self.sightTimer = 0
    while true do
        local noticeWait
        if self.isAlert then
            noticeWait = self.alertNoticeWait
        else
            noticeWait = self.noticeWait
        end

        if self.sightTimer >= noticeWait then break end
        coroutine.yield()
    end

    -- i see him!!
    if self.ai then
        self.ai:release()
        self.ai = nil
    end
    self.aiTask = nil

    self._hasMoveTarget = false
    self.xVel = 0.0
    self.yVel = 0.0
    self.world:addEntity(self.gunSight)
    self.fireTimer = 0

    local cx, cy
    local playerCx, playerCy
    local playerVx, playerVy
    while self.sightTimer > 0 do
        local player = self.world.player --[[@as game.entities.Player]]
        if player.isDisguised then
            self.sawDisguise = true
        end

        cx, cy = self:getCenterPos()
        playerCx, playerCy = world.player:getCenterPos()
        playerVx, playerVy = world.player.xVel, world.player.yVel

        local playerDx = playerCx - cx
        local playerDy = playerCy - cy
        if playerDx * playerDx + playerDy * playerDy ~= 0 then
            playerDx, playerDy = math.normalize(playerDx, playerDy)
        end

        self.gunSight:updateSight(cx, cy, playerDx, playerDy)
        self.faceDir = math.atan2(playerDy, playerDx)
        coroutine.yield()

        self.fireTimer = self.fireTimer + 1
        if self.fireTimer == self.fireWait then
            player:publish("hit", playerDx, playerDy)
        end
    end

    -- no longer in sight...
    for _=1, 5 do
        coroutine.yield()
    end

    if world.player.dead then
        for _=1, 120 do
            coroutine.yield()
        end
    end

    self.gunSight:remove()

    if not self.aiBehavior.chasePlayer or world.player.dead then
        self.aiTask = coroutine.create(function()
            return self:_patrolRoutine()
        end)
        return
    end

    -- hey, come back here!
    self:_beginMove(playerCx, playerCy)
    self.isAlert = true
    self.moveSpeed = ALERT_MOVE_SPEED

    -- also, initiate the search...
    cx, cy = self:getCenterPos()
    playerVx, playerVy = math.normalize(playerVx, playerVy)

    self.ai = EnemyAi(self)
    self.ai:initMapAwareness()
    self.ai.yield = coroutine.yield
    self.ai:beginChaseSearch(cx, cy, playerCx, playerCy)

    self.aiTask = coroutine.create(function()
        local searchBehavior = {
            beginMove = self._beginMove,
            isCurrentlyMoving = self._isCurrentlyMoving,
            endMove = self._endMove,
            getPointOfInterest = function()
                return playerCx, playerCy
            end
        }
        local coro = coroutine.create(function()
            self.ai:searchCoroutine(self, searchBehavior)
        end)

        while true do
            if not coroutine.sresume(coro) then
                break
            end
            coroutine.yield()
        end

        -- search is done... return home.
        self.ai:release()
        self.ai = nil

        for _=1, 240 do
            coroutine.yield()
        end

        self:_moveToHome()
        return self:_patrolRoutine()
    end)
end

---@param path any
---@param index integer
---@param dir integer
---@return integer index, integer dir
local function getNextPathIndex(path, index, dir)
    local pointCount = path:getPointCount()

    if path.closed then
        index = math.wrap(index + dir, 1, pointCount + 1)
    else
        if dir == 1 and index == pointCount then
            dir = -1
            index = index - 1
        elseif dir == -1 and index == 1 then
            dir = 1
            index = 2
        else
            index = index + dir
        end
    end

    return index, dir
end

function Enemy:_patrolRoutine()
    if not self.patrolPath then
        return
    end

    -- starting vertex is the closest one
    local pathIndex
    do
        local cx, cy = self:getCenterPos()

        pathIndex = 1
        local minDist = math.distance(cx, cy, self.patrolPath:getPoint(1))
        for i=2, self.patrolPath:getPointCount() do
            local dist = math.distance(cx, cy, self.patrolPath:getPoint(i))
            if dist < minDist then
                pathIndex = i
                minDist = dist
            end
        end
    end

    -- determine initial path traversal direction
    -- the enemy shall traverse the path according to the direction it is
    -- currently facing
    local moveDir
    do
        local path = self.patrolPath
        local angX = math.cos(self.faceDir)
        local angY = math.sin(self.faceDir)
        local curX, curY = path:getPoint(pathIndex)
        local prevX, prevY = path:getPoint(getNextPathIndex(path, pathIndex, -1))
        local nextX, nextY = path:getPoint(getNextPathIndex(path, pathIndex, 1))
        local prevDx, prevDy = prevX - curX, prevY - curY
        local nextDx, nextDy = nextX - curX, nextY - curY

        local nextDot = angX * nextDx + angY * nextDy
        local prevDot = angX * prevDx + angY * prevDy

        moveDir = nextDot > prevDot and 1 or -1
    end

    self.moveSpeed = PATROL_MOVE_SPEED
    
    while true do
        local path = self.patrolPath
        local pointCount = path:getPointCount()
        if pointCount == 1 then
            softerror("bruh")
            break
        end

        -- get next path index
        local nextIndex
        nextIndex, moveDir = getNextPathIndex(path, pathIndex, moveDir)
        
        -- move to it please.
        local x, y = path:getPoint(nextIndex)
        x = math.round(x / 8) * 8
        y = math.round(y / 8) * 8

        self:_beginMove(x, y)
        while self:_isCurrentlyMoving() do
            coroutine.yield()
        end

        -- wait 1.5 secs before moving to the next point
        for i=1, 90 do
            coroutine.yield()
        end

        pathIndex = nextIndex
    end
end

local DIRECTIONS = {"r", "d", "l", "u"}

---@param ang number
---@param dirCount integer
local function getAngleInt(ang, dirCount)
    ang = math.normalise_angle(ang - math.pi) + math.pi
    return math.round(ang / math.tau * dirCount) % dirCount
end

---@param lastAnimState string?
function Enemy:_updateAnimation(lastAnimState)
    if type(self.render) ~= "table" then return end
    local spr = self.render.sprite
    if not spr then return end

    if self.animState == "dead" then
        local angInt = getAngleInt(-self.faceDir + math.pi/2, 8)
        local celStart = spr.res.animations.dead.from
        if spr.curAnim then
            spr:stop()
        end

        spr.cel = celStart + angInt
    else
        local angInt = getAngleInt(self.faceDir, 4)
        self.dirAnim:setDirection(spr, DIRECTIONS[angInt+1])
        if self.animState ~= lastAnimState then
            self.dirAnim:play(spr, self.animState)
        end
    end

    spr:update(App.tickLength)
end

return Enemy
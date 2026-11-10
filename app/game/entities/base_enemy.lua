local SpriteRenderer = require("game.util").SpriteRenderer
local centeredRect = require("game.util").centeredRect
local Const = require("game.consts")
local Util = require("game.util")
local EnemyAi = require "game.enemy_ai"
local Pathfinding = require "game.pathfind"
local Resmgr = require "game.resmgr"

---@class game.entities.Enemy: game.entities.Entity
local Enemy = batteries.class {
    extends = require("game.entities.base")
}

function Enemy:new(x, y, w, h)
    self:super(x, y, w, h)
    self:addTag("enemy")

    self.collision = true
    self.colGroup = Const.COLGROUP_NPC
    self.moveSpeed = 2.0
    self.dead = false

    -- sight timer stuff --
    self.sightTimer = 0
    self.noticeWait = 20 -- how many frames until enemy actually notices/registers player
    self.fireTimer = 0
    self.fireWait = 30 -- how frames after notice until enemy shoots player

    self.gunSight = Util.newEntity("gun_sight", 0, 0) --[[@as game.entities.GunSight]]
    self.gunSight.maxBounces = 1

    self._hasMoveTarget = false
    self._moveTargetX = 0
    self._moveTargetY = 0
    self._homeX = 0.0
    self._homeY = 0.0
    self._isTrackingPlayer = false

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
end

function Enemy:_added()
    self._homeX, self._homeY = self:getCenterPos()
end

function Enemy:_removing()
    self.gunSight:remove()
    self._sightCoro = nil
    self.ai = nil
end

function Enemy:_hit(hitVx, hitVy)
    hitVx, hitVy = math.normalize(hitVx, hitVy)

    -- Die . Now.
    self.dead = true
    self.msg:unsubscribe("hit", self._hit)
    self:removeTag("enemy")

    self.xVel = hitVx * 3
    self.yVel = hitVy * 3
    self.zIndex = -10

    self.gunSight:remove()
    self.gunSight = nil

    -- darken color
    self.render.r = self.render.r * 0.5
    self.render.g = self.render.g * 0.5
    self.render.b = self.render.b * 0.5

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

-- must be called within a coroutine...
function Enemy:_moveToHome()
    local startX, startY = self:getCenterPos()
    startX = math.floor(startX / Const.TILE_SIZE)
    startY = math.floor(startY / Const.TILE_SIZE)
    local endX = math.floor(self._homeX / Const.TILE_SIZE)
    local endY = math.floor(self._homeY / Const.TILE_SIZE)
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
end

function Enemy:_witnessedDeath(victim, hitVx, hitVy, isPerpretator)
    if not isPerpretator then
        return
    end

    self.ai = EnemyAi(self.world)
    self.aiTask = coroutine.create(function()
        local myOrigX, myOrigY = self:getCenterPos()
        local victimOrigX, victimOrigY = victim:getCenterPos()

        -- first, wait a bit...
        for _=1, love.math.random(20, 40) do
            coroutine.yield()
        end

        -- then, move to victim...
        self:_beginMove(victim.x, victim.y)
        while self:_isCurrentlyMoving() do
            coroutine.yield()
        end
        
        -- initialize search for the killer
        self.ai.yield = coroutine.yield
        self.ai:beginKillerSearch(myOrigX, myOrigY, victimOrigX, victimOrigY, hitVx, hitVy)

        local searchBehavior = {
            beginMove = self._beginMove,
            isCurrentlyMoving = self._isCurrentlyMoving
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
        self.ai = nil

        for _=1, 240 do
            coroutine.yield()
        end

        self:_moveToHome()
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
    
    if self.dead then
        self.xVel = self.xVel * 0.9
        self.yVel = self.yVel * 0.9
        return
    end

    if self._hasMoveTarget then
        local dx,dy = self._moveTargetX - self.x, self._moveTargetY - self.y
        if math.length(dx, dy) < 10 then
            print("STOP IT")
            self._hasMoveTarget = false
        else
            dx, dy = math.normalize(dx, dy)
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
    if world.player then
        local hasSight = self:hasSightLineTo(world.player)
        if hasSight then
            self.sightTimer = self.sightTimer + 1
        else
            self.sightTimer = 0
        end
    end
    -- self:_sightUpdate()

    if self.ai then
        self.ai:update()
    end
end

function Enemy:_sightRoutine()
    coroutine.yield()
    local world = assert(self.world)

    -- do nothing until enemy notices player
    self.sightTimer = 0
    while self.sightTimer < self.noticeWait do
        coroutine.yield()
    end

    -- i see him!!
    self.ai = nil
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
        cx, cy = self:getCenterPos()
        playerCx, playerCy = world.player:getCenterPos()
        playerVx, playerVy = world.player.xVel, world.player.yVel

        local playerDx = playerCx - cx
        local playerDy = playerCy - cy
        if playerDx * playerDx + playerDy * playerDy ~= 0 then
            playerDx, playerDy = math.normalize(playerDx, playerDy)
        end

        self.gunSight:updateSight(cx, cy, playerDx, playerDy)
        coroutine.yield()

        self.fireTimer = self.fireTimer + 1
        if self.fireTimer == self.fireWait then
            print("fire the weapon!")
            if not Debug.enabled then
                Sceneman.switchScene("entry")
            end
        end
    end

    -- no longer in sight...
    for _=1, 5 do
        coroutine.yield()
    end

    self.gunSight:remove()

    if not self.aiBehavior.chasePlayer then
        return
    end

    -- hey, come back here!
    self:_beginMove(playerCx, playerCy)

    -- also, initiate the search...
    cx, cy = self:getCenterPos()
    playerVx, playerVy = math.normalize(playerVx, playerVy)

    self.ai = EnemyAi(world)
    self.ai.yield = coroutine.yield
    self.ai:beginChaseSearch(cx, cy, playerCx, playerCy)

    self.aiTask = coroutine.create(function()
        local searchBehavior = {
            beginMove = self._beginMove,
            isCurrentlyMoving = self._isCurrentlyMoving,
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
        self.ai = nil

        for _=1, 240 do
            coroutine.yield()
        end

        self:_moveToHome()
    end)

    --[[
    if sightRaycast then
        if not self.gunSight.world then
            self.world:addEntity(self.gunSight)
        end

        local cx, cy = self:getCenterPos()
        local dx, dy = math.normalize(playerDx, playerDy)
        self.gunSight:updateSight(cx, cy, dx, dy)

        self.fireTimer = self.fireTimer + 1
        if self.fireTimer == self.noticeWait then
            print("notice")
            self._hasMoveTarget = true
            self._moveTargetX, self._moveTargetY = world.player:getCenterPos()
        end

        if self.fireTimer >= self.fireWait then
            print("fire the weapon")
            self.fireTimer = 0
            -- Sceneman.switchScene("entry")
        end
    else
        if self.gunSight.world then
            self.gunSight:remove()
            self.gunSight:clearSight()
        end

        self.fireTimer = 0
    end
    --]]
end

return Enemy
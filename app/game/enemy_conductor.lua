---This class is responsible for managing orchestration between the enemy AIs
---in the level.
---@class game.EnemyConductor: batteries.Class
---@overload fun(world:game.World):game.EnemyConductor
local EnemyConductor = batteries.class()

---@param world game.World
function EnemyConductor:new(world)
    self.world = world
end

function EnemyConductor:handleEnemyDeath(victim, hitVx, hitVy)
    -- alert any enemies in sight line to perceived origin of bullet
    local witnesses = {}
    for _, ent in ipairs(self.world:findEntitiesWithTag("enemy")) do
        ---@cast ent game.entities.Enemy
        if ent:hasSightLineTo(victim) and ent.aiBehavior.investigateKills then
            table.insert(witnesses, ent)
        end
    end

    -- the perpretator is a randomly picked witness
    local perpretator = table.pick_random(witnesses)
    for _, ent in ipairs(witnesses) do
        ent:publish("witnessedDeath", victim, hitVx, hitVy, ent == perpretator)
    end
end

return EnemyConductor
local collision = {}

local TILE_SIZE = require("game.consts").TILE_SIZE

---@param x0 number
---@param y0 number
---@param w0 number
---@param h0 number
---@param x1 number
---@param y1 number
---@param w1 number
---@param h1 number
---@return boolean
function collision.rectRectCollision(x0, y0, w0, h0, x1, y1, w1, h1)
    return x0 < x1 + w1 and
           y0 < y1 + h1 and
           x0 + w0 > x1 and
           y0 + h0 > y1
end

---@param ray_x number
---@param ray_y number
---@param ray_dx number
---@param ray_dy number
---@param rx number
---@param ry number
---@param rw number
---@param rh number
---@return number? distance, number? nx, number? ny
function collision.rayRectIntersection(ray_x, ray_y, ray_dx, ray_dy,
                                       rx, ry, rw, rh)
    local ray_len = math.length(ray_dx, ray_dy)
    if ray_len == 0.0 then
        return
    end

    ray_dx = ray_dx / ray_len
    ray_dy = ray_dy / ray_len

    local rl = rx
    local rr = rx + rw
    local rt = ry
    local rb = ry + rh

    -- get ray distances for all four rect sides
    local d_left  = (rl - ray_x) / ray_dx
    local d_right = (rr - ray_x) / ray_dx
    local d_top   = (rt - ray_y) / ray_dy
    local d_bot   = (rb - ray_y) / ray_dy

    -- get intersections for each side (the other component is inferred by the side)
    local p_left  = ray_y + ray_dy * d_left;
    local p_right = ray_y + ray_dy * d_right;
    local p_top   = ray_x + ray_dx * d_top;
    local p_bot   = ray_x + ray_dx * d_bot;

    -- get the minimum positive distance
    local min_dist = math.huge
    if d_left >= 0.0 and p_left > rt and p_left < rb then
        min_dist = math.min(d_left, min_dist)
    end
    if d_right >= 0.0 and p_right > rt and p_right < rb then
        min_dist = math.min(d_right, min_dist)
    end
    if d_top >= 0.0 and p_top > rl and p_top < rr then
        min_dist = math.min(d_top, min_dist)
    end
    if d_bot >= 0.0 and p_bot > rl and p_bot < rr then
        min_dist = math.min(d_bot, min_dist)
    end

    -- if minDist is still POSITIVE_INFINITY, no intersections were found
    if min_dist == math.huge then
        return
    end

    -- get the normal of the intersecting side
    local nx, ny
    if min_dist == d_left then
        nx, ny = -1, 0
    elseif min_dist == d_right then
        nx, ny = 1, 0
    elseif min_dist == d_top then
        nx, ny = 0, -1
    elseif min_dist == d_bot then
        nx, ny = 0, 1
    else
        softerror("impossible else branch")
    end

    return min_dist, nx, ny
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param tileCol fun(tx:integer, ty:integer)
---@return integer? colX, integer? colY, integer? colW, integer? colH, any? colEnt
function collision.gameCollision(x, y, w, h, tileCol)
    local sx = math.floor(x / TILE_SIZE)
    local sy = math.floor(y / TILE_SIZE)
    local ex = math.ceil((x + w) / TILE_SIZE) - 1
    local ey = math.ceil((y + h) / TILE_SIZE) - 1
    local cx = x + w / 2
    local cy = y + h / 2

    local collideX, collideY, collideW, collideH
    local minDist = math.huge

    -- first, check tile collisions
    for ty=sy, ey do
        for tx=sx, ex do
            local t = tileCol(tx, ty)
            if t ~= nil and t ~= 0 then
                local tcx = (tx + 0.5) * TILE_SIZE
                local tcy = (ty + 0.5) * TILE_SIZE
                local dx = tcx - cx
                local dy = tcy - cy
                local distsq = dx * dx + dy * dy
                if distsq < minDist then
                    collideX = tx * TILE_SIZE
                    collideY = ty * TILE_SIZE
                    collideW = TILE_SIZE
                    collideH = TILE_SIZE
                end
            end
        end
    end

    -- then, check entity collisions
    -- for _, ent in ipairs(ents) do
    --     if ent == entToIgnore or not ent.collide then
    --         goto continue
    --     end
        

    --     ::continue::
    -- end

    return collideX, collideY, collideW, collideH, nil
end

local function sign2(n)
    return n >= 0 and 1 or -1
end

---@param ray_x number
---@param ray_y number
---@param ray_dx number
---@param ray_dy number
---@param getCol fun(tx:integer, ty:integer)
---@return number? distance, number? dx, number? dy
function collision.tileRaycast(ray_x, ray_y, ray_dx, ray_dy, getCol)
    local ray_len = math.length(ray_dx, ray_dy)
    if ray_len == 0.0 then return end

    ray_dx = ray_dx / ray_len
    ray_dy = ray_dy / ray_len

    local dir_sign_x = sign2(ray_dx)
    local dir_sign_y = sign2(ray_dy)
    local tile_offset_x = (ray_dx >= 0.0) and 1 or 0
    local tile_offset_y = (ray_dy >= 0.0) and 1 or 0

    local cur_x = ray_x
    local cur_y = ray_y
    local tile_x = math.floor(cur_x / TILE_SIZE)
    local tile_y = math.floor(cur_y / TILE_SIZE)
    
    local t = 0.0
    local dt = 0.0
    local dt_x = ((tile_x + tile_offset_x) * TILE_SIZE - cur_x) / ray_dx
    local dt_y = ((tile_y + tile_offset_y) * TILE_SIZE - cur_y) / ray_dy
    local side = 0

    while t < ray_len do
        local col = getCol(tile_x, tile_y)
        
        -- nil means out of bounds!
        if not col then
            break
        end
        
        if col > 0 --[[and not NONCOLLIDABLE_TILES[col])]] then
            local nx, ny
            if side == 0 then
                nx = dir_sign_x
                ny = 0.0
            else
                nx = 0
                ny = dir_sign_y
            end

            return t, nx, ny
        end

        if dt_x < dt_y then
            tile_x = tile_x + dir_sign_x
            side = 0
            dt = dt_x
            t = t + dt
            dt_x = dt_x + dir_sign_x * TILE_SIZE / ray_dx - dt
            dt_y = dt_y - dt
        else
            tile_y = tile_y + dir_sign_y
            side = 1
            dt = dt_y
            t = t + dt
            dt_x = dt_x - dt
            dt_y = dt_y + dir_sign_y * TILE_SIZE / ray_dy - dt
        end
    end
end

return collision
---@meta

--wrap v around range [lo, hi)
function math.wrap(v, lo, hi)
	return (v - lo) % (hi - lo) + lo
end

--wrap i around the indices of t
function math.wrap_index(i, t)
	return math.floor(math.wrap(i, 1, #t + 1))
end

--clamp v to range [lo, hi]
function math.clamp(v, lo, hi)
	return math.max(lo, math.min(v, hi))
end

--clamp v to range [0, 1]
function math.clamp01(v)
	return math.clamp(v, 0, 1)
end

--round v to nearest whole, away from zero
function math.round(v)
	if v < 0 then
		return math.ceil(v - 0.5)
	end
	return math.floor(v + 0.5)
end

--round v to one-in x
-- (eg x = 2, v rounded to increments of 0.5)
function math.to_one_in(v, x)
	return math.round(v * x) / x
end

--round v to a given decimal precision
function math.to_precision(v, decimal_points)
	return math.to_one_in(v, math.pow(10, decimal_points))
end

--0, 1, -1 sign of a scalar
--todo: investigate if a branchless or `/abs` approach is faster in general case
function math.sign(v)
	if v < 0 then return -1 end
	if v > 0 then return 1 end
	return 0
end

--linear interpolation between a and b
function math.lerp(a, b, t)
	return a * (1.0 - t) + b * t
end

--linear interpolation with a minimum "final step" distance
--useful for making sure dynamic lerps do actually reach their final destination
function math.lerp_eps(a, b, t, eps)
	local v = math.lerp(a, b, t)
	if math.abs(v - b) < eps then
		v = b
	end
	return v
end

--bilinear interpolation between 4 samples
function math.bilerp(a, b, c, d, u, v)
	return math.lerp(
		math.lerp(a, b, u),
		math.lerp(c, d, u),
		v
	)
end

--get the lerp factor on a range, inverse_lerp(6, 0, 10) == 0.6
function math.inverse_lerp(v, min, max)
	return (v - min) / (max - min)
end

--remap a value from one range to another
function math.remap_range(v, in_min, in_max, out_min, out_max)
	return math.lerp(out_min, out_max, math.inverse_lerp(v, in_min, in_max))
end

--remap a value from one range to another, staying within that range
function math.remap_range_clamped(v, in_min, in_max, out_min, out_max)
	return math.lerp(out_min, out_max, math.clamp01(math.inverse_lerp(v, in_min, in_max)))
end

--easing curves
--(generally only "safe" for 0-1 range, see math.clamp01)

--no curve - can be used as a default to avoid needing a branch
function math.identity(f)
	return f
end

--classic smoothstep
function math.smoothstep(f)
	return f * f * (3 - 2 * f)
end

--classic smootherstep; zero 2nd order derivatives at 0 and 1
function math.smootherstep(f)
	return f * f * f * (f * (f * 6 - 15) + 10)
end

--pingpong from 0 to 1 and back again
function math.pingpong(f)
	return 1 - math.abs(1 - (f * 2) % 2)
end

--quadratic ease in
function math.ease_in(f)
	return f * f
end

--quadratic ease out
function math.ease_out(f)
	local oneminus = (1 - f)
	return 1 - oneminus * oneminus
end

--quadratic ease in and out
--(a lot like smoothstep)
function math.ease_inout(f)
	if f < 0.5 then
		return f * f * 2
	end
	local oneminus = (1 - f)
	return 1 - 2 * oneminus * oneminus
end

--branchless but imperfect quartic in/out
--either smooth or smootherstep are usually a better alternative
function math.ease_inout_branchless(f)
	local halfsquared = f * f / 2
	return halfsquared * (1 - halfsquared) * 4
end

--todo: more easings - back, bounce, elastic

--(internal; use a provided random generator object, or not)
local function _random(rng, ...)
	if rng then return rng:random(...) end
	if love then return love.math.random(...) end
	return math.random(...)
end

--return a random sign
function math.random_sign(rng)
	return _random(rng) < 0.5 and -1 or 1
end

--return a random value between two numbers (continuous)
function math.random_lerp(min, max, rng)
	return math.lerp(min, max, _random(rng))
end

--nan checking
function math.isnan(v)
	return v ~= v
end

--angle handling stuff
--superior constant handy for expressing things in turns
math.tau = math.pi * 2

--normalise angle onto the interval [-math.pi, math.pi)
--so each angle only has a single value representing it
function math.normalise_angle(a)
	return math.wrap(a, -math.pi, math.pi)
end

--alias for americans
math.normalize_angle = math.normalise_angle

--get the normalised difference between two angles
function math.angle_difference(a, b)
	a = math.normalise_angle(a)
	b = math.normalise_angle(b)
	return math.normalise_angle(b - a)
end

--math.lerp equivalent for angles
function math.lerp_angle(a, b, t)
	local dif = math.angle_difference(a, b)
	return math.normalise_angle(a + dif * t)
end

--math.lerp_eps equivalent for angles
function math.lerp_angle_eps(a, b, t, eps)
	--short circuit to avoid having to wrap so many angles
	if a == b then
		return a
	end
	--same logic as lerp_eps
	local v = math.lerp_angle(a, b, t)
	if math.abs(math.angle_difference(v, b)) < eps then
		v = b
	end
	return v
end

--geometric functions standalone/"unpacked" components and multi-return
--consider using vec2 if you need anything complex!

--rotate a point around the origin by an angle
function math.rotate(x, y, r)
	local s = math.sin(r)
	local c = math.cos(r)
	return c * x - s * y, s * x + c * y
end

--get the length of a vector from the origin
function math.length(x, y)
	return math.sqrt(x * x + y * y)
end

--get the distance between two points
function math.distance(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2
	return math.length(dx, dy)
end

return math

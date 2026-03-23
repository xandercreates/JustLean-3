---@class Easings
local easings = {}

---@private
---@param a number|Vector|Matrix
---@param b number|Vector|Matrix
---@param t number
---@return number|Matrix|Vector
function easings.inOutSine(a, b, t)
    return math.map(-(math.cos(math.pi * t) - 1) / 2, 0, 1, a, b)
end

---@private
---@param a number|Vector|Matrix
---@param b number|Vector|Matrix
---@param t number
---@return number|Matrix|Vector
function easings.inOutCubic(a, b, t)
    local v = t < 0.5 and 4 * t ^ 3 or 1 - (-2 * t + 2) ^ 3 / 2
    return math.map(v, 0, 1, a, b)
end

function easings.inOutElastic(a, b, x)
    local c5 = (2 * math.pi) / 4.5
    local v
    if x == 0 then
      v = 0
    elseif x == 1 then
      v = 1
    elseif x < 0.5 then
      v = -(math.pow(2, 20 * x - 10) * math.sin((20 * x - 11.125) * c5)) / 2
    else
      v = (math.pow(2, -20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1
    end
    return math.map(v, 0, 1, a, b)
end

function easings.linear(a,b,t)
    return a + (b - a) * t
end

--Curves
easings.curves = {
    linear    = function(t) return t end,
    easeIn    = function(t) return t * t end,
    easeOut   = function(t) return 1 - (1 - t) * (1 - t) end,
    easeInOut = function(t) return t < 0.5 and 2*t*t or 1 - (-2*t+2)^2/2 end,
    smooth    = function(t) return t * t * (3 - 2 * t) end,
}
---@param curr number|Vector3
---@param tgt number|Vector3
---@param speed number -- lerp speed
---@param curve_fn function yes
---@return number|Vector3
function easings.slerp(curr, tgt, speed, curve_fn)
    local diff = tgt - curr
    local dist = type(diff) == "number" and math.abs(diff) or diff:length()
    if dist < 0.001 then return tgt end
    local extra = curve_fn(math.clamp(dist / 90, 0, 1))
    local shaped = speed + (1 - speed) * extra
    return math.lerp(curr, tgt, math.clamp(shaped, 0, 1))
end

---@param curr number|Vector3
---@param tgt number|Vector3
---@param vel number|Vector3
---@param stiff number
---@param dampen number
---@return number|Vector3 new_curr
---@return number|Vector3 new_vel
function easings.spring(curr, tgt, vel, stiff, dampen)
    vel = (vel + (tgt - curr) * stiff) * dampen
    return curr + vel, vel
end

---@private
---@param a number|Vector|Matrix
---@param b number|Vector|Matrix
---@param t number
---@param s string
---@return number|Matrix|Vector
local function ease(a, b, t, s)
    return easings[s](a, b, t)
end

math.ease = ease
math.boing = easings.spring
math.slerp = easings.slerp
math.cur = easings.curves
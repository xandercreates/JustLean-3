---@class Easings
local easings = {}
--consts
local pi = 3.141592653589793238462643383279502884197 ---i didnt use math.pi for the lols.... DIGITS!!!!!!
local c1 = 1.70158
local c2 = c1 * 1.525
local c3 = c1 + 1
local c4 = (2 * pi) / 3
local c5 = (2 * pi) / 4.5
local n1 = 7.5625
local d1 = 2.75

--inBounce Requires outBounce, felt easier to just make it an external function to be accessible for the other funcs
local function outBounce(t) if (t < 1 / d1) then return n1 * t * t; elseif (t < 2 / d1) then t = (t - 1.5 / d1) return n1 * t * t + 0.75; elseif (t < 2.5 / d1) then t = (t - 2.25 / d1) return n1 * t * t + 0.9375; else t = (t - 2.625 / d1) return n1 * t * t + 0.984375; end end

---@class EaseCurves
local curves = {
    smooth = function(t) return t * t * (3 - 2 * t) end,
    linear = function(t) return t end,
    logarithmic = function(t) return logar(t * (exp(1) - 1) + 1) end,
    inSine = function(t) return 1 - cos((t * pi) / 2) end,
    outSine = function(t) return sin((t * pi) / 2) end,
    sine = function(t) return -(cos(pi * t) - 1) / 2 end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return 1 - (1 - t) * (1 - t) end,
    quad = function(t) return t < 0.5 and (2 * t * t) or (1 - (-2 * t + 2)^2 / 2) end,
    inCubic = function(t) return t * t * t end,
    outCubic = function(t) return 1 - (1 - t)^3 end,
    cubic = function(t) return t < 0.5 and (4 * t * t * t) or (1 - (-2 * t + 2)^3 / 2) end,
    inQuart = function(t) return t * t * t * t end,
    outQuart = function(t) return 1 - (1 - t)^4 end,
    quart = function(t) return t < 0.5 and (8 * t * t * t * t) or (1 - (-2 * t + 2)^4 / 2) end,
    inQuint = function(t) return t * t * t * t * t end,
    outQuint = function(t) return 1 - (1 - t)^5 end,
    quint = function(t) return t < 0.5 and (16 * t * t * t * t * t) or (1 - (-2 * t + 2)^5 / 2) end,
    inExpo = function(t) return t == 0 and 0 or 2^(10 * t - 10) end,
    outExpo = function(t) return t == 1 and 1 or (1 - 2^(-10 * t)) end,
    expo = function(t) return t == 0 and 0 or t == 1 and 1 or t < 0.5 and (2^(20 * t - 10) / 2) or (2 - 2^(-20 * t + 10)) / 2 end,
    inCirc = function(t) return 1 - sqrt(1 - (t^2)) end,
    outCirc = function(t) return sqrt(1 - (t - 1)^2) end,
    circ = function(t) return t < 0.5 and ((1 - sqrt(1 - (2 * t)^2)) / 2) or (sqrt(1 - (-2 * t + 2)^2) + 1) / 2 end,
    inBack = function(t) return c3 * t * t * t - c1 * t * t end,
    outBack = function(t) return 1 + c3 * ((t - 1)^3) + c1 * ((t - 1)^2) end,
    back = function(t) return t < 0.5 and (((2 * t)^2) * ((c2 + 1) * 2 * t - c2)) / 2 or (((2 * t - 2)^2 * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2) end,
    inElastic = function(t) return t == 0 and 0 or t == 1 and 1 or -(2^(10 * t - 10)) * sin((t * 10 - 10.75) * c4) end,
    outElastic = function(t) return t == 0 and 0 or t == 1 and 1 or (2^(-10 * t)) * sin((t * 10 - 0.75) * c4) + 1 end,
    elastic = function(t) return t == 0 and 0 or t == 1 and 1 or t < 0.5 and -((2^(20 * t - 10)) * sin((20 * t - 11.125) * c5)) / 2 or ((2^(-20 * t + 10)) * sin((20 * t - 11.125) * c5)) / 2 + 1 end,
    outBounce = outBounce,
    inBounce = function(t) return 1 - outBounce(1 - t) end,
    bounce = function(t) return t < 0.5 and (1 - outBounce(1 - 2 * t)) / 2 or (1 + outBounce(2 * t - 1)) / 2 end
}

---@param curr number|Vector3
---@param tgt number|Vector3
---@param speed number -- lerp speed
---@param curve_fn function
---@return number|Vector3
function easings.sperp(curr, tgt, speed, curve_fn)
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

---Framerate-independent exponential smoothing toward a target.
---@param current number|Vector3
---@param target number|Vector3
---@param rate number -- higher = snappier
---@param dt number -- delta time in seconds
---@return number|Vector3
function easings.damp(current, target, rate, dt)
    return math.lerp(current, target, 1 - math.exp(-rate * dt))
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

return easings

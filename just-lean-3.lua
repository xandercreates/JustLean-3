-- Just Lean 3
-- DEV ENV: Figura 0.1.6, Lua 5.2 (LuaJ, Sandboxed)

---@alias ValidModes
---|1 STRENGTH
---|2 CLAMPED
---|3 BOTH

---@alias Sides
---|1 LEFT
---|2 RIGHT

---@alias ValidCurves
---| "linear"
---| "smooth"
---| "logarithmic"
---| "inSine"
---| "outSine"
---| "sine"
---| "inQuad"
---| "outQuad"
---| "quad"
---| "inCubic"
---| "outCubic"
---| "cubic"
---| "inQuart"
---| "outQuart"
---| "quart"
---| "inQuint"
---| "outQuint"
---| "quint"
---| "inExpo"
---| "outExpo"
---| "expo"
---| "inCirc"
---| "outCirc"
---| "circ"
---| "inBack"
---| "outBack"
---| "back"
---| "inBounce"
---| "outBounce"
---| "bounce"

---@class JustLean3
local jl3 = {}

jl3.active = {} -- everything that's currently updating goes here

local raw_Y = 0
local sin, cos, lerp, clamp, abs = math.sin, math.cos, math.lerp, math.clamp, math.abs
local logar, exp, sqrt = math.log, math.exp, math.sqrt
local vec3 = vectors.vec3
local vHead = vanilla_model.HEAD
local base = vec3(0, 0, 0)

local DT = 0.05
local WEIGHT_RATE = 14

local raw = base
local sneaking = false
local riding = false
local swim = false
local climbing = false
local targetVel = 1
local breathe = base
local turnLean = 0
local leanScale = 1.0
local offset = vanilla_model.HEAD:getOffsetRot() or vec3(0, 0, 0)
local pi = 3.141592653589793238462643383279502884197
local c1 = 1.70158
local c2 = c1 * 1.525
local c3 = c1 + 1
local c4 = (2 * pi) / 3
local c5 = (2 * pi) / 4.5
local n1 = 7.5625
local d1 = 2.75
local isSableLoaded = false

local function wrap(val)
    return ((val + 180) % 360) - 180
end

local function outBounce(t)
    return (t < 1 / d1) and (n1 * t * t) or (t < 2 / d1) and (n1 * (t - 1.5 / d1) * (t - 1.5 / d1) + 0.75) or (t < 2.5 / d1) and (n1 * (t - 2.25 / d1) * (t - 2.25 / d1) + 0.9375) or (n1 * (t - 2.625 / d1) * (t - 2.625 / d1) + 0.984375)
end

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

local function sperp(curr, tgt, speed, curve_data, axis_mask)
    local diff = tgt - curr
    local dist = type(diff) == "number" and abs(diff) or diff:length()
    if dist < 0.001 then return tgt end
    local rawT = clamp(dist / 90, 0, 1)
    
    if axis_mask and type(curve_data) == "function" then
        local cx = axis_mask.x == 1 and curve_data or curves.linear
        local cy = axis_mask.y == 1 and curve_data or curves.linear
        local cz = axis_mask.z == 1 and curve_data or curves.linear
        
        return vec3(
            lerp(curr.x, tgt.x, clamp(speed + (1 - speed) * cx(rawT), 0, 1)),
            lerp(curr.y, tgt.y, clamp(speed + (1 - speed) * cy(rawT), 0, 1)),
            lerp(curr.z, tgt.z, clamp(speed + (1 - speed) * cz(rawT), 0, 1))
        )
    elseif type(curve_data) == "table" then
        local cx = curve_data.x or curves.linear
        local cy = curve_data.y or curves.linear
        local cz = curve_data.z or curves.linear
        
        return vec3(
            lerp(curr.x, tgt.x, clamp(speed + (1 - speed) * cx(rawT), 0, 1)),
            lerp(curr.y, tgt.y, clamp(speed + (1 - speed) * cy(rawT), 0, 1)),
            lerp(curr.z, tgt.z, clamp(speed + (1 - speed) * cz(rawT), 0, 1))
        )
    else
        local extra = curve_data(rawT)
        local shaped = speed + (1 - speed) * extra
        return lerp(curr, tgt, clamp(shaped, 0, 1))
    end
end

local function spring(curr, tgt, vel, stiff, dampen)
    vel = (vel + (tgt - curr) * stiff) * dampen
    return curr + vel, vel
end

local function damp(current, target, rate, dt)
    return lerp(current, target, 1 - exp(-rate * dt))
end

local MODE_STRENGTH = 1
local MODE_CLAMPED = 2
local MODE_BOTH = 3
local LEFT = 1
local RIGHT = 2

jl3.lean = {}
jl3.head = {}
jl3.arms = {}
jl3.legs = {}
jl3.extras = {}

jl3.settings = {
    breatheStrength = 1.25,     -- strength
    breatheSpeed = 0.95,        -- breathing speed..
    turnLeanStiff = 0.5,
    turnLeanStrength = 40,
    turn_z = 15,                --max angle in degrees for the z axis of the torso
    leanDamping = 0.575,        --torso spring bounciness (higher = wobblier, lower = stiffer) idk why its like this it was meant to be the other way around but here it is.
    headCurve = "smooth",       --curve for head tracking (linear/easeIn/easeOut/easeInOut/smooth)
    armCurve = "smooth",        --same deal for arms
    legCurve = "smooth",        --and legs
    _zstr = 0.1,                --body tilt
}

function jl3:getActiveTable()
    return jl3.active
end

local api = {}
api.__index = api

function api:remove()
    for i = #jl3.active, 1, -1 do
        if jl3.active[i] == self then
            table.remove(jl3.active, i)
            return true
        end
    end
    return false
end

function api:enable()
    self.disabled = false
    self.enabled = true
    self._settled = false
    if self.type == "LEAN" then
        self.rot_vel = base
        self.pivot_vel = base
    end
    return self
end

function api:disable()
    self.disabled = true
    self.enabled = false
    self._settled = false
    if self.type == "LEAN" then
        self.rot = base
    end
    return self
end

function api:setWeight(w)
    self.weight = clamp(w, 0, 1)
    self._settled = false
    return self
end

function api:stepWeight()
    local targetW = (self.enabled and self.weight) or 0
    self._w = damp(self._w, targetW, WEIGHT_RATE, DT)
    
    if targetW == 0 and self._w < 0.002 then
        self._w = 0
        if not self._settled then
            self._settled = true
            if self.part then
                if self.type == "HEAD" then
                    self.part:setRot(base)
                else
                    self.part:setOffsetRot(base)
                end
                if self.type == "LEAN" and self.base_pivot then self.part:setPivot(self.base_pivot) end
                if self.type == "LEG" or self.type == "INFLUENCE" then self.part:setPos(base) end
            end
        end
        return true
    end
    return false
end

function api:bind(part) self.part = part; self._settled = false; return self end
function api:unbind() self.part = nil; return self end
function api:getRot() return self.r_rot or base end
function api:getPos() return self.r_pos or base end
function api:getWeight() return self._w or 0 end

-- metatables inherit from api
local lean = setmetatable({}, api); lean.__index = lean
local head = setmetatable({}, api); head.__index = head
local arms = setmetatable({}, api); arms.__index = arms
local legs = setmetatable({}, api); legs.__index = legs
local extras = setmetatable({}, api); extras.__index = extras

local torso_count = 0
local head_count = 0
local arm_count = 0
local leg_count = 0
local extras_count = 0


---@param mode ValidModes
---@param part? ModelPart
---@param speed number
---@param pivot Vector3
---@param enabled boolean
---@param constraints table --{{xMin, xMax}, {yMin, yMax}}
---@param strength Vector3
---@param dobreathe boolean
---@param dospring boolean
---@param in_curve ValidCurves
---@return table
function jl3.lean:new(mode, part, speed, pivot, enabled, constraints, strength, dobreathe, dospring, in_curve)
    local self = setmetatable({}, lean)
    self.type = "LEAN"
    self.id = torso_count + 1
    self.enabled = enabled
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
    self.part = part
    self.do_spring = dospring and dospring or false
    self.interp_curve = in_curve and in_curve or "linear"
    self.mode = mode
    self.constraints = constraints or {{-90, 90}, {-90, 90}}
    self.strength = strength
    self.speed = speed or 1
    self.rot = base
    self.rot_vel = base
    self._pivot = base
    self.pivot = pivot and pivot or (part and part:getPivot() or base)
    self.pivot_vel = base
    self.base_pivot = self.pivot
    self.f_pivot = self.pivot
    self._rot = base
    self.r_rot = base
    self.dobreathe = dobreathe == nil and true or dobreathe
    self._settled = false
    table.insert(jl3.active, self)
    torso_count = torso_count + 1
    return self
end

function lean:tick()
    if self:stepWeight() then return end
    self._rot = self.rot
    local s = jl3.settings
    local rotTarget, pivotTarget
    if self.disabled then
        rotTarget = base
        pivotTarget = self.base_pivot
    else
        local zRot = raw.y * s._zstr * leanScale
        local calc
        if self.mode == MODE_STRENGTH then
            calc = vec3(raw.x * targetVel, raw.y, raw.z + zRot) * self.strength * leanScale
        elseif self.mode == MODE_CLAMPED then
            calc = vec3(
                clamp(raw.x, self.constraints[1][1], self.constraints[1][2]) * targetVel,
                clamp(raw.y, self.constraints[2][1], self.constraints[2][2]) * targetVel,
                zRot
            ) * leanScale
        elseif self.mode == MODE_BOTH then
            calc = vec3(
                clamp(raw.x, self.constraints[1][1], self.constraints[1][2]) * targetVel,
                clamp(raw.y, self.constraints[2][1], self.constraints[2][2]) * targetVel,
                zRot
            ) * self.strength * leanScale
        end
        local turnZ = clamp(turnLean * s.turnLeanStrength, -s.turn_z, s.turn_z)
        pivotTarget = self.base_pivot + (sneaking and (vanilla_model.BODY:getOriginPos() * 1.875) or base)
        rotTarget = (calc * (sneaking and vec3(0.1, 0.5, 0.1) or 1)) + (self.dobreathe and breathe or base) + vec3(0, 0, turnZ)
    end
    self._pivot = self.pivot
    if self.do_spring then
        self.pivot, self.pivot_vel = spring(self.pivot, pivotTarget, self.pivot_vel, self.speed, s.leanDamping)
        self.rot, self.rot_vel = spring(self.rot, rotTarget, self.rot_vel, self.speed, s.leanDamping)
    else
        self.rot = sperp(self.rot, rotTarget, self.speed, curves[self.interp_curve])
        self.pivot = sperp(self.pivot, pivotTarget, self.speed, curves[self.interp_curve])
    end
end

function lean:render(delta)
    if self._settled then return end
    self.r_rot = lerp(self._rot, self.rot, delta)
    self.f_pivot = lerp(self._pivot, self.pivot, delta)
    if self.part then
        self.part:setPivot(lerp(self.base_pivot, self.f_pivot, self._w)):setOffsetRot(self.r_rot * self._w)
    end
end

---@param mode ValidModes
---@param part? ModelPart
---@param speed number
---@param enabled true
---@param constraints table
---@param strength number|Vector3
---@param lean_table JustLean3
---@return table
function jl3.head:new(mode, part, speed, enabled, constraints, strength, lean_table)
    local self = setmetatable({}, head)
    self.type = "HEAD"
    self.id = head_count + 1
    self.mode = mode
    self.enabled = enabled
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
    self.part = part
    self.lean_ref = lean_table
    self.lean = base
    self.rot = base
    self._rot = base
    self.r_rot = base
    self.speed = speed or 1
    self.constraints = constraints
    self.strength = strength
    self._settled = false
    table.insert(jl3.active, self)
    head_count = head_count + 1
    return self
end

function head:tick()
    if self:stepWeight() then return end
    self.lean = self.lean_ref and self.lean_ref.r_rot and -self.lean_ref.r_rot or base
    self._rot = self.rot
    local calc
    if self.disabled then
        calc = base
    else
        local headBob = breathe.y * 0.3
        if self.mode == MODE_STRENGTH then
            calc = (raw + vec3(headBob, 0, raw.y * 0.125) + self.lean) * self.strength
        elseif self.mode == MODE_CLAMPED then
            calc = vec3(
                clamp(raw.x, self.constraints[1][1], self.constraints[1][2]) + headBob,
                clamp(raw.y, self.constraints[2][1], self.constraints[2][2]),
                raw.y * 0.125
            ) + self.lean
        elseif self.mode == MODE_BOTH then
            calc = (vec3(
                clamp(raw.x, self.constraints[1][1], self.constraints[1][2]) + headBob,
                clamp(raw.y, self.constraints[2][1], self.constraints[2][2]),
                raw.y * 0.125
            ) + self.lean) * self.strength
        end
    end
    self.rot = sperp(self.rot, calc, self.speed, curves[jl3.settings.headCurve])
end

function head:render(delta)
    if self._settled then return end
    self.r_rot = lerp(self._rot, self.rot, delta)
    local w = self._w
    vHead:setRot(vHead:getOriginRot() * (1 - w))
    if self.part then
        self.part:setRot(self.r_rot * w)
    end
end


---@param side Sides
---@param part? ModelPart
---@param speed number
---@param enabled boolean
---@param strength number|Vector3
---@return table
function jl3.arms:new(side, part, speed, enabled, strength)
    local self = setmetatable({}, arms)
    self.type = "ARM"
    self.id = arm_count + 1
    self.side = side
    self.part = part
    self.speed = clamp(speed, 0, 1)
    self.strength = strength
    self.enabled = enabled
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
    self.rot = base
    self._rot = base
    self._settled = false
    table.insert(jl3.active, self)
    arm_count = arm_count + 1
    return self
end

function arms:tick()
    if self:stepWeight() then return end
    local calc
    if self.disabled then
        calc = base
    else
        local armBreathe = breathe.x * 0.15
        if self.side == LEFT then
            if sneaking then
                calc = vec3((-raw.x * self.strength.x * 0.5) + armBreathe, 0, 0)
            else
                calc = vec3(((-raw.x * self.strength.x + -(raw.y * self.strength.z)) * targetVel) + armBreathe, 0, 0)
            end
        elseif self.side == RIGHT then
            if sneaking then
                calc = vec3((-raw.x * self.strength.x * 0.5) - armBreathe, 0, 0)
            else
                calc = vec3(((-raw.x * self.strength.x + (raw.y * self.strength.z)) * targetVel) - armBreathe, 0, 0)
            end
        end
        calc = calc * leanScale
    end
    self._rot = self.rot
    self.rot = sperp(self.rot, calc, self.speed, curves[jl3.settings.armCurve])
end

function arms:render(delta)
    if self._settled then return end
    if self.part then
        self.part:setOffsetRot(lerp(self._rot, self.rot, delta) * self._w)
    end
end

---@param side Sides
---@param part? ModelPart
---@param speed number
---@param enabled boolean
---@param strength number|Vector3
---@return table
function jl3.legs:new(side, part, speed, enabled, strength)
    local self = setmetatable({}, legs)
    self.type = "LEG"
    self.id = leg_count + 1
    self.side = (side == "LEFT" or side == LEFT) and LEFT or RIGHT
    self.part = part
    self.speed = clamp(speed, 0, 1)
    self.enabled = enabled
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
    self.strength = strength
    self.rot = base
    self._rot = base
    self.r_rot = base
    self.pos = base
    self._pos = base
    self.r_pos = base
    self._settled = false
    table.insert(jl3.active, self)
    leg_count = leg_count + 1
    return self
end

function legs:tick()
    if self:stepWeight() then return end
    local _crX, _crZ, _calPosX, _calPosZ = 0, 0, 0, 0
    if not self.disabled then
        local crX, crZ = 0, 0
        local calPosX, calPosZ = 0, 0
        local sX, sZ = self.strength.x, self.strength.z
        local lbx, lbz = breathe.x * 0.2, breathe.z * 0.5
        local x_damp = clamp(1 - abs(raw.x) / 90, 0, 1)
        local dY = raw_Y * x_damp
        if self.side == LEFT then
            if sneaking then
                crX = (dY * 0.0714285) + lbx
                crZ = (-(dY * sZ)) + lbz
                calPosX = (dY * sZ) * 0.25
                calPosZ = dY * 0.025
            else
                crX = ((dY * 0.0714285) * targetVel) + lbx
                crZ = lbz
                calPosZ = dY * 0.025
            end
        elseif self.side == RIGHT then
            if sneaking then
                crX = (-(dY * 0.0714285)) - lbx
                crZ = (-(dY * sZ)) - lbz
                calPosX = (dY * sZ) * 0.25
                calPosZ = -(dY * 0.025)
            else
                crX = ((-(dY * 0.0714285)) * targetVel) - lbx
                crZ = -lbz
                calPosZ = -(dY * 0.025)
            end
        end
        _crX, _crZ = crX * sX * leanScale, crZ * leanScale
        _calPosX, _calPosZ = calPosX * sX * leanScale, calPosZ * leanScale
    end
    self._rot = self.rot
    self._pos = self.pos
    local curve = curves[jl3.settings.legCurve]
    self.rot = sperp(self.rot, vec3(_crX, 0, _crZ), self.speed, curve)
    self.pos = sperp(self.pos, vec3(_calPosX, 0, _calPosZ), self.speed, curve)
end

function legs:render(delta)
    if self._settled then return end
    self.r_pos = lerp(self._pos, self.pos, delta)
    self.r_rot = lerp(self._rot, self.rot, delta)
    if self.part then
        self.part:setPos(self.r_pos * self._w)
        self.part:setOffsetRot(self.r_rot * self._w)
    end
end

---@param mode ValidModes
---@param part? ModelPart
---@param speed number
---@param influence table
---@param strength_rot number|Vector3
---@param strength_pos number|Vector3
---@param constraints_rot table
---@param constraints_pos table
---@param pivot Vector3
---@param enabled boolean
---@param in_curve ValidCurves
---@return table
function jl3.extras:new(mode, part, speed, influence, strength_rot, strength_pos, constraints_rot, constraints_pos, pivot, enabled, in_curve)
    local self = setmetatable({}, extras)
    self.type = "INFLUENCE"
    self.enabled = enabled or true
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
    self.part = part
    self.mode = mode
    self.speed = speed
    self.interp_curve = in_curve or "smooth"
    self.mode_string = mode == 1 and "STRENGTH" or mode == 2 and "CLAMPED" or mode == 3 and "BOTH"
    self.inf_table = influence
    self.strength_rot = strength_rot
    self.strength_pos = strength_pos
    self.constraints_rot = constraints_rot
    self.constraints_pos = constraints_pos
    self.id = extras_count + 1
    self.rot = base
    self._rot = base
    self.r_rot = base
    self.pos = base
    self._pos = base
    self.r_pos = base
    self._settled = false
    self.pivot = type(pivot) == "Vector3" and pivot or (part and part:getPivot() or base)
    extras_count = extras_count + 1
    table.insert(jl3.active, self)
    return self
end

function extras:tick()
    if self:stepWeight() then return end
    local this = self.inf_table
    local calc
    local calc_p
    local ipos = this.pos and this.pos or base
    self._rot = self.rot
    self._pos = self.pos
    local s_r = self.strength_rot * (player:isCrouching() and 0.5 or 1)
    local s_p = self.strength_pos * (player:isCrouching() and 0.5 or 1)
    
    if self.disabled then
        calc = base
        calc_p = base
    elseif self.mode == 1 then
        calc = this.rot * s_r
        calc_p = ipos * s_p
    elseif self.mode == 2 then
        calc = vec3(
            clamp(this.rot.x, self.constraints_rot[1][1], self.constraints_rot[2][1]),
            clamp(this.rot.y, self.constraints_rot[1][2], self.constraints_rot[2][2]),
            clamp(this.rot.z, self.constraints_rot[1][3], self.constraints_rot[2][3])
        )
        calc_p = vec3(
            clamp(ipos.x, self.constraints_pos[1][1], self.constraints_pos[2][1]),
            clamp(ipos.y, self.constraints_pos[1][2], self.constraints_pos[2][2]),
            clamp(ipos.z, self.constraints_pos[1][3], self.constraints_pos[2][3])
        )
    elseif self.mode == 3 then
        calc = vec3(
            clamp(this.rot.x, self.constraints_rot[1][1], self.constraints_rot[2][1]),
            clamp(this.rot.y, self.constraints_rot[1][2], self.constraints_rot[2][2]),
            clamp(this.rot.z, self.constraints_rot[1][3], self.constraints_rot[2][3])
        ) * s_r
        calc_p = vec3(
            clamp(ipos.x, self.constraints_pos[1][1], self.constraints_pos[2][1]),
            clamp(ipos.y, self.constraints_pos[1][2], self.constraints_pos[2][2]),
            clamp(ipos.z, self.constraints_pos[1][3], self.constraints_pos[2][3])
        ) * s_p
    end
    self.rot = sperp(self.rot, calc, self.speed, curves[self.interp_curve])
    self.pos = sperp(self.pos, calc_p, self.speed, curves[self.interp_curve])
end

function extras:render(delta)
    if self._settled then return end
    self.r_rot = lerp(self._rot, self.rot, delta)
    self.r_pos = lerp(self._pos, self.pos, delta)
    if self.part then
        self.part:setPos(self.r_pos * self._w)
        self.part:setOffsetRot(self.r_rot * self._w)
    end
end

function jl3:disable()
    for i = 1, #self.active do self.active[i]:disable() end
end

function jl3:enable()
    for i = 1, #self.active do self.active[i]:enable() end
end

function jl3:setWeight(w)
    for i = 1, #self.active do self.active[i]:setWeight(w) end
end

function events.tick()
    local systime = client.getSystemTime() * 0.001
    isSableLoaded = client:isModLoaded("sable")
    local t = sin(systime * 1.25)
    local vel
    if isSableLoaded then
        local x, y, z = table.unpack(player:getNbt().Motion)
        vel = vec3(x, y, z)
    else
        vel = player:getVelocity()
    end
    local speed = vel.x_z:length() * 20
    local headRot = vHead:getOriginRot()
    sneaking = player:isCrouching()
    riding = player:getVehicle() ~= nil
    swim = player:isVisuallySwimming()
    climbing = player:isClimbing()

    if swim then
        leanScale = 0.1
    elseif climbing or riding then
        leanScale = 0.3
    else
        leanScale = 1.0
    end

    offset = vanilla_model.HEAD:getOffsetRot() or vec3(0, 0, 0)

    raw = vec3(
        wrap(headRot.x),
        wrap(headRot.y),
        wrap(headRot.z)
    ) + offset

    raw_Y = wrap(headRot.y)
    targetVel = math.max(0.3, 1.0 - (speed * 0.16))

    -- Turn lean: cross product of look direction x velocity
    local dir = player:getLookDir()
    local cross = -((dir.x * vel.z) - (dir.z * vel.x))
    local dis = turnLean - cross
    turnLean = turnLean - jl3.settings.turnLeanStiff * dis
    local settings = jl3.settings
    if settings.useBreathing then
        breathe = lerp(breathe, vec3(
            t * 2.0,
            abs(t) / 2.0,
            abs(cos(t)) / 4.0
        ) * settings.breatheStrength, settings.breatheSpeed)
    else
        breathe = base
    end
    for i = 1, #jl3.active do
        jl3.active[i]:tick()
    end
end

function events.render(delta)
    for i = 1, #jl3.active do
        jl3.active[i]:render(delta)
    end
end

return jl3
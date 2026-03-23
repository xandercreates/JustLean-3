-- JustLean3
-- ease.lua is actually needed this time

---@class JustLean3
local jl3 = {}

jl3.active = {} -- everything that's currently updating goes here

local raw_Y = 0
local sin, cos, lerp, clamp, abs = math.sin, math.cos, math.lerp, math.clamp, math.abs
local spring --set after ease.lua is loaded
local slerp
local curves
local vec3 = vectors.vec3
local vHead = vanilla_model.HEAD
local base = vec3(0, 0, 0)

local raw = base
local sneaking = false
local riding = false
local swim = false
local climbing = false
local targetVel = 1
local breathe = base
local turnLean = 0
local leanScale = 1.0

local function wrap(val)
    return ((val + 180) % 360) - 180
end

---@alias ValidModes
---|1 STRENGTH
---|2 CLAMPED
---|3 BOTH

---@alias Sides
---|1 LEFT
---|2 RIGHT

local MODE_STRENGTH = 1
local MODE_CLAMPED = 2
local MODE_BOTH = 3
local LEFT = 1
local RIGHT = 2

jl3.lean = {}
jl3.head = {}
jl3.arms = {}
jl3.legs = {}

-- tweak any of these at runtime. go wild i guess :P
jl3.settings = {
    useBreathing = true,        -- have an idle breathing animation
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
    gazeCompat = true           --you could just keep this as true tbh
}

---@return table
function jl3:getActiveTable()
    return jl3.active
end

-- metatables
local lean = {}; lean.__index = lean
local head = {}; head.__index = head
local arms = {}; arms.__index = arms
local legs = {}; legs.__index = legs

-- call :remove() on any part to pull it out of the update loop
local function remove(self)
    for i = #jl3.active, 1, -1 do
        if jl3.active[i] == self then
            table.remove(jl3.active, i)
            return true
        end
    end
    return false
end

lean.remove = remove
head.remove = remove
arms.remove = remove
legs.remove = remove

local torso_count = 0
local head_count = 0
local arm_count = 0
local leg_count = 0

--leaning, the thing you're likely here for.

---@param mode ValidModes -- 1=STRENGTH, 2=CLAMPED, 3=BOTH
---@param part ModelPart
---@param speed number -- interpolatioon speed
---@param pivot Vector3 -- where it rotates from, in blockbench coords (look for your pivot value and input it here)
---@param enabled boolean
---@param constraints table|nil -- {{xMin,xMax},{yMin,yMax}} degrees. ignored if mode=1
---@param strength number|Vector3|nil -- multiplier. ignored if mode=2
---@param dobreathe boolean|nil -- breathing on this part? (default: yes)
function jl3.lean:new(mode, part, speed, pivot, enabled, constraints, strength, dobreathe)
    local self = setmetatable({}, lean)
    self.type = "LEAN"
    self.id = torso_count + 1
    self.enabled = enabled
    self.part = part
    self.mode = mode
    self.constraints = constraints or {{-90, 90}, {-90, 90}}
    self.strength = strength
    self.speed = speed or 1
    self.rot = base
    self.rot_vel = base
    self._pivot = base
    self.pivot = pivot and pivot or part:getPivot()
    self.pivot_vel = base
    self.base_pivot = pivot
    self.f_pivot = pivot
    self._rot = base
    self.r_rot = base
    self.dobreathe = dobreathe == nil and true or dobreathe
    table.insert(jl3.active, self)
    torso_count = torso_count + 1
    return self
end

function lean:tick()
    if not self.enabled then return end
    self._rot = self.rot
    local s = jl3.settings
    local zRot = raw.y * jl3.settings._zstr * leanScale
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
    local pivotTarget = self.base_pivot + (sneaking and (vanilla_model.BODY:getOriginPos() * 1.875) or base)
    local rotTarget = (calc * (sneaking and vec3(0.1, 1, 1) or 1)) + (self.dobreathe and breathe or base) + vec3(0, 0, turnZ)
    self._pivot = self.pivot
    self.pivot, self.pivot_vel = spring(self.pivot, pivotTarget, self.pivot_vel, self.speed, s.leanDamping)
    self.rot, self.rot_vel = spring(self.rot, rotTarget, self.rot_vel, self.speed, s.leanDamping)
end

function lean:render(delta)
    if not self.enabled then return end
    self.r_rot = lerp(self._rot, self.rot, delta)
    self.f_pivot = lerp(self._pivot, self.pivot, delta)
    self.part:setPivot(self.f_pivot):setOffsetRot(self.r_rot)
end

--Head 
---@param mode ValidModes --use numbers 1-3
---@param part ModelPart
---@param speed number -- interpolation speed
---@param enabled boolean
---@param constraints table|nil -- {{xMin,xMax},{yMin,yMax}}, nil/unused if on mode 1
---@param strength number|Vector3|nil --nil/unused if on mode 2
---@param lean_table table|nil -- pass your torso lean here so the head compensates
function jl3.head:new(mode, part, speed, enabled, constraints, strength, lean_table)
    local self = setmetatable({}, head)
    self.type = "HEAD"
    self.id = head_count + 1
    self.mode = mode
    self.enabled = enabled
    self.part = part
    self.lean_ref = lean_table
    self.lean = base
    self.rot = base
    self._rot = base
    self.r_rot = base
    self.speed = speed or 1
    self.constraints = constraints
    self.strength = strength
    self.gazeCompat = jl3.settings.gazeCompat
    table.insert(jl3.active, self)
    head_count = head_count + 1
    return self
end

function head:tick()
    if not self.enabled then return end
    vHead:setRot(0, 0, 0)
    self.lean = self.lean_ref and self.lean_ref.r_rot and -self.lean_ref.r_rot or base
    self._rot = self.rot
    local headBob = breathe.y * 0.3
    local calc
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
    self.rot = slerp(self.rot, calc or base, self.speed, curves[jl3.settings.headCurve])
end

function head:render(delta)
    if not self.enabled then return end
    self.r_rot = lerp(self._rot, self.rot, delta)
    if self.gazeCompat then
        self.part:setOffsetRot(vHead:getOffsetRot() and vHead:getOffsetRot() or vec(0,0,0) + self.r_rot)
    else
        self.part:setRot(self.r_rot)
    end
end

---@param side Sides --1=LEFT, 2=RIGHT
---@param part ModelPart
---@param speed number
---@param enabled boolean
---@param strength Vector3 -- x = pitch influence, z = yaw influence (y not used)
function jl3.arms:new(side, part, speed, enabled, strength)
    local self = setmetatable({}, arms)
    self.type = "ARM"
    self.id = arm_count + 1
    self.side = side
    self.part = part
    self.speed = clamp(speed, 0, 1)
    self.strength = strength
    self.enabled = enabled
    self.rot = base
    self._rot = base
    table.insert(jl3.active, self)
    arm_count = arm_count + 1
    return self
end

function arms:tick()
    if not self.enabled then return end
    local armBreathe = breathe.x * 0.15
    local calc
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
    self._rot = self.rot
    self.rot = slerp(self.rot, (calc or base) * leanScale, self.speed, curves[jl3.settings.armCurve])
end

function arms:render(delta)
    if not self.enabled then return end
    self.part:setOffsetRot(lerp(self._rot, self.rot, delta))
end

---@param side Sides|string -- 1="LEFT" or 2="RIGHT"
---@param part ModelPart
---@param speed number
---@param enabled boolean
---@param strength Vector3 -- x = rotation scale, z = yaw->Z (y not used)
function jl3.legs:new(side, part, speed, enabled, strength)
    local self = setmetatable({}, legs)
    self.type = "LEG"
    self.id = leg_count + 1
    self.side = (side == "LEFT" or side == LEFT) and LEFT or RIGHT
    self.part = part
    self.speed = clamp(speed, 0, 1)
    self.enabled = enabled
    self.strength = strength
    self.rot = base
    self._rot = base
    self.pos = base
    self._pos = base
    table.insert(jl3.active, self)
    leg_count = leg_count + 1
    return self
end

function legs:tick()
    if not self.enabled then return end
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
    local _crX, _crZ = crX * sX * leanScale, crZ * leanScale
    local _calPosX, _calPosZ = calPosX * sX * leanScale, calPosZ * leanScale
    self._rot = self.rot
    self._pos = self.pos
    local curve = curves[jl3.settings.legCurve]
    self.rot = slerp(self.rot, vec3(_crX, 0, _crZ), self.speed, curve)
    self.pos = slerp(self.pos, vec3(_calPosX, 0, _calPosZ), self.speed, curve)
end

function legs:render(delta)
    if not self.enabled then return end
    self.part:setPos(lerp(self._pos, self.pos, delta))
    self.part:setOffsetRot(lerp(self._rot, self.rot, delta))
end


function events.tick()
    if not spring then
        spring = math.boing
        slerp = math.slerp
        curves = math.cur
    end
    local systime = client.getSystemTime() * 0.001
    local t = sin(systime * 1.25)
    local vel = player:getVelocity()
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

    raw = vec3(
        wrap(headRot.x),
        wrap(headRot.y),
        wrap(headRot.z)
    )

    raw_Y = wrap(headRot.y)
    targetVel = math.max(0.3, 1.0 - (speed * 0.16))

    -- Turn lean: cross product of look direction x velocity
    local dir = player:getLookDir()
    local cross = (dir.x * vel.z) - (dir.z * vel.x)
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

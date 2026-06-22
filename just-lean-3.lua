-- Just Lean 3
-- ease.lua is actually needed this time

--DEV ENV: Figura 0.1.6, LuaJ-core/LuaJ-jse 3.0.8 (Lua 5.2)

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
local offset = vanilla_model.HEAD:getOffsetRot() or vec(0,0,0)

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
jl3.extras = {}

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
local extras = {}; extras.__index = extras

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
extras.remove = remove

local function disable_part(self)
    self.disabled = true
    self._settled = false
    self.enabled = false
end
local function enable_part(self)
    self.disabled = false
    self.enabled = true
    self._settled = false
end

lean.disable = disable_part
head.disable = disable_part
arms.disable = disable_part
legs.disable = disable_part
extras.disable = disable_part

function lean:enable()
    enable_part(self)
    self.rot_vel = base
    self.pivot_vel = base
end

function lean:disable()
    self.rot = vec(0,0,0)
    disable_part(self)

end

head.enable = enable_part
arms.enable = enable_part
legs.enable = enable_part
extras.enable = enable_part

local torso_count = 0
local head_count = 0
local arm_count = 0
local leg_count = 0
local extras_count = 0

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
    self.disabled = false
    self._settled = false
    table.insert(jl3.active, self)
    torso_count = torso_count + 1
    return self
end

function lean:tick()
    if not self.enabled or self._settled then
        return end
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
    self.pivot, self.pivot_vel = spring(self.pivot, pivotTarget, self.pivot_vel, self.speed, s.leanDamping)
    self.rot, self.rot_vel = spring(self.rot, rotTarget, self.rot_vel, self.speed, s.leanDamping)
    if self.disabled and self.rot:length() < 0.01 and self.rot_vel:length() < 0.01 then
        self.rot, self.rot_vel = base, base
        self.pivot, self.pivot_vel = self.base_pivot, base
        self._settled = true
        self.part:setOffsetRot(base):setPivot(self.base_pivot)
    end
end

function lean:render(delta)
    if not self.enabled or self._settled then return end
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
    self.disabled = false
    self._settled = false
    table.insert(jl3.active, self)
    head_count = head_count + 1
    return self
end

function head:tick()
    if not self.enabled or self._settled then return end
    self.lean = self.lean_ref and self.lean_ref.r_rot and -self.lean_ref.r_rot or base
    self._rot = self.rot
    local calc
    if self.disabled then
        calc = base
    else
        vHead:setRot(0, 0, 0)
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
    self.rot = slerp(self.rot, calc, self.speed, curves[jl3.settings.headCurve])
    if self.disabled and self.rot:length() < 0.05 then
        self.rot = base
        self._settled = true
        self.part:setOffsetRot(base)
    end
end

function head:render(delta)
    if not self.enabled or self._settled then return end
    self.r_rot = lerp(self._rot, self.rot, delta)
    if self.gazeCompat then
        self.part:setOffsetRot((vHead:getOffsetRot() or base) + self.r_rot)
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
    self.disabled = false
    self._settled = false
    table.insert(jl3.active, self)
    arm_count = arm_count + 1
    return self
end

function arms:tick()
    if not self.enabled or self._settled then return end
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
    self.rot = slerp(self.rot, calc, self.speed, curves[jl3.settings.armCurve])
    if self.disabled and self.rot:length() < 0.05 then
        self.rot = base
        self._settled = true
        self.part:setOffsetRot(base)
    end
end

function arms:render(delta)
    if not self.enabled or self._settled then return end
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
    self.disabled = false
    self._settled = false
    table.insert(jl3.active, self)
    leg_count = leg_count + 1
    return self
end

function legs:tick()
    if not self.enabled or self._settled then return end
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
    self.rot = slerp(self.rot, vec3(_crX, 0, _crZ), self.speed, curve)
    self.pos = slerp(self.pos, vec3(_calPosX, 0, _calPosZ), self.speed, curve)
    if self.disabled and self.rot:length() < 0.05 and self.pos:length() < 0.01 then
        self.rot, self.pos = base, base
        self._settled = true
        self.part:setOffsetRot(base):setPos(base)
    end
end

function legs:render(delta)
    if not self.enabled or self._settled then return end
    self.part:setPos(lerp(self._pos, self.pos, delta))
    self.part:setOffsetRot(lerp(self._rot, self.rot, delta))
end

---Influence a Selected Modelpart with a JL3 Object
---@param mode number|ValidModes
---@param part ModelPart
---@param speed number
---@param influence table|JustLean3
---@param strength_rot? number|Vector3|nil --can set to nil if on CLAMPED (2)
---@param strength_pos? number|Vector3|nil --can set to nil if on CLAMPED (2)
---@param constraints_rot? table|nil --this one takes 3 entries for x, y, and z. can set to nil if on STRENGTH (1)
---@param constraints_pos? table|nil --this one takes 3 entries for x, y, and z. can set to nil if on STRENGTH (1)
---@param pivot Vector3
---@param enabled boolean
function jl3.extras:new(mode, part, speed, influence, strength_rot, strength_pos, constraints_rot, constraints_pos, pivot, enabled)
    local self = setmetatable({}, extras)
    self.type = "INFLUENCE"
    self.enabled = enabled or true
    self.part = part
    self.mode = mode
    self.speed = speed
    self.mode_string = mode == 1 and "STRENGTH" or mode == 2 and "CLAMPED" or mode == 3 and "BOTH"
    self.inf_table = influence
    self.strength_rot = strength_rot
    self.strength_pos = strength_pos
    self.constraints_rot = constraints_rot
    self.constraints_pos = constraints_pos
    self.id = extras_count + 1
    self.rot = base
    self._rot = base
    self.pos = base
    self._pos = base
    self.pivot = type(pivot) == "Vector3" and pivot or self.part:getPivot()
    extras_count = extras_count + 1
    table.insert(jl3.active, self)
    return self
end

function extras:tick()
    if not self.enabled then return end
    local this = self.inf_table
    local calc
    local calc_p
    local ipos = this.pos and this.pos or base
    self._rot = self.rot
    self._pos = self.pos
    local s_r = self.strength_rot * (player:isCrouching() and 0.5 or 1)
    local s_p = self.strength_pos * (player:isCrouching() and 0.5 or 1)
    if self.mode == 1 then
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
    self.rot = lerp(self.rot, calc, self.speed)
    self.pos = lerp(self.pos, calc_p, self.speed)
end

function extras:render(delta)
    self.part:setOffsetRot(lerp(self._rot,self.rot,delta))
end


function jl3:disable()
    for i = 1, #self.active do self.active[i]:disable() end
end
function jl3:enable()
    for i = 1, #self.active do self.active[i]:enable() end
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

    offset = vanilla_model.HEAD:getOffsetRot() or vec(0,0,0)

    raw = vec3(
        wrap(headRot.x),
        wrap(headRot.y),
        wrap(headRot.z)
    ) + offset

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

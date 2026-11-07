-- Just Lean 3

---CREDITS:
---| Shiji (CommanderShiji @cmdr_shiji) Leg Math Phase 1
---| TombstoneTechnician (TombTech @tombstonetechnician) | Raven Corvaire (RavenTheWitch @thewightwitch) Sway Math
---| マヌエル (@manuel_2867) Figura Implementation of expDecay from Freya Holmér (https://www.youtube.com/@FreyaHolmer)
---| Freya Holmér (https://www.youtube.com/@FreyaHolmer) | expDecay Math

---@diagnostic disable: duplicate-doc-field
---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: missing-fields
---@diagnostic disable: undefined-field

local _VERSION = "3.2.1"

---- PATCH NOTES
---| (Hopefully) Fixed a bug that breaks parts after using :disable() and then :enable() - (https://discord.com/channels/1129805506354085959/1485784920696819874/1567775138605301892)
---| Removed Ease - Seemed like Bloat. Was a good Idea, but I hardly saw a difference. Will return soon, hopefully.
---| Once again, replaced lerp with expDecay.

---@alias ValidModes
---|1 STRENGTH
---|2 CLAMPED
---|3 BOTH

---@alias Sides
---|1 LEFT
---|2 RIGHT

---@class JustLean3.INSTANCE
---@class JustLean3.CONSTRUCTOR
---@class JustLean3.ACTIVE_INSTANCES
---@class JustLean3.TICK
---@class JustLean3.RENDER

---@class JustLean3
---@field lean JustLean3.CONSTRUCTOR
---@field head JustLean3.CONSTRUCTOR
---@field arms JustLean3.CONSTRUCTOR
---@field legs JustLean3.CONSTRUCTOR
---@field extras JustLean3.CONSTRUCTOR

---@type JustLean3
local jl3 = {}
jl3.__type = "JustLean3"

---@type JustLean3.ACTIVE_INSTANCES[]
jl3.active = {}

local rawUrl = "https://raw.githubusercontent.com/xandercreates/JustLean-3/refs/heads/main/just-lean-3.lua"
local versionFuture = nil

if host:isHost() then
    local optInState = config:load("jl3UpdateOptIn")
    if optInState == nil then
        local prompt = '["",{"text":"[Just Lean 3]: Opt in for update notifications? "},{"text":"[YES]","color":"green","clickEvent":{"action":"figura_function","value":"_optUpdates(true)"}},{"text":" "},{"text":"[NO]","color":"red","clickEvent":{"action":"figura_function","value":"_optUpdates(false)"}}]'
        printJson(prompt)
    elseif optInState == true then
        if net:isNetworkingAllowed() and net:isLinkAllowed(rawUrl) and net.http then
            versionFuture = net.http:request(rawUrl):send()
        end
    end
end

local function parseVersion(response)
    if not config:load("jl3UpdateOptIn") then return end
    
    local stream = response:getData()
    local buffer = data:createBuffer()
    buffer:readFromStream(stream)
    buffer:setPosition(0)
    
    local textData = buffer:readString()
    buffer:close()
    
    local remoteVersion = string.match(textData, 'local%s+_VERSION%s*=%s*["\'](.-)["\']')
    
    if not remoteVersion then
        printJson('{"text":"[Just Lean 3]: Cannot read the remote version.","color":"gold"}')
        return
    end
    
    local status = client.compareVersions(_VERSION, remoteVersion)
    if status < 0 then
        printJson('["",{"text":"[Just Lean 3]: Update available. New version: ","color":"gold"},{"text":"' .. remoteVersion .. '","color":"green"}]')
    elseif status > 0 then
        printJson('{"text":"[Just Lean 3]: Local version is newer than remote.","color":"gold"}')
    else
        printJson('{"text":"[Just Lean 3]: The script is up to date.","color":"green"}')
    end
end

function _optUpdates(state)
    config:save("jl3UpdateOptIn", state)
    if state then
        printJson('{"text":"[Just Lean 3]: Update notifications enabled.","color":"green"}')
        if net:isNetworkingAllowed() and net:isLinkAllowed(rawUrl) and net.http then
            versionFuture = net.http:request(rawUrl):send()
        end
    else
        printJson('{"text":"[Just Lean 3]: Update notifications disabled.","color":"gold"}')
    end
end

local sin, cos, clamp, abs = math.sin, math.cos, math.clamp, math.abs
local logar, exp, sqrt = math.log, math.exp, math.sqrt
local map = math.map
local vec3 = vectors.vec3
local vHead = vanilla_model.HEAD
local base = vec3(0, 0, 0)
local wR = 0.56
local sxR = 0.05
local szR = 0.02
local syR = 0.07
local sYR = -0.01
local sZR = 0.5
local lrY = 0.07142857142
local lpZ = 0.025
local lspZ = 0.25

local raw = base
local raw_Y = base.y
local sneaking = false
local riding = false
local swim = false
local climbing = false
local targetVel = 1
local swayMult = 0
local breathe = base
local turnLean = 0
local isSableLoaded = false
local leanScale = 1.0
local offset = vanilla_model.HEAD:getOffsetRot() or vec3(0, 0, 0)
local st = client.getSystemTime()
local getst = client.getSystemTime

math.dt = 0

local function expDecay(a, b, decay, dt)
    local k = clamp(decay, 0, 1) * 25
    return b + (a - b) * exp(-k * dt)
end

local function wrapAngle(val)
    return ((val + 180) % 360) - 180
end


local function spring(curr, tgt, vel, stiff, dampen)
    vel = (vel + (tgt - curr) * stiff) * dampen
    return curr + vel, vel
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


---@class JL3Settings
jl3.settings = {
    breatheStrength = 1.5,
    breatheSpeed = 1,
    breatheX = 2.0,          -- side-to-side breathing amplitude
    breatheY = 0.5,          -- vertical breathing bob
    breatheZ = 0.25,         -- forward/back breathing
    turnLeanStiff = 0.5,
    turnLeanStrength = 40,
    turn_z = 15,
    leanDamping = 0.5,
    _zstr = 0.1,
    sneakLeanX = 0.1,        -- lean X reduction when sneaking
    sneakLeanY = 0.5,        -- lean Y reduction when sneaking
    sneakLeanZ = 0.1,        -- lean Z reduction when sneaking
    sway_str_x = 1,
    sway_str_y = 1,
    sway_str_z = -1,
    stop_shimmy = false,
    useBreathing = true,
    legBreatheX = 0.2,       -- breathing X -> leg rotation
    legBreatheY = 0.5,       -- breathing Y -> leg sway
    legBreatheZ = 0.5,       -- breathing Z -> leg rotation
    legSwayR = 0.2,          -- yaw sway -> leg rotation R
    legSwayP = 0.05,         -- yaw sway -> leg rotation P
    __type = "JL3Settings"
}

function jl3:getActiveTable()
    return jl3.active
end

local api = {}
api.__index = api
api.__type = "JL_API"

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
    return self
end

function api:setWeight(w)
    self.weight = clamp(w, 0, 1)
    self._settled = false
    return self
end

function api:stepWeight()
    local targetW = (self.enabled and self.weight) or 0
    local w_r = clamp(wR, 0, 1)
    self._w = expDecay(self._w, targetW, w_r, 0.05)
    
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
---@param doshimmy boolean
---@param damp_yaw? boolean
---@return JustLean3.INSTANCE[]
function jl3.lean:new(mode, part, speed, pivot, enabled, constraints, strength, dobreathe, dospring, doshimmy, damp_shimmy, damp_yaw)
    local self = setmetatable({}, lean)
    self.type = "LEAN"
    self.id = torso_count + 1
    self.enabled = enabled
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
    self.part = part
    self.do_spring = dospring or false
    self.mode = mode
    self.constraints = constraints or {{-90, 90}, {-90, 90}}
    self.strength = strength
    self.speed = speed or 1
    self.damp_yaw = damp_yaw and damp_yaw or false

    self.rot = base
    self.pivot = pivot or (part and part:getPivot()) or base
    self.shimmy = base

    self.r_rot = base
    self.r_pivot = self.pivot
    self.r_shimmy = base

    self.rot_vel = base
    self.pivot_vel = base
    self.shimmy_vel = base

    self.base_pivot = self.pivot
    self.dobreathe = dobreathe and dobreathe or false
    self.doshimmy = doshimmy and doshimmy or false
    self.damp_shimmy = damp_shimmy and damp_shimmy or false
    self._settled = false
    table.insert(jl3.active, self)
    torso_count = torso_count + 1
    return self
end

function lean:tick()
    if self:stepWeight() then return end
    local s = jl3.settings

    local targetRot, targetPivot, targetShimmy = base, self.base_pivot, base
    if not self.disabled then
        local x_damp = self.damp_yaw and clamp(1 - abs(raw.x) / 90, 0, 1) or 1
        local zRot = (raw.y * s._zstr * leanScale)
        local calcX, calcY, calcZ = 0, 0, 0
        if self.mode == MODE_STRENGTH then
            calcX = raw.x * targetVel * self.strength.x * leanScale
            calcY = raw.y * self.strength.y * leanScale
            calcZ = (raw.z + zRot) * self.strength.z * leanScale
        elseif self.mode == MODE_CLAMPED then
            calcX = clamp(raw.x, self.constraints[1][1], self.constraints[1][2]) * targetVel * leanScale
            calcY = clamp(raw.y, self.constraints[2][1], self.constraints[2][2]) * targetVel * leanScale
            calcZ = zRot * leanScale
        elseif self.mode == MODE_BOTH then
            calcX = clamp(raw.x, self.constraints[1][1], self.constraints[1][2]) * targetVel * self.strength.x * leanScale
            calcY = clamp(raw.y, self.constraints[2][1], self.constraints[2][2]) * targetVel * self.strength.y * leanScale
            calcZ = zRot * self.strength.z * leanScale
        end

        local turnZ = clamp((turnLean * s.turnLeanStrength), -s.turn_z, s.turn_z)
        local multX = sneaking and s.sneakLeanX or 1
        local multY = sneaking and s.sneakLeanY or 1
        local multZ = sneaking and s.sneakLeanZ or 1
        local bX = self.dobreathe and breathe.x or 0
        local bY = self.dobreathe and breathe.y or 0
        local bZ = self.dobreathe and breathe.z or 0

        targetPivot = self.base_pivot * self._w
        targetRot = vec3(
            (calcX * multX) + bX,
            (calcY * multY) + bY,
            (calcZ * multZ) + bZ + turnZ
        ) * self._w

        if self.doshimmy and not s.stop_shimmy and not player:getVehicle() then
            local ly = (raw_Y * (self.damp_shimmy and x_damp or 1)) * swayMult
            targetShimmy = vec3(ly * sxR, abs(ly * syR) * sYR, ly * szR * sZR)
                * vec3(s.sway_str_x, s.sway_str_y, s.sway_str_z)
        end
    end

    if self.do_spring then
        self.rot, self.rot_vel = spring(self.rot, targetRot, self.rot_vel, 1, s.leanDamping)
        self.pivot, self.pivot_vel = spring(self.pivot, targetPivot, self.pivot_vel, 1, s.leanDamping)
        self.shimmy, self.shimmy_vel = spring(self.shimmy, targetShimmy, self.shimmy_vel, 1, s.leanDamping)
    else
        self.rot = targetRot
        self.pivot = targetPivot
        self.shimmy = targetShimmy
    end
end

function lean:render(dt)
    if self._settled then return end
    self.r_rot = expDecay(self.r_rot, self.rot, self.speed, dt)
    self.r_pivot = expDecay(self.r_pivot, self.pivot, self.speed, dt)
    self.r_shimmy = expDecay(self.r_shimmy, self.shimmy, self.speed, dt)
    if self.part then
        self.part:setPos(self.r_shimmy):setPivot(self.r_pivot):setOffsetRot(self.r_rot)
    end
end

---@param mode ValidModes
---@param part? ModelPart
---@param speed number
---@param enabled true
---@param constraints table
---@param strength number|Vector3
---@param lean_table JustLean3.INSTANCE[]
---@return JustLean3.INSTANCE[]
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
    self._r = base
    self.rot = base
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
    if self.lean_ref then
        self.lean = self.speed < self.lean_ref.speed and -self.lean_ref.r_rot or -self.lean_ref.rot
    end
    if self.disabled then
        self.target_rot = base
    else
        local headBob = breathe.y * 0.3
        local rawX, rawY = raw.x, raw.y
        local leanX, leanY, leanZ = self.lean.x, self.lean.y, self.lean.z
        
        local str = self.strength
        local stX = type(str) == "number" and str or str.x
        local stY = type(str) == "number" and str or str.y
        local stZ = type(str) == "number" and str or str.z

        local cX, cY, cZ = 0, 0, 0

        if self.mode == MODE_STRENGTH then
            cX = (rawX + headBob + leanX) * stX
            cY = (rawY + leanY) * stY
            cZ = ((rawY * 0.125) + leanZ) * stZ
        elseif self.mode == MODE_CLAMPED then
            cX = clamp(rawX, self.constraints[1][1], self.constraints[1][2]) + headBob + leanX
            cY = clamp(rawY, self.constraints[2][1], self.constraints[2][2]) + leanY
            cZ = (rawY * 0.125) + leanZ
        elseif self.mode == MODE_BOTH then
            cX = (clamp(rawX, self.constraints[1][1], self.constraints[1][2]) + headBob + leanX) * stX
            cY = (clamp(rawY, self.constraints[2][1], self.constraints[2][2]) + leanY) * stY
            cZ = ((rawY * 0.125) + leanZ) * stZ
        end
        self.target_rot = vec3(cX, cY, cZ) * self._w
    end
end

function head:render(dt)
    if self._settled then return end
    self.rot = expDecay(self.rot, self.target_rot, self.speed, dt)
    vHead:setRot(vHead:getOriginRot() * (1 - self._w))
    if self.part then
        self.part:setRot(self.rot)
    end
end


---@param side Sides
---@param part? ModelPart
---@param speed number
---@param enabled boolean
---@param strength number|Vector3
---@return JustLean3.INSTANCE[]
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
    self.target_rot = base
    self.rot = base
    self._settled = false
    table.insert(jl3.active, self)
    arm_count = arm_count + 1
    return self
end

function arms:tick()
    if self:stepWeight() then return end
    self._r = self.rot
    if self.disabled then
        self.target_rot = base
    else
        local armBreathe = breathe.x * 0.15
        local calcX = 0
        
        if self.side == LEFT then
            if sneaking then
                calcX = (-raw.x * self.strength.x * 0.5) + armBreathe
            else
                calcX = ((-raw.x * self.strength.x + -(raw.y * self.strength.z)) * targetVel) + armBreathe
            end
        elseif self.side == RIGHT then
            if sneaking then
                calcX = (-raw.x * self.strength.x * 0.5) - armBreathe
            else
                calcX = ((-raw.x * self.strength.x + (raw.y * self.strength.z)) * targetVel) - armBreathe
            end
        end
        self.target_rot = vec3(calcX * leanScale, 0, 0) * self._w
    end
end

function arms:render(dt)
    if self._settled then return end
    self.rot = expDecay(self.rot, self.target_rot, self.speed, dt)
    if self.part then
        self.part:setOffsetRot(self.rot)
    end
end

---@param side Sides
---@param part? ModelPart
---@param speed number
---@param enabled boolean
---@param strength number|Vector3
---@return JustLean3.INSTANCE[]
function jl3.legs:new(side, part, speed, enabled, strength, doshimmy, damp_shimmy)
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
    self.target_rot = base
    self.target_pos = base
    self.pos = base
    self.doshimmy = doshimmy == nil and false or doshimmy
    self.damp_shimmy = damp_shimmy == nil and false or damp_shimmy
    self._settled = false
    table.insert(jl3.active, self)
    leg_count = leg_count + 1
    return self
end

function legs:tick()
    if self:stepWeight() then return end
    local _crX, _crZ, _calPosX, _calPosZ = 0, 0, 0, 0
    local s = jl3.settings
    local lsR = 0
    local lsP = 0
    local lbx, lby, lbz = breathe.x * s.legBreatheX, breathe.y * s.legBreatheY, breathe.z * s.legBreatheZ
    if not self.disabled then
        local crX, crZ = 0, 0
        local calPosX, calPosZ = 0, 0
        local x_damp = clamp(1 - abs(raw.x) / 90, 0, 1)
        local sX, sZ = self.strength.x, self.strength.z
        local dY = raw_Y * x_damp
        local smooth_lry = (raw_Y * (self.damp_shimmy and x_damp or 1)) * swayMult
        local stateMult = sneaking and 0.5 or 1.0
        if self.doshimmy and not s.stop_shimmy and not player:getVehicle() then
            lsR = (-smooth_lry * s.legSwayR) * stateMult
            lsP = (smooth_lry * s.legSwayP) * stateMult
        else
            lsR = 0
            lsP = 0
        end
        if self.side == LEFT then
            if sneaking then
                crX = (dY * lrY) + lbx
                crZ = (-(dY * sZ)) + lbz
                calPosX = (dY * sZ) * lspZ
                calPosZ = dY * lpZ
            else
                crX = ((dY * lrY) * targetVel) + lbx
                crZ = lbz
                calPosZ = dY * lpZ
            end
        elseif self.side == RIGHT then
            if sneaking then
                crX = (-(dY * lrY)) - lbx
                crZ = (-(dY * sZ)) - lbz
                calPosX = (dY * sZ) * lspZ
                calPosZ = -(dY * lpZ)
            else
                crX = ((-(dY * lrY)) * targetVel) - lbx
                crZ = -lbz
                calPosZ = -(dY * lpZ)
            end
        end
        _crX, _crZ = crX * sX * leanScale, crZ * leanScale
        _calPosX, _calPosZ = calPosX * sX * leanScale, calPosZ * leanScale
    end
    self.target_rot = vec3(_crX, 0, _crZ + lsR) * self._w
    self.target_pos = vec3(_calPosX + lsP, 0, _calPosZ) * self._w
end

function legs:render(dt)
    if self._settled then return end
    self.pos = expDecay(self.pos, self.target_pos, self.speed, dt)
    self.rot = expDecay(self.rot, self.target_rot, self.speed, dt)
    if self.part then
        self.part
        :setPos(self.pos)
        :setOffsetRot(self.rot)
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
---@return JustLean3.INSTANCE[]
function jl3.extras:new(mode, part, speed, influence, strength_rot, strength_pos, constraints_rot, constraints_pos, pivot, enabled)
    local self = setmetatable({}, extras)
    self.type = "INFLUENCE"
    self.enabled = enabled or true
    self.disabled = not enabled
    self.weight = 1
    self._w = enabled and 1 or 0
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
    self.target_rot = base
    self.pos = base
    self.target_pos = base
    self._settled = false
    self.pivot = type(pivot) == "Vector3" and pivot or (part and part:getPivot() or base)
    extras_count = extras_count + 1
    table.insert(jl3.active, self)
    return self
end

function extras:tick()
    if self:stepWeight() then return end
    local this = self.inf_table
    local ipos = this.pos and this.pos or base
    if self.disabled then
        self.target_rot = base
        self.target_pos = base
    else
        local crouchMult = player:isCrouching() and 0.5 or 1
        local sr = self.strength_rot
        local sp = self.strength_pos
        local srX = (type(sr) == "number" and sr or sr.x) * crouchMult
        local srY = (type(sr) == "number" and sr or sr.y) * crouchMult
        local srZ = (type(sr) == "number" and sr or sr.z) * crouchMult
        local spX = (type(sp) == "number" and sp or sp.x) * crouchMult
        local spY = (type(sp) == "number" and sp or sp.y) * crouchMult
        local spZ = (type(sp) == "number" and sp or sp.z) * crouchMult
        local rX, rY, rZ = 0, 0, 0
        local pX, pY, pZ = 0, 0, 0
        
        if self.mode == 1 then
            rX, rY, rZ = this.rot.x * srX, this.rot.y * srY, this.rot.z * srZ
            pX, pY, pZ = ipos.x * spX, ipos.y * spY, ipos.z * spZ
        elseif self.mode == 2 then
            rX = clamp(this.rot.x, self.constraints_rot[1][1], self.constraints_rot[2][1])
            rY = clamp(this.rot.y, self.constraints_rot[1][2], self.constraints_rot[2][2])
            rZ = clamp(this.rot.z, self.constraints_rot[1][3], self.constraints_rot[2][3])
            
            pX = clamp(ipos.x, self.constraints_pos[1][1], self.constraints_pos[2][1])
            pY = clamp(ipos.y, self.constraints_pos[1][2], self.constraints_pos[2][2])
            pZ = clamp(ipos.z, self.constraints_pos[1][3], self.constraints_pos[2][3])
        elseif self.mode == 3 then
            rX = clamp(this.rot.x, self.constraints_rot[1][1], self.constraints_rot[2][1]) * srX
            rY = clamp(this.rot.y, self.constraints_rot[1][2], self.constraints_rot[2][2]) * srY
            rZ = clamp(this.rot.z, self.constraints_rot[1][3], self.constraints_rot[2][3]) * srZ
            
            pX = clamp(ipos.x, self.constraints_pos[1][1], self.constraints_pos[2][1]) * spX
            pY = clamp(ipos.y, self.constraints_pos[1][2], self.constraints_pos[2][2]) * spY
            pZ = clamp(ipos.z, self.constraints_pos[1][3], self.constraints_pos[2][3]) * spZ
        end
        self.target_rot = vec3(rX, rY, rZ) * self._w
        self.target_pos = vec3(pX, pY, pZ) * self._w
    end
end

function extras:render(dt)
    if self._settled then return end
    self.rot = expDecay(self.rot, self.target_rot, self.speed, dt)
    self.pos = expDecay(self.pos, self.target_pos, self.speed, dt)
    if self.part then
        self.part
        :setPos(self.r_pos)
        :setOffsetRot(self.r_rot)
    end
end

---disable globally
function jl3:disable()
    for i = 1, #self.active do self.active[i]:disable() end
end

---enable globally
function jl3:enable()
    for i = 1, #self.active do self.active[i]:enable() end
end

---set weight globally
function jl3:setWeight(w)
    for i = 1, #self.active do self.active[i]:setWeight(w) end
end



function events.tick()
    isSableLoaded = client.isModLoaded("sable")
    local bt = sin((getst()/1000) * jl3.settings.breatheSpeed)
    
    if host:isHost() and versionFuture and versionFuture:isDone() then
        local success, response = pcall(function()
            return versionFuture:getOrError()
        end)
        
        if success and response then
            parseVersion(response)
        else
            printJson('{"text":"[Just Lean 3]: Failed to check for updates.","color":"red"}')
        end
        versionFuture = nil
    end

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

    offset = vanilla_model.HEAD:getOffsetRot() or base

    raw = vec3(
        wrapAngle(headRot.x),
        wrapAngle(headRot.y),
        wrapAngle(headRot.z)
    ) + offset

    raw_Y = wrapAngle(headRot.y)

    targetVel = math.max(0.3, 1.0 - (speed * 0.16))
    swayMult = clamp(1.0 - (speed * 0.16), 0, 1)

    local settings = jl3.settings
    local dir = player:getLookDir()
    local cross = -((dir.x * vel.z) - (dir.z * vel.x))
    local dis = turnLean - cross
    turnLean = turnLean - settings.turnLeanStiff * dis
    if settings.useBreathing then
        breathe = vec3(
            bt * settings.breatheX,
            abs(bt) * settings.breatheY,
            abs(cos(bt)) * settings.breatheZ
        ) * settings.breatheStrength
    else
        breathe = base
    end
    for i = 1, #jl3.active do
        jl3.active[i]:tick()
    end
end

function events.render()
    local newst = getst()
    math.dt = (newst - st) * 0.001
    st = newst
    local dt = math.dt
    for i = 1, #jl3.active do
        jl3.active[i]:render(dt)
    end
end

return jl3
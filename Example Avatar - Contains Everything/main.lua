vanilla_model.PLAYER:setVisible(false)
models:setPrimaryTexture("SKIN")

local root = models.model.root
local torsopart = root.Torso
local leftarm = torsopart.LeftArm
local rightarm = torsopart.RightArm
local model_head = torsopart.Head
local leftleg = root.LeftLeg
local rightleg = root.RightLeg

---VSCODE DOCS RECOMMENDED!!
---or anything that can also use a Lua LS and read the Code Docs the same way.

local JustLean3 = require("just-lean-3") --var can be any name
local jl3settings = JustLean3.settings

local torso = JustLean3.lean:new(
    3, ---1: STRENGTH, 2: CLAMPED, 3: BOTH
    torsopart, --ModelPart. Leave Nil and It will simply just output math.
    0.5, --How fast you want it? (0 - 1)
    vec(0,12,0), --Either Nil or a Vector3
    true, --controls if it should be enabled or not by default
    {{-90,90},{-22.5,22.5}}, --{{xMin, xMax},{yMin, yMax}} , can be nil if Mode 1 is set
    vec(0.95,0.5,1), --Can either be a number or Vector3, can be nil if Mode 2 is set
    true, --controls if breathing should apply or not.
    true, --controls if lean should be springy or not
    false, --enable alongside with the legs so this does not look weird.
    false --if sway/shimmy should dampen like it does with lean's Y axis based on the X axis.
)

local head = JustLean3.head:new(
    3, ---1: STRENGTH, 2: CLAMPED, 3: BOTH
    model_head, --ModelPart. Leave Nil and It will simply just output math.
    0.75, --How fast you want it? (0 - 1)
    true, --controls if it should be enabled or not by default
    {{-90,90},{-45,45}}, --{{xMin, xMax},{yMin, yMax}} , can be nil if Mode 1 is set
    vec(0.95, 0.95, 0.25), --Can either be a number or Vector3, can be nil if Mode 2 is set
    torso --While I would have liked to make this automatically check for an active lean instance/table, I felt this gives better control to the user
)

local left_arm = JustLean3.arms:new(
    1, -- 1: Left, 2: Right
    leftarm, -- ModelPart, Leave Nil to only output the resulting math.
    0.5, --How fast you want it? (0 - 1)
    true, --controls if it should be enabled or not by default
    vec(0.2,1,0.2) --Can either be a number or Vector3, this should not be nil
)

local right_arm = JustLean3.arms:new(
    2, -- 1: Left, 2: Right
    rightarm, -- ModelPart, Leave Nil to only output the resulting math.
    0.5, --How fast you want it? (0 - 1)
    true, --controls if it should be enabled or not by default
    vec(0.2,1,0.2) --Can either be a number or Vector3, this should not be nil
)

local left_leg = JustLean3.legs:new(
    1, -- 1: Left, 2: Right
    leftleg, -- ModelPart, Leave Nil to only output the resulting math.
    0.5, --How fast you want it? (0 - 1)
    true, --controls if it should be enabled or not by default
    vec(1, 0.5, 0.1), --Can either be a number or Vector3, this should not be nil
    false -- Ensure this changes with your lean. Disabled by default.
)

local right_leg = JustLean3.legs:new(
    2, -- 1: Left, 2: Right
    rightleg, -- ModelPart, Leave Nil to only output the resulting math.
    0.5, --How fast you want it? (0 - 1)
    true, --controls if it should be enabled or not by default
    vec(1, 0.5, 0.1), --Can either be a number or Vector3, this should not be nil
    false -- Ensure this changes with your lean. Disabled by default.
)


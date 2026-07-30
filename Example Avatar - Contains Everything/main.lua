vanilla_model.PLAYER:setVisible(false)
models:setPrimaryTexture("SKIN")

local root = models.model.root
local torsopart = root.Torso
local leftarm = torsopart.LeftArm
local rightarm = torsopart.RightArm
local model_head = torsopart.Head
local leftleg = root.LeftLeg
local rightleg = root.RightLeg
local JustLean3 = require("just-lean-3") --var can be any name
local torso = JustLean3.lean:new(3, torsopart, 0.2725, vec(0,12,0), true, {{-90,90},{-17.5,17.5}}, vec(0.95,0.2,1), true, true, nil) --Torso
local head = JustLean3.head:new(3, model_head, 0.75, true, {{-90,87},{-45,45}}, vec(0.95, 0.95, 0.95), torso) --Head
local left_arm = JustLean3.arms:new(1, leftarm, 0.5, true, vec(0.2,1,0.2))
local right_arm JustLean3.arms:new(2, rightarm, 0.5, true, vec(0.2,1,0.2))
local left_leg = JustLean3.legs:new(1, leftleg, 0.5, true, vec(1, 0.5, 0.1))
local right_leg = JustLean3.legs:new(2, rightleg, 0.5, true, vec(1, 0.5, 0.1))

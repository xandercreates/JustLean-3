vanilla_model.PLAYER:setVisible(false)
models:setPrimaryTexture("SKIN")


local torsopart = models.model.root.Torso
--local body = torsopart.Body
local leftarm = torsopart.LeftArm
local JustLean3 = require("just-lean-3") --var can be any name
local torso = JustLean3.lean:new(3, torsopart, 0.2725, vec(0,12,0), true, {{-90,90},{-17.5,17.5}}, vec(0.95,0.2,1)) --Torso
local head = JustLean3.head:new(3, torsopart.Head, 0.75, true, {{-90,87},{-45,45}}, vec(0.95, 0.95, 0.95), torso) --Head
local left_arm = JustLean3.arms:new(1, leftarm, 0.5, true, vec(0.2,1,0.2))
local right_arm JustLean3.arms:new(2, torsopart.RightArm, 0.5, true, vec(0.2,1,0.2))
local left_leg = JustLean3.legs:new(1, models.model.root.LeftLeg, 0.5, true, vec(1, 0.5, 0.1))
local right_leg = JustLean3.legs:new(2, models.model.root.RightLeg, 0.5, true, vec(1, 0.5, 0.1))
--local torso2 = JustLean3.lean:new()
function events.tick()
    --log(head)
    --log(torso)
   -- log(left_leg)
end

--math.map(1,2,3,4,5)
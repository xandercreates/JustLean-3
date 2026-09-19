local __index = figuraMetatables.ModelPart.__index

local flat_cache = {}

-- Declare using "local function" so it can safely call itself
local function findPart(part, target_name)
    for _, child in ipairs(part:getChildren()) do
        if child:getName() == target_name then
            return child
        end
        local found = findPart(child, target_name)
        if found then return found end
    end
    return nil
end

function figuraMetatables.ModelPart.__index(self, key)
    local result = __index(self, key)
    if result then return result end
    
    local cache_key = self:getName() .. "_" .. key
    if flat_cache[cache_key] then
        return flat_cache[cache_key]
    end
    
    --log(findPart(self, key))
    local found_part = findPart(self, key)
    
    if found_part then
        flat_cache[cache_key] = found_part
        return found_part
    end
    
    return nil
end

local hmp = models.model.Head:newPart("HelmetItemPivot","HelmetItemPivot")
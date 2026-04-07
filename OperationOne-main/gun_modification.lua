local recoil_x = 0
local recoil_y = 0

local Module = {
    _initialized = false,
    _enabled = false,
    _hooked = false,
    shared = nil,
    config = {
        recoil_reduction = 0,
        horizontal_recoil = 0,
    },
}

function Module:setShared(shared)
    if type(shared) ~= "table" then
        return false, "shared must be table"
    end

    self.shared = shared
    if type(shared.applyToEnv) == "function" then
        shared:applyToEnv()
    end

    return true
end

function Module:_applyConfig()
    if self._enabled then
        recoil_x = tonumber(self.config.recoil_reduction) or 0
        recoil_y = tonumber(self.config.horizontal_recoil) or 0
    else
        recoil_x = 0
        recoil_y = 0
    end
end

function Module:_installHook()
    if self._hooked then
        return true
    end

    local old_tweenInfo_new = clonefunction(TweenInfo.new)
    hookfunction(TweenInfo.new, newcclosure(function(...)
        if dbg.info(3, "n") == "recoil_function" then
            sstack(3, 5, gstack(3, 5) * recoil_x)
            sstack(3, 6, gstack(3, 6) * recoil_y)
        end
        return old_tweenInfo_new(...)
    end))

    self._hooked = true
    return true
end

function Module:init(force)
    if self._initialized and not force then
        return true
    end

    local okHook, hookErr = pcall(function()
        return self:_installHook()
    end)
    if not okHook then
        return false, tostring(hookErr)
    end

    self:_applyConfig()
    self._initialized = true
    return true
end

function Module:load(force)
    return self:init(force)
end

function Module:isLoaded()
    return self._initialized
end

function Module:setEnabled(state)
    local okInit, initErr = self:init(false)
    if not okInit then
        return false, initErr
    end

    self._enabled = state == true
    self:_applyConfig()
    return true
end

function Module:updateConfig(newConfig)
    if type(newConfig) ~= "table" then
        return false, "config must be table"
    end

    for key, value in pairs(newConfig) do
        if self.config[key] ~= nil then
            self.config[key] = value
        end
    end

    self:_applyConfig()
    return true
end

function Module:getConfig()
    return self.config
end

function Module:unload()
    self._enabled = false
    self:_applyConfig()
    return true
end

return Module

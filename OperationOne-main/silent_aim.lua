local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService"))

local TARGET_PARTS = {
    "head", "torso", "shoulder1", "shoulder2",
    "arm1", "arm2", "hip1", "hip2", "leg1", "leg2",
}

local Module = {
    shared = nil,
    _initialized = false,
    _hooked = false,
    _enabled = false,
    _gunModule = nil,
    _originalGetShootLook = nil,
    _fovRadius = 60,
    _smoothness = 1,
    _targetMode = "custom_parts",
    _debug = false,
    _circleEnabled = true,
    _fovCircle = nil,
    _circleConn = nil,
}

function Module:setShared(shared)
    if type(shared) ~= "table" then
        return false, "shared must be table"
    end

    self.shared = shared
    if type(shared.applyToEnv) == "function" then
        shared:applyToEnv()
    end

    ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    UserInputService = cloneref(game:GetService("UserInputService"))
    Workspace = cloneref(game:GetService("Workspace"))
    RunService = cloneref(game:GetService("RunService"))
    return true
end

local function cloneCallable(ref)
    if type(ref) ~= "function" then
        return ref
    end
    local ok, cloned = pcall(clonefunction, ref)
    if ok and cloned then
        return cloned
    end
    return ref
end

local function getPartList(targetMode)
    if targetMode == "head_only" then
        return { "head" }
    end
    return TARGET_PARTS
end

function Module:_pickAimPart()
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local viewmodelsFolder = Workspace:FindFirstChild("Viewmodels")
    if not viewmodelsFolder then
        return nil
    end

    local best, best_d2 = nil, math.huge
    local mouse = UserInputService:GetMouseLocation()
    local radius_sq = self._fovRadius * self._fovRadius

    for _, vm in ipairs(viewmodelsFolder:GetChildren()) do
        if vm.Name == "LocalViewmodel" or vm.Name ~= "Viewmodel" then
            continue
        end

        local torso = vm:FindFirstChild("torso")
        if torso and torso.Transparency == 1 then
            continue
        end

        for _, name in ipairs(getPartList(self._targetMode)) do
            local part = vm:FindFirstChild(name)
            if not part or not part:IsA("BasePart") then
                continue
            end

            local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
            if not onScreen then
                continue
            end

            local dx = screenPos.X - mouse.X
            local dy = screenPos.Y - mouse.Y
            local d2 = dx * dx + dy * dy

            if d2 <= radius_sq and d2 < best_d2 then
                best = part
                best_d2 = d2
            end
        end
    end

    return best
end

function Module:_updateFovCircle()
    local circle = self._fovCircle
    if not circle then
        return
    end

    local mp = UserInputService:GetMouseLocation()
    circle.Position = Vector2.new(mp.X, mp.Y)
    circle.Radius = self._fovRadius
    circle.Visible = self._enabled and self._circleEnabled
end

function Module:_ensureFovCircle()
    if self._fovCircle then
        self:_updateFovCircle()
        return
    end

    if not (Drawing and Drawing.new) then
        return
    end

    local circle = Drawing.new("Circle")
    circle.Visible = false
    circle.Filled = false
    circle.Thickness = 1.5
    circle.Color = Color3.fromRGB(255, 255, 255)
    circle.Transparency = 0.7
    circle.NumSides = 64
    circle.Radius = self._fovRadius
    self._fovCircle = circle

    self._circleConn = RunService.RenderStepped:Connect(function()
        self:_updateFovCircle()
    end)
end

function Module:_installHook()
    if self._hooked then
        return true
    end

    local okRequire, gunModuleOrErr = pcall(function()
        return require(ReplicatedStorage.Modules.Items.Item.Gun)
    end)
    if not okRequire or type(gunModuleOrErr) ~= "table" then
        return false, "gun module require failed: " .. tostring(gunModuleOrErr)
    end

    self._gunModule = gunModuleOrErr
    self._originalGetShootLook = cloneCallable(self._gunModule.get_shoot_look)
    if type(self._originalGetShootLook) ~= "function" then
        return false, "get_shoot_look not callable"
    end

    self._gunModule.get_shoot_look = newcclosure(function(weapon)
        if checkcaller_safe() then
            return self._originalGetShootLook(weapon)
        end

        local okOriginal, originalLook = pcall(self._originalGetShootLook, weapon)
        if not okOriginal or typeof(originalLook) ~= "CFrame" then
            return CFrame.new()
        end

        if not self._enabled then
            return originalLook
        end

        local target = self:_pickAimPart()
        if not target then
            return originalLook
        end

        if self._debug then
            print("Silent Aim ->", target:GetFullName())
        end

        local origin = originalLook.Position
        local targetCFrame = CFrame.lookAt(origin, target.Position)
        if self._smoothness < 1 then
            return originalLook:Lerp(targetCFrame, self._smoothness)
        end
        return targetCFrame
    end)

    self._hooked = true
    return true
end

function Module:init(force)
    if self._initialized and not force then
        return true
    end

    local okHook, hookErr = self:_installHook()
    if not okHook then
        return false, hookErr
    end

    self:_ensureFovCircle()
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
    self:_updateFovCircle()
    return true
end

function Module:setFov(value)
    if type(value) ~= "number" or value <= 0 then
        return false, "invalid fov"
    end
    self._fovRadius = value
    self:_updateFovCircle()
    return true
end

function Module:setSmoothness(value)
    if type(value) ~= "number" then
        return false, "invalid smoothness"
    end
    self._smoothness = math.clamp(value, 0.01, 1)
    return true
end

function Module:setTargeting(players, gadgets, cameras)
    -- Kept for compatibility with previous UI signatures.
    if players == true and (gadgets == false or cameras == false) then
        self._targetMode = "custom_parts"
    end
    return true
end

function Module:setFovCircleEnabled(state)
    self._circleEnabled = state == true
    self:_updateFovCircle()
    return true
end

function Module:unload()
    if self._hooked and self._gunModule and self._originalGetShootLook then
        self._gunModule.get_shoot_look = self._originalGetShootLook
    end

    if self._circleConn then
        self._circleConn:Disconnect()
        self._circleConn = nil
    end

    if self._fovCircle then
        pcall(function()
            self._fovCircle:Remove()
        end)
        self._fovCircle = nil
    end

    self._hooked = false
    self._initialized = false
    self._enabled = false
    return true
end

return Module

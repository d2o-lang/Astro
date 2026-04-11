local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Module = {
    shared = nil,
    _initialized = false,
    _enabled = false,
    _mode = "silent",
    _aimAssistActivation = "mb2",
    _targetMode = "custom_parts",
    _fov = 60,
    _fovSq = 60 * 60,
    _smoothness = 1,
    _renderConn = nil,
    _fovCircle = nil,
    _viewmodelsFolder = nil,
    _hookInstalled = false,
    _targetParts = {
        "head", "torso", "shoulder1", "shoulder2",
        "arm1", "arm2", "hip1", "hip2", "leg1", "leg2",
    },
}

local function clampNumber(v, minV, maxV, defaultV)
    local n = tonumber(v)
    if not n then
        return defaultV
    end
    if n < minV then
        return minV
    end
    if n > maxV then
        return maxV
    end
    return n
end

local function getCamera()
    return Workspace.CurrentCamera
end

local function toLower(str)
    if type(str) ~= "string" then
        return ""
    end
    return string.lower(str)
end

function Module:setShared(shared)
    if type(shared) ~= "table" then
        return false, "shared must be table"
    end

    self.shared = shared

    if type(shared.applyToEnv) == "function" then
        pcall(function()
            shared:applyToEnv()
        end)
    end

    local ref = shared.cloneref
    if type(ref) ~= "function" then
        ref = shared.ref
    end

    if type(ref) == "function" then
        RunService = ref(game:GetService("RunService"))
        UserInputService = ref(game:GetService("UserInputService"))
        Workspace = ref(game:GetService("Workspace"))
    end

    return true
end

function Module:_getMousePosition()
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        local camera = getCamera()
        if camera then
            return Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
        end
    end

    local pos = UserInputService:GetMouseLocation()
    return Vector2.new(pos.X, pos.Y)
end

function Module:_getViewmodelsFolder()
    if self._viewmodelsFolder and self._viewmodelsFolder.Parent then
        return self._viewmodelsFolder
    end

    self._viewmodelsFolder = Workspace:FindFirstChild("Viewmodels")
    return self._viewmodelsFolder
end

function Module:_isCandidateModel(model)
    if not model or not model:IsA("Model") then
        return false
    end

    if model.Name ~= "Viewmodel" then
        return false
    end

    local torso = model:FindFirstChild("torso")
    if torso and torso:IsA("BasePart") and torso.Transparency >= 1 then
        return false
    end

    return true
end

function Module:_shouldUsePartName(partName)
    if self._targetMode == "head_only" then
        return toLower(partName) == "head"
    end

    local target = toLower(partName)
    for _, name in ipairs(self._targetParts) do
        if target == name then
            return true
        end
    end

    return false
end

function Module:_checkPart(part, mousePos, closestPart, closestDistSq)
    if not part or not part:IsA("BasePart") then
        return closestPart, closestDistSq
    end

    local camera = getCamera()
    if not camera then
        return closestPart, closestDistSq
    end

    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return closestPart, closestDistSq
    end

    local dx = screenPos.X - mousePos.X
    local dy = screenPos.Y - mousePos.Y
    local distSq = dx * dx + dy * dy

    if distSq <= self._fovSq and distSq < closestDistSq then
        return part, distSq
    end

    return closestPart, closestDistSq
end

function Module:_getClosestTargetToCursor()
    local folder = self:_getViewmodelsFolder()
    if not folder then
        return nil
    end

    local mousePos = self:_getMousePosition()
    local closestPart = nil
    local closestDistSq = math.huge

    for _, model in ipairs(folder:GetChildren()) do
        if self:_isCandidateModel(model) then
            if self._targetMode == "head_only" then
                local head = model:FindFirstChild("head")
                closestPart, closestDistSq = self:_checkPart(head, mousePos, closestPart, closestDistSq)
            else
                for _, child in ipairs(model:GetChildren()) do
                    if child:IsA("BasePart") and self:_shouldUsePartName(child.Name) then
                        closestPart, closestDistSq = self:_checkPart(child, mousePos, closestPart, closestDistSq)
                    end
                end
            end
        end
    end

    return closestPart
end

function Module:_updateFovCircle()
    if not self._fovCircle then
        return
    end

    local pos = self:_getMousePosition()
    self._fovCircle.Position = pos
    self._fovCircle.Radius = self._fov
    self._fovCircle.Visible = self._enabled
end

function Module:_isAimAssistActiveInput()
    if self._aimAssistActivation == "always" then
        return true
    end

    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        local touches = UserInputService:GetTouches()
        return type(touches) == "table" and #touches > 0
    end

    if self._aimAssistActivation == "mb1" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end

    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

function Module:_runAimAssist()
    if not self._enabled then
        return
    end

    if self._mode ~= "aim_assist" then
        return
    end

    if not self:_isAimAssistActiveInput() then
        return
    end

    local camera = getCamera()
    if not camera then
        return
    end

    local target = self:_getClosestTargetToCursor()
    if not target then
        return
    end

    local desired = CFrame.lookAt(camera.CFrame.Position, target.Position)
    local alpha = clampNumber(self._smoothness, 0.01, 1, 1)

    if alpha >= 0.999 then
        camera.CFrame = desired
    else
        camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    end
end

function Module:_onRenderStep()
    self:_updateFovCircle()
    self:_runAimAssist()
end

function Module:_onCFrameNew(oldCF, ...)
    if not self._enabled or self._mode ~= "silent" then
        return oldCF(...)
    end

    local dbg = debug
    if type(dbg) ~= "table" then
        return oldCF(...)
    end

    if type(dbg.info) ~= "function" or type(dbg.getstack) ~= "function" or type(dbg.setstack) ~= "function" then
        return oldCF(...)
    end

    local stackLevel = nil
    if dbg.info(2, "n") == "send_shoot" then
        stackLevel = 2
    elseif dbg.info(3, "n") == "send_shoot" then
        stackLevel = 3
    end

    if stackLevel then
        local target = self:_getClosestTargetToCursor()
        if target then
            local origin = dbg.getstack(stackLevel, 3)
            if origin and origin.Position then
                dbg.setstack(stackLevel, 5, CFrame.lookAt(origin.Position, target.Position))
            end
        end
    end

    return oldCF(...)
end

function Module:_installHook()
    if self._hookInstalled then
        return true
    end

    local clonefn = clonefunction or function(fn) return fn end
    local closure = newcclosure or function(fn) return fn end
    local hookfn = hookfunction

    if type(hookfn) ~= "function" then
        return false, "hookfunction unavailable"
    end

    local oldCF = clonefn(CFrame.new)
    local selfRef = self

    local ok, err = pcall(function()
        hookfn(CFrame.new, closure(function(...)
            return selfRef:_onCFrameNew(oldCF, ...)
        end))
    end)

    if not ok then
        return false, tostring(err)
    end

    self._hookInstalled = true
    return true
end

function Module:_createFovCircle()
    if self._fovCircle then
        return
    end

    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        return
    end

    local env = (getgenv and getgenv()) or _G
    if env.__op1_silent_fov_circle then
        pcall(function()
            env.__op1_silent_fov_circle:Remove()
        end)
    end

    local circle = Drawing.new("Circle")
    circle.Visible = false
    circle.Filled = false
    circle.Thickness = 1.5
    circle.NumSides = 72
    circle.Color = Color3.fromRGB(255, 255, 255)
    circle.Transparency = 1
    circle.Radius = self._fov
    circle.Position = self:_getMousePosition()

    env.__op1_silent_fov_circle = circle
    self._fovCircle = circle
end

function Module:init(force)
    if self._initialized and not force then
        return true
    end

    if self._initialized and force then
        self:unload()
    end

    local okHook, hookErr = self:_installHook()
    if not okHook then
        return false, hookErr
    end

    self:_createFovCircle()

    if self._renderConn then
        self._renderConn:Disconnect()
        self._renderConn = nil
    end

    self._renderConn = RunService.RenderStepped:Connect(function()
        self:_onRenderStep()
    end)

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
    self._fov = clampNumber(value, 10, 400, 60)
    self._fovSq = self._fov * self._fov
    self:_updateFovCircle()
    return true
end

function Module:setSmoothness(value)
    self._smoothness = clampNumber(value, 0.01, 1, 1)
    return true
end

function Module:setMode(mode)
    local m = toLower(mode)
    if m ~= "silent" and m ~= "aim_assist" then
        return false, "invalid mode"
    end

    self._mode = m
    return true
end

function Module:setAimAssistActivation(mode)
    local m = toLower(mode)
    if m ~= "mb1" and m ~= "mb2" and m ~= "always" then
        return false, "invalid activation"
    end

    self._aimAssistActivation = m
    return true
end

function Module:setTargetMode(mode)
    local m = toLower(mode)
    if m ~= "custom_parts" and m ~= "head_only" then
        return false, "invalid target mode"
    end

    self._targetMode = m
    return true
end

function Module:unload()
    self._enabled = false

    if self._renderConn then
        self._renderConn:Disconnect()
        self._renderConn = nil
    end

    if self._fovCircle then
        pcall(function()
            self._fovCircle.Visible = false
            self._fovCircle:Remove()
        end)
        self._fovCircle = nil
    end

    local env = (getgenv and getgenv()) or _G
    if type(env) == "table" then
        env.__op1_silent_fov_circle = nil
    end

    self._initialized = false
    return true
end

return Module

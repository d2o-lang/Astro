local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Module = {
    shared = nil,
    _initialized = false,
    _enabled = false,
    _mode = "silent",
    _targetMode = "custom_parts",
    _targetGadgets = false,
    _aimAssistActivation = "mb2",
    _smoothness = 1,
    _fovRadius = 60,
    _fovRadiusSq = 60 * 60,
    _renderConn = nil,
    _fovCircle = nil,
    _viewmodelsFolder = nil,
    _hookInstalled = false,
}

local TARGET_PARTS = {
    "head", "torso", "shoulder1", "shoulder2",
    "arm1", "arm2", "hip1", "hip2", "leg1", "leg2",
}

local GADGET_TARGETS = {
    Drone = "HumanoidRootPart",
    Claymore = "Laser",
    ProximityAlarm = "RedDot",
    StickyCamera = "Cam",
    SignalDisruptor = "Screen",
}

local TEAM_COLOR = Color3.fromRGB(0, 150, 0)

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

local function toLower(v)
    if type(v) ~= "string" then
        return ""
    end
    return string.lower(v)
end

local function isColorMatch(color, expected)
    if typeof(color) ~= "Color3" or typeof(expected) ~= "Color3" then
        return false
    end

    return math.floor(color.R * 255 + 0.5) == math.floor(expected.R * 255 + 0.5)
        and math.floor(color.G * 255 + 0.5) == math.floor(expected.G * 255 + 0.5)
        and math.floor(color.B * 255 + 0.5) == math.floor(expected.B * 255 + 0.5)
end

local function getDebugApi()
    if type(dbg) == "table" then
        return dbg
    end
    if type(debug) == "table" then
        return debug
    end
    return nil
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
        local camera = Workspace.CurrentCamera
        if camera then
            return Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
        end
    end

    local pos = UserInputService:GetMouseLocation()
    return Vector2.new(pos.X, pos.Y)
end

function Module:_checkPart(part, mousePos, closestPart, closestDistSq)
    if not part or not part:IsA("BasePart") then
        return closestPart, closestDistSq
    end

    local camera = Workspace.CurrentCamera
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

    if distSq <= self._fovRadiusSq and distSq < closestDistSq then
        return part, distSq
    end

    return closestPart, closestDistSq
end

function Module:_getViewmodelTeamMap()
    local viewmodelTeams = {}

    for _, child in ipairs(Workspace:GetChildren()) do
        if child.ClassName == "Highlight" then
            local adornee = child.Adornee
            if adornee and adornee.Name == "Viewmodel" then
                local isTeammate = isColorMatch(child.FillColor, TEAM_COLOR)
                    or isColorMatch(child.OutlineColor, TEAM_COLOR)
                viewmodelTeams[adornee] = isTeammate
            end
        end
    end

    return viewmodelTeams
end

function Module:_getGadgetTargetPart(model)
    if not model or not model:IsA("Model") then
        return nil
    end

    local partName = GADGET_TARGETS[model.Name]
    if not partName then
        return nil
    end

    return model:FindFirstChild(partName)
end

function Module:_getClosestTargetToCursor()
    local closestPart = nil
    local closestDistSq = math.huge
    local mousePos = self:_getMousePosition()
    local viewmodelTeams = self:_getViewmodelTeamMap()

    if not self._viewmodelsFolder or not self._viewmodelsFolder.Parent then
        self._viewmodelsFolder = Workspace:FindFirstChild("Viewmodels")
    end

    local viewmodelsFolder = self._viewmodelsFolder
    if viewmodelsFolder then
        for _, vm in ipairs(viewmodelsFolder:GetChildren()) do
            if vm.Name == "Viewmodel" then
                if viewmodelTeams[vm] then
                    continue
                end

                local torso = vm:FindFirstChild("torso")
                if torso and torso.Transparency == 1 then
                    continue
                end

                if self._targetMode == "head_only" then
                    local head = vm:FindFirstChild("head")
                    closestPart, closestDistSq = self:_checkPart(head, mousePos, closestPart, closestDistSq)
                else
                    for _, partName in ipairs(TARGET_PARTS) do
                        local part = vm:FindFirstChild(partName)
                        closestPart, closestDistSq = self:_checkPart(part, mousePos, closestPart, closestDistSq)
                    end
                end
            end
        end
    end

    if self._targetGadgets then
        for _, child in ipairs(Workspace:GetChildren()) do
            local gadgetPart = self:_getGadgetTargetPart(child)
            if gadgetPart then
                closestPart, closestDistSq = self:_checkPart(gadgetPart, mousePos, closestPart, closestDistSq)
            end
        end
    end

    return closestPart
end

function Module:_isAimAssistInputActive()
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
    if not self._enabled or self._mode ~= "aim_assist" then
        return
    end

    if not self:_isAimAssistInputActive() then
        return
    end

    local camera = Workspace.CurrentCamera
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

function Module:_updateFovCircle()
    if not self._fovCircle then
        return
    end

    self._fovCircle.Visible = self._enabled
    self._fovCircle.Radius = self._fovRadius
    self._fovCircle.Position = self:_getMousePosition()
end

function Module:_onRenderStep()
    self:_updateFovCircle()
    self:_runAimAssist()
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
            if not selfRef._enabled or selfRef._mode ~= "silent" then
                return oldCF(...)
            end

            local dbgApi = getDebugApi()
            if not dbgApi then
                return oldCF(...)
            end

            local infoFn = dbgApi.info
            local getStackFn = dbgApi.getstack or getstack
            local setStackFn = dbgApi.setstack or setstack

            if type(infoFn) ~= "function" or type(getStackFn) ~= "function" or type(setStackFn) ~= "function" then
                return oldCF(...)
            end

            local stackLevel = nil
            if infoFn(2, "n") == "send_shoot" then
                stackLevel = 2
            elseif infoFn(3, "n") == "send_shoot" then
                stackLevel = 3
            end

            if stackLevel then
                local target = selfRef:_getClosestTargetToCursor()
                if target then
                    local origin = getStackFn(stackLevel, 3)
                    if origin and origin.Position then
                        setStackFn(stackLevel, 5, CFrame.lookAt(origin.Position, target.Position))
                    end
                end
            end

            return oldCF(...)
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
    if type(env) == "table" and env.__op1_silent_fov_circle then
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
    circle.Radius = self._fovRadius
    circle.Position = self:_getMousePosition()

    if type(env) == "table" then
        env.__op1_silent_fov_circle = circle
    end

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
    self._fovRadius = clampNumber(value, 10, 400, 60)
    self._fovRadiusSq = self._fovRadius * self._fovRadius
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

function Module:setTargetGadgets(state)
    self._targetGadgets = state == true
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

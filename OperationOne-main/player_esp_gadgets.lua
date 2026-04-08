local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Module = {
    shared = nil,
    _initialized = false,
    _enabled = false,
    _teamCheck = false,
    _playerBoxEnabled = false,
    _skeletonEnabled = false,
    _objectBoxEnabled = false,
    _playerColor = Color3.fromRGB(210, 50, 80),
    _skeletonColor = Color3.fromRGB(210, 50, 80),
    _droneColor = Color3.fromRGB(0, 255, 255),
    _claymoreColor = Color3.fromRGB(255, 0, 0),
    _playerBoxes = {},
    _objectBoxes = {},
    _connections = {},
    _renderConn = nil,
    _teamCache = {},
    _lastCache = 0,
    _cacheInterval = 0.7,
}

function Module:setShared(shared)
    if type(shared) ~= "table" then
        return false, "shared must be table"
    end

    self.shared = shared

    local ref = shared.cloneref
    if type(ref) ~= "function" then
        ref = shared.ref
    end
    if type(ref) == "function" then
        RunService = ref(game:GetService("RunService"))
        Workspace = ref(game:GetService("Workspace"))
    end

    return true
end

local function disconnectAll(connections)
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end

local function getCamera()
    return Workspace.CurrentCamera
end

local SKELETON_CONNECTIONS = {
    { "head", "torso" },
    { "torso", "shoulder1" },
    { "shoulder1", "arm1" },
    { "torso", "shoulder2" },
    { "shoulder2", "arm2" },
    { "torso", "hip1" },
    { "hip1", "leg1" },
    { "torso", "hip2" },
    { "hip2", "leg2" },
}

function Module:_getObjectColor(name)
    if name == "Drone" then
        return self._droneColor
    elseif name == "Claymore" then
        return self._claymoreColor
    end
    return nil
end

function Module:_isOnScreen(worldPos)
    local camera = getCamera()
    if not camera then return false end
    local _, onScreen = camera:WorldToViewportPoint(worldPos)
    return onScreen
end

function Module:_isInFrustum(worldPos)
    local camera = getCamera()
    if not camera then return false end

    local relativePos = worldPos - camera.CFrame.Position
    local lookDir = camera.CFrame.LookVector
    if relativePos:Dot(lookDir) <= 0 then
        return false
    end

    local mag = relativePos.Magnitude
    if mag <= 0 then
        return true
    end
    local angle = math.acos(math.min(1, relativePos.Unit:Dot(lookDir)))
    return angle < math.rad(60)
end

function Module:_updateTeamCache()
    self._teamCache = {}
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("Highlight") and v.Adornee then
            self._teamCache[v.Adornee] = true
        end
    end
    self._lastCache = tick()
end

function Module:_isTeammate(model)
    if not self._teamCheck then
        return false
    end
    if tick() - self._lastCache > self._cacheInterval then
        self:_updateTeamCache()
    end
    return self._teamCache[model] == true
end

function Module:_newBox(color, thickness, transparency, zindex)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Filled = false
    box.Color = color
    box.Thickness = thickness
    box.Transparency = transparency
    box.ZIndex = zindex
    return box
end

function Module:_newLine(color, thickness, transparency, zindex)
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = color
    line.Thickness = thickness
    line.Transparency = transparency
    line.ZIndex = zindex
    return line
end

function Module:_getObjectBox2D(model)
    local camera = getCamera()
    if not camera then return nil end

    local cf, size = model:GetBoundingBox()
    if not self:_isInFrustum(cf.Position) or not self:_isOnScreen(cf.Position) then
        return nil
    end

    local half = size / 2
    local corners = {
        cf * Vector3.new(-half.X, -half.Y, -half.Z),
        cf * Vector3.new(-half.X, -half.Y, half.Z),
        cf * Vector3.new(-half.X, half.Y, -half.Z),
        cf * Vector3.new(-half.X, half.Y, half.Z),
        cf * Vector3.new(half.X, -half.Y, -half.Z),
        cf * Vector3.new(half.X, -half.Y, half.Z),
        cf * Vector3.new(half.X, half.Y, -half.Z),
        cf * Vector3.new(half.X, half.Y, half.Z),
    }

    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local anyVisible = false
    for _, corner in ipairs(corners) do
        local screenPos, onScreen = camera:WorldToViewportPoint(corner)
        if onScreen then
            anyVisible = true
            minX = math.min(minX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxX = math.max(maxX, screenPos.X)
            maxY = math.max(maxY, screenPos.Y)
        end
    end

    if not anyVisible then return nil end
    return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

function Module:_getPlayerBox2D(data)
    local camera = getCamera()
    if not camera then return nil end

    local head = data.head
    local torso = data.torso
    if not head or not torso or not data.isVisible then
        return nil
    end

    if not self:_isInFrustum(torso.Position) or not self:_isOnScreen(torso.Position) then
        return nil
    end

    local hsx, hsy = head.Size.X / 2, head.Size.Y / 2
    local tsx, tsy = torso.Size.X / 2, torso.Size.Y / 2
    local points = {
        head.Position + Vector3.new(-hsx, hsy, 0),
        head.Position + Vector3.new(hsx, hsy, 0),
        torso.Position + Vector3.new(-tsx, -tsy, 0),
        torso.Position + Vector3.new(tsx, -tsy, 0),
    }

    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local anyVisible = false
    for _, point in ipairs(points) do
        local screenPos, onScreen = camera:WorldToViewportPoint(point)
        if onScreen then
            anyVisible = true
            minX = math.min(minX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxX = math.max(maxX, screenPos.X)
            maxY = math.max(maxY, screenPos.Y)
        end
    end

    if not anyVisible then return nil end
    local padding = 3
    return Vector2.new(minX - padding, minY - padding), Vector2.new((maxX - minX) + padding * 2, (maxY - minY) + padding * 2)
end

function Module:_cleanupPlayerBox(model)
    local data = self._playerBoxes[model]
    if not data then return end

    if data.headConn then data.headConn:Disconnect() end
    if data.torsoConn then data.torsoConn:Disconnect() end
    if data.box then data.box:Remove() end
    if data.skeletonLines then
        for _, line in ipairs(data.skeletonLines) do
            if line then line:Remove() end
        end
    end
    self._playerBoxes[model] = nil
end

function Module:_cleanupObjectBox(model)
    local data = self._objectBoxes[model]
    if not data then return end
    if data.box then data.box:Remove() end
    self._objectBoxes[model] = nil
end

function Module:_createPlayerBox(model)
    if self._playerBoxes[model] or model.Name == "LocalViewmodel" then
        return
    end

    local head = model:FindFirstChild("head")
    local torso = model:FindFirstChild("torso")
    if not head or not torso then
        return
    end

    local data = {
        box = self:_newBox(self._playerColor, 2, 1, 2),
        head = head,
        torso = torso,
        isVisible = torso.Transparency <= 0.95,
        skeletonLines = {},
        skeletonParts = {},
    }

    for i = 1, #SKELETON_CONNECTIONS do
        data.skeletonLines[i] = self:_newLine(self._skeletonColor, 1.5, 1, 2)
    end

    for _, segment in ipairs(SKELETON_CONNECTIONS) do
        local aName, bName = segment[1], segment[2]
        if data.skeletonParts[aName] == nil then
            data.skeletonParts[aName] = model:FindFirstChild(aName)
        end
        if data.skeletonParts[bName] == nil then
            data.skeletonParts[bName] = model:FindFirstChild(bName)
        end
    end

    data.headConn = head:GetPropertyChangedSignal("Transparency"):Connect(function()
        local cached = self._playerBoxes[model]
        if cached then
            cached.isVisible = cached.torso and cached.torso.Transparency <= 0.95
        end
    end)

    data.torsoConn = torso:GetPropertyChangedSignal("Transparency"):Connect(function()
        local cached = self._playerBoxes[model]
        if cached then
            cached.isVisible = cached.torso and cached.torso.Transparency <= 0.95
        end
    end)

    self._playerBoxes[model] = data
end

function Module:_createObjectBox(model)
    if self._objectBoxes[model] then return end

    local color = self:_getObjectColor(model.Name)
    if not color then return end

    self._objectBoxes[model] = {
        box = self:_newBox(color, 1.5, 0.9, 3),
    }
end

function Module:_scanInitial()
    local vmFolder = Workspace:FindFirstChild("Viewmodels")
    if vmFolder then
        for _, model in ipairs(vmFolder:GetChildren()) do
            if model:IsA("Model") then
                self:_createPlayerBox(model)
            end
        end
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") then
            self:_createObjectBox(child)
        end
    end
end

function Module:_bindWorkspace()
    local vmFolder = Workspace:FindFirstChild("Viewmodels")
    if vmFolder then
        table.insert(self._connections, vmFolder.ChildAdded:Connect(function(model)
            if model:IsA("Model") then
                task.delay(0.25, function()
                    self:_createPlayerBox(model)
                end)
            end
        end))
    end

    table.insert(self._connections, Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Folder") and child.Name == "Viewmodels" then
            table.insert(self._connections, child.ChildAdded:Connect(function(model)
                if model:IsA("Model") then
                    task.delay(0.25, function()
                        self:_createPlayerBox(model)
                    end)
                end
            end))
            return
        end

        if child:IsA("Model") then
            self:_createObjectBox(child)
        end
    end))
end

function Module:_renderStep()
    if not self._enabled then
        for _, data in pairs(self._playerBoxes) do
            data.box.Visible = false
            if data.skeletonLines then
                for _, line in ipairs(data.skeletonLines) do
                    line.Visible = false
                end
            end
        end
        for _, data in pairs(self._objectBoxes) do data.box.Visible = false end
        return
    end

    if tick() - self._lastCache > self._cacheInterval then
        self:_updateTeamCache()
    end

    if self._playerBoxEnabled or self._skeletonEnabled then
        local camera = getCamera()
        for model, data in pairs(self._playerBoxes) do
            if not model:IsDescendantOf(Workspace) then
                self:_cleanupPlayerBox(model)
            elseif self:_isTeammate(model) then
                data.box.Visible = false
                if data.skeletonLines then
                    for _, line in ipairs(data.skeletonLines) do
                        line.Visible = false
                    end
                end
            else
                if self._playerBoxEnabled then
                    local pos, size = self:_getPlayerBox2D(data)
                    if pos and size then
                        data.box.Position = pos
                        data.box.Size = size
                        data.box.Visible = true
                    else
                        data.box.Visible = false
                    end
                else
                    data.box.Visible = false
                end

                if self._skeletonEnabled and data.isVisible and camera then
                    for i, segment in ipairs(SKELETON_CONNECTIONS) do
                        local line = data.skeletonLines and data.skeletonLines[i]
                        if line then
                            local partA = data.skeletonParts and data.skeletonParts[segment[1]]
                            local partB = data.skeletonParts and data.skeletonParts[segment[2]]
                            if partA and partB and partA:IsA("BasePart") and partB:IsA("BasePart") then
                                local a2D, aOn = camera:WorldToViewportPoint(partA.Position)
                                local b2D, bOn = camera:WorldToViewportPoint(partB.Position)
                                if aOn and bOn then
                                    line.From = Vector2.new(a2D.X, a2D.Y)
                                    line.To = Vector2.new(b2D.X, b2D.Y)
                                    line.Color = self._skeletonColor
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                            else
                                line.Visible = false
                            end
                        end
                    end
                elseif data.skeletonLines then
                    for _, line in ipairs(data.skeletonLines) do
                        line.Visible = false
                    end
                end
            end
        end
    else
        for _, data in pairs(self._playerBoxes) do
            data.box.Visible = false
            if data.skeletonLines then
                for _, line in ipairs(data.skeletonLines) do
                    line.Visible = false
                end
            end
        end
    end

    if self._objectBoxEnabled then
        for model, data in pairs(self._objectBoxes) do
            if not model:IsDescendantOf(Workspace) then
                self:_cleanupObjectBox(model)
            else
                local pos, size = self:_getObjectBox2D(model)
                if pos and size then
                    data.box.Position = pos
                    data.box.Size = size
                    data.box.Visible = true
                else
                    data.box.Visible = false
                end
            end
        end
    else
        for _, data in pairs(self._objectBoxes) do data.box.Visible = false end
    end
end

function Module:init(force)
    if self._initialized and not force then
        return true
    end

    if self._initialized and force then
        self:unload()
    end

    self._enabled = false
    self._teamCheck = false
    self._playerBoxEnabled = false
    self._skeletonEnabled = false
    self._objectBoxEnabled = false

    self:_updateTeamCache()
    self:_scanInitial()
    self:_bindWorkspace()

    self._renderConn = RunService.RenderStepped:Connect(function()
        self:_renderStep()
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
    return true
end

function Module:toggle()
    return self:setEnabled(not self._enabled)
end

function Module:setTeamCheck(state)
    self._teamCheck = state == true
    return true
end

function Module:setPlayerBoxEnabled(state)
    self._playerBoxEnabled = state == true
    if not self._playerBoxEnabled then
        for _, data in pairs(self._playerBoxes) do data.box.Visible = false end
    end
    return true
end

function Module:setSkeletonEnabled(state)
    self._skeletonEnabled = state == true
    if not self._skeletonEnabled then
        for _, data in pairs(self._playerBoxes) do
            if data.skeletonLines then
                for _, line in ipairs(data.skeletonLines) do
                    line.Visible = false
                end
            end
        end
    end
    return true
end

function Module:setObjectBoxEnabled(state)
    self._objectBoxEnabled = state == true
    if not self._objectBoxEnabled then
        for _, data in pairs(self._objectBoxes) do data.box.Visible = false end
    end
    return true
end

function Module:setPlayerColor(color)
    if typeof(color) ~= "Color3" then
        return false, "invalid color"
    end
    self._playerColor = color
    for _, data in pairs(self._playerBoxes) do
        data.box.Color = color
    end
    return true
end

function Module:setSkeletonColor(color)
    if typeof(color) ~= "Color3" then
        return false, "invalid color"
    end
    self._skeletonColor = color
    for _, data in pairs(self._playerBoxes) do
        if data.skeletonLines then
            for _, line in ipairs(data.skeletonLines) do
                line.Color = color
            end
        end
    end
    return true
end

function Module:setObjectColor(color)
    if typeof(color) ~= "Color3" then
        return false, "invalid color"
    end
    self._droneColor = color
    self._claymoreColor = color
    for _, data in pairs(self._objectBoxes) do
        data.box.Color = color
    end
    return true
end

function Module:setDroneColor(color)
    if typeof(color) ~= "Color3" then return false, "invalid color" end
    self._droneColor = color
    for model, data in pairs(self._objectBoxes) do
        if model.Name == "Drone" then data.box.Color = color end
    end
    return true
end

function Module:setClaymoreColor(color)
    if typeof(color) ~= "Color3" then return false, "invalid color" end
    self._claymoreColor = color
    for model, data in pairs(self._objectBoxes) do
        if model.Name == "Claymore" then data.box.Color = color end
    end
    return true
end

function Module:unload()
    self._enabled = false
    if self._renderConn then
        self._renderConn:Disconnect()
        self._renderConn = nil
    end

    disconnectAll(self._connections)

    for model in pairs(self._playerBoxes) do
        self:_cleanupPlayerBox(model)
    end
    for model in pairs(self._objectBoxes) do
        self:_cleanupObjectBox(model)
    end

    self._playerBoxes = {}
    self._objectBoxes = {}
    self._initialized = false
    return true
end

return Module

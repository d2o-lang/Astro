pcall(function() setthreadidentity(8) end)

local UILIB_LOCAL_PATH = "ui_lib.lua"
local UILIB_URL = "https://github.com/PLU3t0/Meathead/raw/refs/heads/main/OperationOne-main/ui_lib.lua"
local UILIB_LOCAL_PATHS = {
    UILIB_LOCAL_PATH,
    "OperationOne-main/ui_lib.lua",
    "OperationOne-main\\ui_lib.lua",
}
local SHARED_RUNTIME_SOURCE = { local_path = "shared_runtime.lua", url = "https://github.com/PLU3t0/Meathead/raw/refs/heads/main/OperationOne-main/shared_runtime.lua" }

local MODULE_SOURCES = {
    fullbright = {
        local_path = "fullbright.lua",
        url = "https://github.com/PLU3t0/Meathead/raw/refs/heads/main/OperationOne-main/fullbright.lua",
    },
    gun_modification = {
        local_path = "gun_modification.lua",
        url = "https://github.com/PLU3t0/Meathead/raw/refs/heads/main/OperationOne-main/gun_modification.lua",
    },
    EspLib = {
        local_path = "EspLib.lua",
        url = "https://github.com/d2o-lang/UILib/raw/refs/heads/main/EspLib.lua",
    },
    silent_aim = {
        local_path = "silent_aim.lua",
        url = "https://github.com/PLU3t0/Meathead/raw/refs/heads/main/OperationOne-main/silent_aim.lua",
    },
    yenofurry = {
        local_path = "yenofurry.lua",
        url = "https://github.com/d2o-lang/UILib/raw/refs/heads/main/yenofurry.lua",
    },
}

local moduleCache = {}
local sharedRuntimeCache = nil
local ESP_MODULE_NAME = "EspLib"

local function log(msg)
    print("[OP1] " .. tostring(msg))
end

local function compile(source, chunkName)
    local compiler = loadstring or load
    if type(compiler) ~= "function" then
        return nil, "loadstring/load unavailable"
    end

    local okLoad, chunkOrErr = pcall(compiler, source, "@" .. tostring(chunkName))
    if not okLoad or type(chunkOrErr) ~= "function" then
        return nil, "compile error: " .. tostring(chunkOrErr)
    end

    local okRun, resultOrErr = pcall(chunkOrErr)
    if not okRun then
        return nil, "runtime error: " .. tostring(resultOrErr)
    end

    if type(resultOrErr) == "table" then
        return resultOrErr
    end

    return { load = function() return true end }
end

local function readSource(spec)
    if type(readfile) == "function" and spec.local_path then
        local okLocal, localData = pcall(readfile, spec.local_path)
        if okLocal and type(localData) == "string" and localData ~= "" then
            return localData, "local:" .. spec.local_path
        end
    end

    if spec.url and spec.url ~= "" then
        local okUrl, remoteData = pcall(function()
            return game:HttpGet(spec.url)
        end)
        if okUrl and type(remoteData) == "string" and remoteData ~= "" then
            return remoteData, "url:" .. spec.url
        end
    end

    return nil, "no source available"
end

local function loadSharedRuntime()
    if type(sharedRuntimeCache) == "table" then
        return sharedRuntimeCache
    end

    local source, sourceInfo = readSource(SHARED_RUNTIME_SOURCE)
    if not source then
        log("shared runtime source error -> " .. tostring(sourceInfo))
        return nil
    end

    local sharedObj, sharedErr = compile(source, "shared_runtime")
    if not sharedObj or type(sharedObj) ~= "table" then
        log("shared runtime load error -> " .. tostring(sharedErr))
        return nil
    end

    sharedRuntimeCache = sharedObj
    if type(sharedObj.applyToEnv) == "function" then
        pcall(function()
            sharedObj:applyToEnv()
        end)
    end
    return sharedRuntimeCache
end

local function initModule(name, forceReload)
    local cached = moduleCache[name]
    if cached and cached.initialized and not forceReload then
        return cached.module
    end

    local sharedRuntime = loadSharedRuntime()

    local spec = MODULE_SOURCES[name]
    if not spec then
        log("unknown module: " .. tostring(name))
        return nil
    end

    local source, sourceInfo = readSource(spec)
    if not source then
        log(name .. " source error -> " .. tostring(sourceInfo))
        return nil
    end

    local moduleObj, loadErr = compile(source, name)
    if not moduleObj then
        log(name .. " load error -> " .. tostring(loadErr))
        return nil
    end

    if sharedRuntime then
        if type(moduleObj.setShared) == "function" then
            pcall(function()
                moduleObj:setShared(sharedRuntime)
            end)
        elseif type(moduleObj) == "table" and moduleObj.shared == nil then
            moduleObj.shared = sharedRuntime
        end
    end

    local okInit, initErr = true, nil
    if type(moduleObj.load) == "function" then
        okInit, initErr = moduleObj:load(forceReload == true)
    elseif type(moduleObj.init) == "function" then
        okInit, initErr = moduleObj:init(forceReload == true)
    end

    if okInit == false then
        log(name .. " init failed -> " .. tostring(initErr))
        return nil
    end

    moduleCache[name] = { initialized = true, module = moduleObj }
    return moduleObj
end

local function withModule(name, callback)
    local moduleObj = initModule(name, false)
    if not moduleObj then
        return false
    end

    local ok, result = pcall(callback, moduleObj)
    if not ok then
        log(name .. " callback error -> " .. tostring(result))
        return false
    end

    return result ~= false
end

local function setSilentAim(state)
    withModule("silent_aim", function(m)
        if type(m.setEnabled) == "function" then
            m:setEnabled(state)
        end
    end)
end

local function setSilentAimFov(value)
    withModule("silent_aim", function(m)
        if type(m.setFov) == "function" then
            m:setFov(value)
        end
    end)
end

local function setSilentAimSmoothness(value)
    withModule("silent_aim", function(m)
        if type(m.setSmoothness) == "function" then
            m:setSmoothness(value)
        end
    end)
end

local function setSilentAimMode(mode)
    withModule("silent_aim", function(m)
        if type(m.setMode) == "function" then
            m:setMode(mode)
        end
    end)
end

local function setAimAssistActivation(mode)
    withModule("silent_aim", function(m)
        if type(m.setAimAssistActivation) == "function" then
            m:setAimAssistActivation(mode)
        end
    end)
end

local function setSilentAimTargetMode(mode)
    withModule("silent_aim", function(m)
        if type(m.setTargetMode) == "function" then
            m:setTargetMode(mode)
        end
    end)
end

local function setSilentAimTeamCheck(state)
    withModule("silent_aim", function(m)
        if type(m.setTeamCheck) == "function" then
            m:setTeamCheck(state)
        end
    end)
end

local function setSilentAimTargetGadgets(state)
    withModule("silent_aim", function(m)
        if type(m.setTargetGadgets) == "function" then
            m:setTargetGadgets(state)
        end
    end)
end

local function setSilentAimVisibleCheck(state)
    withModule("silent_aim", function(m)
        if type(m.setVisibleCheck) == "function" then
            m:setVisibleCheck(state)
        end
    end)
end

local function setSilentAimFovCircleVisual(state)
    withModule("silent_aim", function(m)
        if type(m.setFovCircleVisible) == "function" then
            m:setFovCircleVisible(state)
        end
    end)
end

local function setGunModEnabled(state)
    withModule("gun_modification", function(m)
        if type(m.setEnabled) == "function" then
            m:setEnabled(state)
        end
    end)
end

local function setGunModConfig(key, value)
    withModule("gun_modification", function(m)
        if type(m.updateConfig) == "function" then
            m:updateConfig({ [key] = value })
        elseif type(m.config) == "table" then
            m.config[key] = value
        end
    end)
end

local function setEspEnabled(state)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setEnabled) == "function" then
            m:setEnabled(state)
        elseif m.Enabled ~= nil then
            m.Enabled = state == true
        end
    end)
end

local function setEspTeamCheck(state)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setTeamCheck) == "function" then
            m:setTeamCheck(state)
        elseif m.Drawing and m.Drawing.TeamCheck then
            m.Drawing.TeamCheck.Enabled = state == true
        end
    end)
end

local function setEspPlayers(state)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setPlayerBoxEnabled) == "function" then
            m:setPlayerBoxEnabled(state)
        elseif m.Drawing and m.Drawing.Boxes and m.Drawing.Boxes.Full then
            m.Drawing.Boxes.Full.Enabled = state == true
        end
    end)
end

local function setEspCorners(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes and m.Drawing.Boxes.Corner then
            m.Drawing.Boxes.Corner.Enabled = state == true
        end
    end)
end

local function setEspFilled(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes and m.Drawing.Boxes.Filled then
            m.Drawing.Boxes.Filled.Enabled = state == true
        end
    end)
end

local function setEspBoxGradient(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.Gradient = state == true
        end
    end)
end

local function setEspBoxAnimate(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.Animate = state == true
        end
    end)
end

local function setEspBoxGradientFill(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.GradientFill = state == true
        end
    end)
end

local function setEspHealthBar(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.HealthBar then
            m.Drawing.HealthBar.Enabled = state == true
        end
    end)
end

local function setEspSkeleton(state)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setSkeletonEnabled) == "function" then
            m:setSkeletonEnabled(state)
        elseif type(m.ToggleSkeleton) == "function" then
            m.ToggleSkeleton(state)
        elseif m.Drawing and m.Drawing.Skeleton then
            m.Drawing.Skeleton.Enabled = state == true
        end
    end)
end

local function setEspNames(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Names then
            m.Drawing.Names.Enabled = state == true
        end
    end)
end

local function setEspDistances(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Distances then
            m.Drawing.Distances.Enabled = state == true
        end
    end)
end

local function setEspWeapons(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Weapons then
            m.Drawing.Weapons.Enabled = state == true
        end
    end)
end

local function setEspChams(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.Enabled = state == true
        end
    end)
end

local function setEspChamsThermal(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.Thermal = state == true
        end
    end)
end

local function setEspChamsVisibleCheck(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.VisibleCheck = state == true
        end
    end)
end

local function setEspFadeOut(state)
    withModule(ESP_MODULE_NAME, function(m)
        if m.FadeOut then
            m.FadeOut.OnDistance = state == true
        end
    end)
end

local function setEspMaxDistance(value)
    withModule(ESP_MODULE_NAME, function(m)
        if m.MaxDistance ~= nil then
            m.MaxDistance = tonumber(value) or m.MaxDistance
        end
    end)
end

local function setEspFontSize(value)
    withModule(ESP_MODULE_NAME, function(m)
        if m.FontSize ~= nil then
            m.FontSize = math.floor(tonumber(value) or m.FontSize)
        end
    end)
end

local function setEspCornerThickness(value)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.SetCornerThickness) == "function" then
            m.SetCornerThickness(value)
        elseif m.Drawing and m.Drawing.Boxes and m.Drawing.Boxes.Corner then
            m.Drawing.Boxes.Corner.Thickness = tonumber(value) or m.Drawing.Boxes.Corner.Thickness
        end
    end)
end

local function setEspCornerLength(value)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.SetCornerLength) == "function" then
            m.SetCornerLength(value)
        elseif m.Drawing and m.Drawing.Boxes and m.Drawing.Boxes.Corner then
            m.Drawing.Boxes.Corner.Length = tonumber(value) or m.Drawing.Boxes.Corner.Length
        end
    end)
end

local function setEspSkeletonThickness(value)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setSkeletonThickness) == "function" then
            m:setSkeletonThickness(value)
        elseif type(m.SetSkeletonThickness) == "function" then
            m.SetSkeletonThickness(value)
        elseif m.Drawing and m.Drawing.Skeleton then
            m.Drawing.Skeleton.Thickness = tonumber(value) or m.Drawing.Skeleton.Thickness
        end
    end)
end

local function setEspBoxRotationSpeed(value)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.RotationSpeed = tonumber(value) or m.Drawing.Boxes.RotationSpeed
        end
    end)
end

local function setEspFilledTransparency(value)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes and m.Drawing.Boxes.Filled then
            m.Drawing.Boxes.Filled.Transparency = tonumber(value) or m.Drawing.Boxes.Filled.Transparency
        end
    end)
end

local function setEspChamsFillTransparency(value)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.Fill_Transparency = tonumber(value) or m.Drawing.Chams.Fill_Transparency
        end
    end)
end

local function setEspChamsOutlineTransparency(value)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.Outline_Transparency = tonumber(value) or m.Drawing.Chams.Outline_Transparency
        end
    end)
end

local function setEspPlayerColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setPlayerColor) == "function" then
            m:setPlayerColor(color)
        elseif m.Drawing and m.Drawing.Boxes then
            if m.Drawing.Boxes.Corner then m.Drawing.Boxes.Corner.RGB = color end
            if m.Drawing.Boxes.Full then m.Drawing.Boxes.Full.RGB = color end
            m.Drawing.Boxes.GradientRGB1 = color
            m.Drawing.Boxes.GradientFillRGB1 = color
        end
    end)
end

local function setEspGradientEndColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.GradientRGB2 = color
        end
    end)
end

local function setEspFillGradientStartColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.GradientFillRGB1 = color
        end
    end)
end

local function setEspFillGradientEndColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Boxes then
            m.Drawing.Boxes.GradientFillRGB2 = color
        end
    end)
end

local function setEspNameColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Names then
            m.Drawing.Names.RGB = color
        end
    end)
end

local function setEspSkeletonColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.setSkeletonColor) == "function" then
            m:setSkeletonColor(color)
        elseif type(m.SetSkeletonColor) == "function" then
            m.SetSkeletonColor(color)
        elseif m.Drawing and m.Drawing.Skeleton then
            m.Drawing.Skeleton.RGB = color
        end
    end)
end

local function setEspWeaponColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Weapons then
            m.Drawing.Weapons.RGB = color
        end
    end)
end

local function setEspDistanceColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Distances then
            m.Drawing.Distances.RGB = color
        end
    end)
end

local function setEspChamsFillColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.FillRGB = color
        end
    end)
end

local function setEspChamsOutlineColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if m.Drawing and m.Drawing.Chams then
            m.Drawing.Chams.OutlineRGB = color
        end
    end)
end


local function setEspDroneEnabled(state)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.ToggleDroneChams) == "function" then
            m.ToggleDroneChams(state)
        elseif m.ObjectChams and m.ObjectChams.Drones then
            m.ObjectChams.Drones.Enabled = state == true
        end
    end)
end

local function setEspClaymoreEnabled(state)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.ToggleClaymoreChams) == "function" then
            m.ToggleClaymoreChams(state)
        elseif m.ObjectChams and m.ObjectChams.Claymores then
            m.ObjectChams.Claymores.Enabled = state == true
        end
    end)
end


local function setEspGadgetsEnabled(state)
    setEspDroneEnabled(state)
    setEspClaymoreEnabled(state)
end

local function setEspDroneColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.SetDroneChamsFill) == "function" then m.SetDroneChamsFill(color) end
        if type(m.SetDroneChamsOutline) == "function" then m.SetDroneChamsOutline(color) end
        if m.ObjectChams and m.ObjectChams.Drones then
            m.ObjectChams.Drones.FillRGB = color
            m.ObjectChams.Drones.OutlineRGB = color
        end
    end)
end

local function setEspClaymoreColor(color)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.SetClaymoreChamsFill) == "function" then m.SetClaymoreChamsFill(color) end
        if type(m.SetClaymoreChamsOutline) == "function" then m.SetClaymoreChamsOutline(color) end
        if m.ObjectChams and m.ObjectChams.Claymores then
            m.ObjectChams.Claymores.FillRGB = color
            m.ObjectChams.Claymores.OutlineRGB = color
        end
    end)
end

local function setEspDroneTransparency(value)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.SetDroneChamsFill) == "function" then m.SetDroneChamsFill(nil, value) end
        if m.ObjectChams and m.ObjectChams.Drones then
            m.ObjectChams.Drones.FillTrans = value
        end
    end)
end

local function setEspClaymoreTransparency(value)
    withModule(ESP_MODULE_NAME, function(m)
        if type(m.SetClaymoreChamsFill) == "function" then m.SetClaymoreChamsFill(nil, value) end
        if m.ObjectChams and m.ObjectChams.Claymores then
            m.ObjectChams.Claymores.FillTrans = value
        end
    end)
end

local function setFullbright(state)
    withModule("fullbright", function(m)
        if type(m.setEnabled) == "function" then
            m:setEnabled(state)
        elseif type(m.toggle) == "function" then
            m:toggle()
        end
    end)
end

local function setFullbrightSetting(key, value)
    withModule("fullbright", function(m)
        if type(m.setSetting) == "function" then
            m:setSetting(key, value)
        end
    end)
end

local function applyDefaults()
    setSilentAim(false)
    setSilentAimFov(60)
    setSilentAimSmoothness(1)
    setSilentAimMode("silent")
    setSilentAimTeamCheck(true)
    setAimAssistActivation("mb2")
    setSilentAimTargetMode("custom_parts")
    setSilentAimTargetGadgets(false)
    setSilentAimVisibleCheck(false)
    setSilentAimFovCircleVisual(true)

    setGunModEnabled(false)
    setGunModConfig("recoil_reduction", 0)
    setGunModConfig("horizontal_recoil", 0)
    setGunModConfig("no_spread", false)
    setGunModConfig("force_auto", false)

    setEspEnabled(false)
    setEspTeamCheck(false)
    setEspPlayers(false)
    setEspCorners(false)
    setEspFilled(false)
    setEspBoxGradient(true)
    setEspBoxAnimate(false)
    setEspBoxGradientFill(true)
    setEspHealthBar(false)
    setEspSkeleton(false)
    setEspFadeOut(false)
    setEspNames(false)
    setEspDistances(false)
    setEspWeapons(false)
    setEspChams(false)
    setEspChamsThermal(false)
    setEspChamsVisibleCheck(false)
    setEspMaxDistance(1000)
    setEspFontSize(11)
    setEspCornerThickness(1)
    setEspCornerLength(15)
    setEspSkeletonThickness(1)
    setEspBoxRotationSpeed(300)
    setEspFilledTransparency(0.75)
    setEspChamsFillTransparency(50)
    setEspChamsOutlineTransparency(50)
    setEspPlayerColor(Color3.fromRGB(255, 255, 255))
    setEspGradientEndColor(Color3.fromRGB(0, 0, 0))
    setEspFillGradientStartColor(Color3.fromRGB(255, 255, 255))
    setEspFillGradientEndColor(Color3.fromRGB(0, 0, 0))
    setEspSkeletonColor(Color3.fromRGB(255, 255, 255))
    setEspNameColor(Color3.fromRGB(255, 255, 255))
    setEspDistanceColor(Color3.fromRGB(255, 255, 255))
    setEspWeaponColor(Color3.fromRGB(255, 255, 255))
    setEspChamsFillColor(Color3.fromRGB(255, 80, 80))
    setEspChamsOutlineColor(Color3.fromRGB(255, 255, 255))
    setEspGadgetsEnabled(false)
    setEspDroneEnabled(false)
    setEspClaymoreEnabled(false)
    setEspDroneTransparency(0.5)
    setEspClaymoreTransparency(0.5)
    setEspDroneColor(Color3.fromRGB(0, 255, 255))
    setEspClaymoreColor(Color3.fromRGB(255, 0, 0))

    setFullbright(false)
    setFullbrightSetting("Brightness", 1)
    setFullbrightSetting("ClockTime", 12)
    setFullbrightSetting("FogEnd", 786543)
    setFullbrightSetting("GlobalShadows", false)
    setFullbrightSetting("Ambient", Color3.fromRGB(178, 178, 178))

end

local function runStartupInit()
    local initOrder = { "silent_aim", "gun_modification", ESP_MODULE_NAME, "fullbright", "yenofurry" }
    for _, name in ipairs(initOrder) do
        initModule(name, false)
    end
    applyDefaults()
    log("init complete")
end

local function loadUiLibrary()
    local compiler = loadstring or load
    if type(compiler) ~= "function" then
        return nil, "loadstring/load unavailable"
    end

    local function loadUiFromSource(source, sourceLabel)
        source = tostring(source)
        source = source:gsub("â€¢", "-"):gsub("•", "-")
        source = source:gsub("â€”", "-"):gsub("—", "-")
        source = source:gsub("â–¾", "v"):gsub("▾", "v")

        local okLib, libOrErr = pcall(function()
            local chunk = compiler(source, "@uilib:" .. tostring(sourceLabel))
            if type(chunk) ~= "function" then
                error("ui compile returned non-function")
            end
            return chunk()
        end)
        if okLib and type(libOrErr) == "table" then
            return libOrErr
        end
        return nil, tostring(libOrErr)
    end

    if type(readfile) == "function" then
        for _, localPath in ipairs(UILIB_LOCAL_PATHS) do
            local okRead, source = pcall(readfile, localPath)
            if okRead and type(source) == "string" and source ~= "" then
                local lib, err = loadUiFromSource(source, "local:" .. localPath)
                if lib then
                    log("UI loaded from local file: " .. localPath)
                    return lib
                end
                log("UI local load failed (" .. tostring(localPath) .. ") -> " .. tostring(err))
            end
        end
    end

    local okHttp, httpSource = pcall(function()
        return game:HttpGet(UILIB_URL)
    end)
    if okHttp and type(httpSource) == "string" and httpSource ~= "" then
        local lib, err = loadUiFromSource(httpSource, "url:" .. UILIB_URL)
        if lib then
            log("UI loaded from url: " .. UILIB_URL)
            return lib
        end
        return nil, "ui url compile/runtime error: " .. tostring(err)
    end

    return nil, "local ui file missing (" .. UILIB_LOCAL_PATH .. ") and url fetch failed: " .. UILIB_URL
end

local function buildAkUi(lib)
    if type(lib.new) ~= "function" then
        error("ui_lib.lua does not expose .new")
    end

    local window = lib.new("Op1NIGGAs", Enum.KeyCode.RightShift)
    window._userResized = true
    window._manualWidth = 400
    window._manualHeight = 200
    window.mainFrame.Size = UDim2.new(0, 400, 0, 200)
    window:_updateScroll()
    if type(window.setConfigFolder) == "function" then
        window:setConfigFolder("FURRY KILLER CONFIG")
    end


    local presetColors = {
        Red = Color3.fromRGB(255, 0, 0),
        Green = Color3.fromRGB(0, 255, 0),
        Blue = Color3.fromRGB(0, 0, 255),
        Cyan = Color3.fromRGB(0, 255, 255),
        Yellow = Color3.fromRGB(255, 255, 0),
        Orange = Color3.fromRGB(255, 165, 0),
        Pink = Color3.fromRGB(255, 192, 203),
        White = Color3.fromRGB(255, 255, 255),
        Gray = Color3.fromRGB(178, 178, 178),
    }
    local colorNames = { "Red", "Green", "Blue", "Cyan", "Yellow", "Orange", "Pink", "White", "Gray" }

    local function nearestColorName(target)
        local bestName, bestDist = "White", math.huge
        for name, c in pairs(presetColors) do
            local dr = target.R - c.R
            local dg = target.G - c.G
            local db = target.B - c.B
            local dist = dr * dr + dg * dg + db * db
            if dist < bestDist then
                bestDist = dist
                bestName = name
            end
        end
        return bestName
    end

    local function addPresetColorDropdown(name, defaultColor, callback)
        window:addDropdown(name, colorNames, nearestColorName(defaultColor), function(selected)
            callback(presetColors[selected] or defaultColor)
        end)
    end

    local combatTab = window:addTab("Combat")
    window:switchTab(combatTab)
    window:addSection("Aimbot")
    window:addToggle("Silent/Aimbot", false, setSilentAim)
    window:addToggle("Aim Team Check", true, setSilentAimTeamCheck)
    window:addToggle("Aim Visible Check", false, setSilentAimVisibleCheck)
    window:addToggle("FOV Circle Visual", true, setSilentAimFovCircleVisual)
    window:addSlider("Aim FOV", 10, 400, 60, 1, setSilentAimFov)
    window:addSlider("Aim Assist Smoothness", 0.01, 1, 1, 0.01, setSilentAimSmoothness)
    window:addDropdown("Aim Mode", { "silent", "aim_assist" }, "silent", function(selected)
        setSilentAimMode(selected)
    end)
    window:addDropdown("Aim Assist Activation", { "mb2", "mb1", "always", "mobile" }, "mb2", function(selected)
        setAimAssistActivation(selected)
    end)
    window:addDropdown("Target Mode", { "Custom Parts", "Head Only" }, "Custom Parts", function(selected)
        if selected == "Head Only" then
            setSilentAimTargetMode("head_only")
        else
            setSilentAimTargetMode("custom_parts")
        end
    end)
    window:addToggle("Target Gadgets", false, setSilentAimTargetGadgets)

    window:addSection("Weapon")
    window:addToggle("Gun Mod Enabled", false, setGunModEnabled)
    window:addSlider("Recoil Reduction", 0, 1, 0, 0.1, function(v) setGunModConfig("recoil_reduction", v) end)
    window:addSlider("Horizontal Recoil", 0, 1, 0, 0.1, function(v) setGunModConfig("horizontal_recoil", v) end)
    window:addToggle("No Spread", false, function(v) setGunModConfig("no_spread", v) end)
    window:addToggle("Automatic", false, function(v) setGunModConfig("force_auto", v) end)

    local visualsTab = window:addTab("Visuals")
    window:switchTab(visualsTab)
    window:addSection("ESP")
    window:addToggle("ESP Enabled", false, setEspEnabled)
    window:addToggle("ESP Team Check", false, setEspTeamCheck)
    window:addToggle("Box ESP (Full)", false, setEspPlayers)
    window:addToggle("Box ESP (Corner)", false, setEspCorners)
    window:addToggle("Box Fill", false, setEspFilled)
    window:addToggle("Box Gradient", true, setEspBoxGradient)
    window:addToggle("Box Animate", false, setEspBoxAnimate)
    window:addToggle("Box Fill Gradient", true, setEspBoxGradientFill)
    window:addToggle("Health Bar", false, setEspHealthBar)
    window:addToggle("Skeleton ESP", false, setEspSkeleton)
    window:addToggle("Name ESP", false, setEspNames)
    window:addToggle("Distance ESP", false, setEspDistances)
    window:addToggle("Weapon ESP", false, setEspWeapons)
    window:addToggle("Chams", false, setEspChams)
    window:addToggle("Chams Thermal", false, setEspChamsThermal)
    window:addToggle("Chams Visible Check", false, setEspChamsVisibleCheck)

    window:addSlider("ESP Max Distance", 100, 3000, 1000, 10, setEspMaxDistance)
    --window:addToggle("Fade Out (Distance)", false, setEspFadeOut)
    window:addSlider("ESP Font Size", 8, 24, 11, 1, setEspFontSize)
    window:addSlider("Corner Thickness", 1, 5, 1, 1, setEspCornerThickness)
    window:addSlider("Corner Length", 5, 35, 15, 1, setEspCornerLength)
    window:addSlider("Skeleton Thickness", 1, 5, 1, 1, setEspSkeletonThickness)
    window:addSlider("Box Rotation Speed", 0, 1000, 300, 10, setEspBoxRotationSpeed)
    window:addSlider("Box Fill Transparency", 0, 1, 0.75, 0.01, setEspFilledTransparency)
    window:addSlider("Chams Fill Transparency", 0, 100, 50, 1, setEspChamsFillTransparency)
    window:addSlider("Chams Outline Transparency", 0, 100, 50, 1, setEspChamsOutlineTransparency)

    addPresetColorDropdown("Player ESP Color", Color3.fromRGB(210, 50, 80), setEspPlayerColor)
    addPresetColorDropdown("Box Gradient End", Color3.fromRGB(0, 0, 0), setEspGradientEndColor)
    addPresetColorDropdown("Fill Gradient Start", Color3.fromRGB(255, 255, 255), setEspFillGradientStartColor)
    addPresetColorDropdown("Fill Gradient End", Color3.fromRGB(0, 0, 0), setEspFillGradientEndColor)
    addPresetColorDropdown("Name Color", Color3.fromRGB(255, 255, 255), setEspNameColor)
    addPresetColorDropdown("Skeleton Color", Color3.fromRGB(210, 50, 80), setEspSkeletonColor)
    addPresetColorDropdown("Distance Color", Color3.fromRGB(255, 255, 255), setEspDistanceColor)
    addPresetColorDropdown("Weapon Color", Color3.fromRGB(255, 255, 255), setEspWeaponColor)
    addPresetColorDropdown("Chams Fill Color", Color3.fromRGB(243, 116, 166), setEspChamsFillColor)
    addPresetColorDropdown("Chams Outline Color", Color3.fromRGB(243, 116, 166), setEspChamsOutlineColor)

    local gadgetTab = window:addTab("ESP Gadgets")
    window:switchTab(gadgetTab)
    window:addSection("Gadgets")
    window:addToggle("Drone Chams", false, setEspDroneEnabled)
    window:addToggle("Claymore Chams", false, setEspClaymoreEnabled)
    window:addSlider("Drone Transparency", 0, 1, 0.5, 0.01, setEspDroneTransparency)
    window:addSlider("Claymore Transparency", 0, 1, 0.5, 0.01, setEspClaymoreTransparency)
    addPresetColorDropdown("Drone Color", Color3.fromRGB(0, 255, 255), setEspDroneColor)
    addPresetColorDropdown("Claymore Color", Color3.fromRGB(255, 0, 0), setEspClaymoreColor)

    window:switchTab(visualsTab)
    window:addSection("Lighting")
    window:addToggle("Fullbright", false, setFullbright)
    window:addSlider("FB Brightness", 0, 5, 1, 0.01, function(v) setFullbrightSetting("Brightness", v) end)
    window:addSlider("FB ClockTime", 0, 24, 12, 1, function(v) setFullbrightSetting("ClockTime", v) end)
    window:addSlider("FB FogEnd", 1000, 1000000, 786543, 1, function(v) setFullbrightSetting("FogEnd", v) end)
    window:addToggle("FB GlobalShadows", false, function(v) setFullbrightSetting("GlobalShadows", v) end)
    addPresetColorDropdown("FB Ambient Color", Color3.fromRGB(178, 178, 178), function(c)
        setFullbrightSetting("Ambient", c)
    end)

    local configTab = window:addTab("Config")
    window:switchTab(configTab)
    if type(window.addConfigManager) == "function" then
        window:addConfigManager("default")
    else
        window:addLabel("Config manager unavailable")
    end
    window:switchTab(combatTab)

    window:onClose(function()
        setSilentAim(false)
        setEspEnabled(false)
        setEspGadgetsEnabled(false)
        setFullbright(false)
        setGunModEnabled(false)
    end)

end

local lib, libErr = loadUiLibrary()
if lib then
    local okInit, initErr = pcall(runStartupInit)
    if not okInit then
        log("startup init failed -> " .. tostring(initErr))
    end

    local ok, err = pcall(buildAkUi, lib)
    if not ok then
        log("failed -> " .. tostring(err))
    end
else
    log("failed -> " .. tostring(libErr))
end

pcall(function()
    game:GetService("WebViewService"):Destroy()
end)

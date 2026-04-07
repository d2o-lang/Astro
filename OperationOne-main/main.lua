pcall(function() setthreadidentity(8) end)

local UILIB_LOCAL_PATH = "ui_lib.lua"
local UILIB_URL = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/ui_lib.lua"
local UILIB_LOCAL_PATHS = {
    UILIB_LOCAL_PATH,
    "OperationOne-main/ui_lib.lua",
    "OperationOne-main\\ui_lib.lua",
}
local SHARED_RUNTIME_SOURCE = { local_path = "shared_runtime.lua", url = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/shared_runtime.lua" }

local MODULE_SOURCES = {
    fullbright = {
        local_path = "fullbright.lua",
        url = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/fullbright.lua",
    },
    gun_modification = {
        local_path = "gun_modification.lua",
        url = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/gun_modification.lua",
    },
    player_esp_gadgets = {
        local_path = "player_esp_gadgets.lua",
        url = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/player_esp_gadgets.lua",
    },
    silent_aim = {
        local_path = "silent_aim.lua",
        url = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/silent_aim.lua",
    },
}

local moduleCache = {}
local sharedRuntimeCache = nil

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
    withModule("player_esp_gadgets", function(m)
        if type(m.setEnabled) == "function" then
            m:setEnabled(state)
        end
    end)
end

local function setEspTeamCheck(state)
    withModule("player_esp_gadgets", function(m)
        if type(m.setTeamCheck) == "function" then
            m:setTeamCheck(state)
        end
    end)
end

local function setEspPlayers(state)
    withModule("player_esp_gadgets", function(m)
        if type(m.setPlayerBoxEnabled) == "function" then
            m:setPlayerBoxEnabled(state)
        end
    end)
end

local function setEspObjects(state)
    withModule("player_esp_gadgets", function(m)
        if type(m.setObjectBoxEnabled) == "function" then
            m:setObjectBoxEnabled(state)
        end
    end)
end

local function setEspPlayerColor(color)
    withModule("player_esp_gadgets", function(m)
        if type(m.setPlayerColor) == "function" then
            m:setPlayerColor(color)
        end
    end)
end

local function setEspObjectColor(color)
    withModule("player_esp_gadgets", function(m)
        if type(m.setObjectColor) == "function" then
            m:setObjectColor(color)
        end
    end)
end

local function setEspDroneColor(color)
    withModule("player_esp_gadgets", function(m)
        if type(m.setDroneColor) == "function" then
            m:setDroneColor(color)
        end
    end)
end

local function setEspClaymoreColor(color)
    withModule("player_esp_gadgets", function(m)
        if type(m.setClaymoreColor) == "function" then
            m:setClaymoreColor(color)
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
    setAimAssistActivation("mb2")
    setSilentAimTargetMode("custom_parts")

    setGunModEnabled(false)
    setGunModConfig("recoil_reduction", 0)
    setGunModConfig("horizontal_recoil", 0)

    setEspEnabled(false)
    setEspTeamCheck(false)
    setEspPlayers(false)
    setEspObjects(false)
    setEspPlayerColor(Color3.fromRGB(210, 50, 80))
    setEspObjectColor(Color3.fromRGB(0, 255, 255))
    setEspDroneColor(Color3.fromRGB(0, 255, 255))
    setEspClaymoreColor(Color3.fromRGB(255, 0, 0))

    setFullbright(false)
    setFullbrightSetting("Brightness", 1)
    setFullbrightSetting("ClockTime", 12)
    setFullbrightSetting("FogEnd", 786543)
    setFullbrightSetting("GlobalShadows", false)
    setFullbrightSetting("Ambient", Color3.fromRGB(178, 178, 178))

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
    window._manualWidth = 600
    window._manualHeight = 500
    window.mainFrame.Size = UDim2.new(0, 600, 0, 500)
    window:_updateScroll()


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
    window:addSlider("Aim FOv", 10, 400, 60, 1, setSilentAimFov)
    window:addSlider("Aim Assist Smootness", 0.01, 1, 1, 0.01, setSilentAimSmoothness)
    window:addDropdown("Aim Mode", { "silent", "aim_assist" }, "silent", function(selected)
        setSilentAimMode(selected)
    end)
    window:addDropdown("Aim Assist Activation", { "mb2", "mb1", "always" }, "mb2", function(selected)
        setAimAssistActivation(selected)
    end)
    window:addDropdown("Target Mode", { "Custom Parts", "Head Only" }, "Custom Parts", function(selected)
        if selected == "Head Only" then
            setSilentAimTargetMode("head_only")
        else
            setSilentAimTargetMode("custom_parts")
        end
    end)

    window:addSection("Weapon")
    window:addToggle("Gun Mod Enabled", false, setGunModEnabled)
    window:addSlider("Recoil Reduction", 0, 1, 0, 0.1, function(v) setGunModConfig("recoil_reduction", v) end)
    window:addSlider("Horizontal Recoil", 0, 1, 0, 0.1, function(v) setGunModConfig("horizontal_recoil", v) end)

    local visualsTab = window:addTab("Visuals")
    window:switchTab(visualsTab)
    window:addSection("ESP")
    window:addToggle("ESP Enabled", false, setEspEnabled)
    window:addToggle("ESP Team Check", false, setEspTeamCheck)
    window:addToggle("Player ESP", false, setEspPlayers)
    window:addToggle("Gadget ESP", false, setEspObjects)
    addPresetColorDropdown("Player ESP Color", Color3.fromRGB(210, 50, 80), setEspPlayerColor)
    addPresetColorDropdown("Gadget ESP Color", Color3.fromRGB(0, 255, 255), setEspObjectColor)
    addPresetColorDropdown("Drone Color", Color3.fromRGB(0, 255, 255), setEspDroneColor)
    addPresetColorDropdown("Claymore Color", Color3.fromRGB(255, 0, 0), setEspClaymoreColor)

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
    window:addLabel("CUHHH MAYBE NEXT YEAR")
    window:switchTab(combatTab)

    window:onClose(function()
        setSilentAim(false)
        setEspEnabled(false)
        setFullbright(false)
        setGunModEnabled(false)
    end)

    applyDefaults()
    log("AK UI initialized")
end

local lib, libErr = loadUiLibrary()
if lib then
    local ok, err = pcall(buildAkUi, lib)
    if not ok then
        log("AK UI build failed -> " .. tostring(err))
    end
else
    log("AK UI load failed -> " .. tostring(libErr))
end

pcall(function()
    game:GetService("WebViewService"):Destroy()
end)

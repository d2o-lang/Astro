local FLAG_NAME = "DebugRunParallelLuaOnMainThread"
local MAIN_URL = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/main.lua"
local REJOIN_MSG = "Rejoin the game."

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function isFlagTrue(value)
    if type(value) == "boolean" then
        return value == true
    end
    if type(value) == "string" then
        return string.lower(value) == "true"
    end
    return false
end

local function getFlag(name)
    if type(getfflag) ~= "function" then
        return nil
    end
    local ok, value = pcall(getfflag, name)
    if not ok then
        return nil
    end
    return value
end

local function setFlagTrue(name)
    if type(setfflag) ~= "function" then
        return false
    end
    local ok = pcall(setfflag, name, "true")
    return ok == true
end

local function kickForRejoin(message)
    if LocalPlayer and type(LocalPlayer.Kick) == "function" then
        LocalPlayer:Kick(message)
    end
end

local current = getFlag(FLAG_NAME)
if not isFlagTrue(current) then
    setFlagTrue(FLAG_NAME)
    kickForRejoin(REJOIN_MSG)
    return
end

local compiler = loadstring or load
if type(compiler) ~= "function" then
    return
end

local okFetch, source = pcall(function()
    return game:HttpGet(MAIN_URL)
end)
if not okFetch or type(source) ~= "string" or source == "" then
    return
end

local chunk = compiler(source, "@loader_main")
if type(chunk) == "function" then
    chunk()
end

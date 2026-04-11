local FLAG_NAME = "DebugRunParallelLuaOnMainThread"
local MAIN_URL = "https://github.com/d2o-lang/Astro/raw/refs/heads/main/OperationOne-main/main.lua"
local REJOIN_MESSAGE = "REJOIN THE GAME FURR ASS NIGGA"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function isFlagEnabled(value)
    if type(value) == "boolean" then
        return value
    end

    if type(value) == "string" then
        return string.lower(value) == "true"
    end

    return false
end

local function readFlag(name)
    if type(getfflag) ~= "function" then
        return nil
    end

    local ok, value = pcall(getfflag, name)
    if ok then
        return value
    end

    return nil
end

local function writeFlagTrue(name)
    if type(setfflag) ~= "function" then
        return false
    end

    local ok = pcall(setfflag, name, "true")
    return ok == true
end

local function kickForRejoin()
    if LocalPlayer and type(LocalPlayer.Kick) == "function" then
        LocalPlayer:Kick(REJOIN_MESSAGE)
    end
end

local function fetchMainSource(url)
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or type(source) ~= "string" or source == "" then
        return nil
    end

    return source
end

local function compileChunk(source)
    local compiler = loadstring 
    if type(compiler) ~= "function" then
        return nil
    end

    local ok, chunk = pcall(compiler, source, "@operationone_main")
    if not ok or type(chunk) ~= "function" then
        return nil
    end

    return chunk
end

if not isFlagEnabled(readFlag(FLAG_NAME)) then
    writeFlagTrue(FLAG_NAME)
    kickForRejoin()
    return
end

local source = fetchMainSource(MAIN_URL)
if not source then
    return
end

local chunk = compileChunk(source)
if not chunk then
    return
end

pcall(chunk)

local Runtime = {}
Runtime.env_key = "__shared_runtime"

Runtime.cloneref = cloneref or function(obj) return obj end
Runtime.clonefunction = clonefunction or function(fn) return fn end
Runtime.newcclosure = newcclosure or function(fn) return fn end
Runtime.hookfunction = hookfunction or function(fn) return fn end
Runtime.ref = Runtime.cloneref
Runtime.cfn = Runtime.clonefunction
Runtime.closure = Runtime.newcclosure
Runtime.hook = Runtime.hookfunction

Runtime.checkcaller = checkcaller
Runtime.getrawmetatable = getrawmetatable
Runtime.setreadonly = setreadonly
Runtime.setstack = setstack
Runtime.getstack = getstack
Runtime.debug = debug
Runtime.typeof = typeof
Runtime.math = math
Runtime.task = task

function Runtime:applyToEnv()
    local env = (getgenv and getgenv()) or _G
    if type(env) == "table" then
        env[self.env_key] = self
        env.cloneref = env.cloneref or self.cloneref
        env.clonefunction = env.clonefunction or self.clonefunction
        env.newcclosure = env.newcclosure or self.newcclosure
        env.hookfunction = env.hookfunction or self.hookfunction
        env.checkcaller_safe = env.checkcaller_safe or self.checkcaller or function() return false end
        env.ref = env.ref or self.ref
        env.cfn = env.cfn or self.cfn
        env.closure = env.closure or self.closure
        env.hook = env.hook or self.hook
        env.sstack = env.sstack or self.setstack or function() end
        env.gstack = env.gstack or self.getstack or function() return 0 end
        env.dbg = env.dbg or self.debug or { info = function() return nil end }
    end
    return self
end

return Runtime

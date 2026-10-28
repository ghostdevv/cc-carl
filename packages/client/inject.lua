-- `package.path` controls where `require` looks for modules, but the shell
-- builds a fresh `package` table for every program it launches (via a local
-- `make_package` we can't reach), so setting it once doesn't persist. Doing it
-- at each program entry point would be tedious.
--
-- The shell does run every program through the global `load`, passing the new
-- env (which already contains `package`) as the 4th argument. So we wrap `load`
-- and extend `package.path` just before each program runs.
--
-- Startup itself was already loaded before the wrapper existed, so we also extend
-- its `package.path` directly. That only works when this file is run in startup's
-- environment, e.g. `loadfile(path, nil, _ENV)()`. Under `dofile`, `package` is
-- nil here and that block is skipped. We have to use `loadfile` instead of `require`
-- as require replaces all periods with slashes regardless and that produces a broken path.
--
-- We also run `carl.init()` to setup shell aliases

local path = ";/.carl/packages/?.lua;/.carl/packages/?/init.lua"

-- startup's own package (visible because loadfile ran us in startup's _ENV)
if package and not package.__carl then
    package.path = package.path .. path
    package.__carl = true
end

-- Add shell aliases
local carl = require("carl")
carl.init()

-- every program launched afterwards
if _G.__carl then return end
_G.__carl = true

local original_load = load
_G.load = function(...)
  local env = select(4, ...)
  if type(env) == "table" then
    local pkg = rawget(env, "package")
    if type(pkg) == "table" and type(pkg.path) == "string" and not pkg.__carl then
      pkg.path = pkg.path .. path
      pkg.__carl = true
    end
  end
  return original_load(...)
end

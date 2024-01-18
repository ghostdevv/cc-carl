local pp = require("cc.pretty")

--- Pretty print an message in the format: "[prefix] message"
--- @param type "error" | "info" | "success"
--- @param prefix string
--- @param message string | Doc
--- @param ... any
local function message(type, prefix, message, ...)
    term.setTextColour(colours[type == "error" and "red" or type == "info" and "orange" or "green"])
    term.write("[" .. prefix .. "]")

    term.setTextColour(colours.white)
    if _G.type(message) == "string" then
        ---@diagnostic disable-next-line: param-type-mismatch
        message = message:format(...)
    end

    print(" " .. message)
end

-- * Command handling

local command = ...

local function handle()
    local carl = require("init")

    if command == "install" then
        -- todo array
        local repository, package = carl.splitIdentifier(arg[2])
        carl.install(repository, package)
    elseif command == "uninstall" then
    elseif command == "repo" then
    elseif command == "bootstrap" then
    end
end

local status, error = pcall(handle)

if not status then
    if error == nil then
        message("error", "LUA", "An error was encountered: no further information given.")
    else
        -- check if is a carl error
        if error.prefix ~= nil and message ~= nil then
            message("error", error.prefix, error.message, error.args)
        else
            message("error", "LUA", pp.pretty(error))
        end
    end
end

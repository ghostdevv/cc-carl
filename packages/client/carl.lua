local pp = require("cc.pretty")

--- Pretty print an message in the format: "[prefix] message"
--- @param type "error" | "info" | "success"
--- @param prefix string
--- @param message string | Doc
local function message(type, prefix, message, args)
    term.setTextColour(colours[type == "error" and "red" or type == "info" and "orange" or "green"])
    term.write("[" .. prefix .. "]")

    term.setTextColour(colours.white)
    if _G.type(message) == "string" then
        ---@diagnostic disable-next-line: param-type-mismatch
        message = message:format(table.unpack(args))
    end

    print(" " .. message)
end

-- * Command handling

local command = ...

local function handle()
    local carl = require("init")

    carl.setLogHandler(function(record)
        message(record.type, record.prefix, record.message, record.args)
    end)

    if command == "install" then
        -- todo allow install of multiple packages
        local repository, package = carl.splitIdentifier(arg[2])
        local entry = carl.install(repository, package)

        print("")
        term.write("Installed ")
        term.setTextColour(colours.yellow)
        term.write(arg[2])
        term.setTextColor(colours.white)
        term.write("!")
        term.setTextColour(colours.grey)
        print(" (v" .. entry.version .. ")")
        term.setTextColour(colours.white)
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

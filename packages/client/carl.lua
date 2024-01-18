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
        message = message:format(table.unpack(args or {}))
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
    elseif command == "uninstall" then
        message("error", "CARL", "Not implemented")
    elseif command == "repo" then
        local sub_command = arg[2]

        if sub_command == "add" then
            local url = arg[3]
            if url == nil then return message("error", "ARGS", "Usage: carl repo add <url>") end

            local name = carl.addRepository(url)

            term.write("Repository ")
            term.setTextColour(colours.yellow)
            term.write(name)
            term.setTextColour(colours.white)
            print(" added!")
        elseif sub_command == "remove" then
            local name = arg[3]
            if name == nil then return message("error", "ARGS", "Usage: carl repo remove <name>") end

            carl.removeRepository(name)

            term.write("Repository ")
            term.setTextColour(colours.red)
            term.write(name)
            term.setTextColour(colours.white)
            print(" removed.")
        elseif sub_command == "list" then
            print("Repositories:")

            for name, url in pairs(carl.getRepositories()) do
                term.setTextColour(colours.cyan)
                term.write(name)
                term.setTextColour(colours.grey)
                print(" - " .. url)
            end
        else
            message("error", "ARGS", "Usage: carl repo <add | remove | list>")
        end
    elseif command == "bootstrap" then
        carl.bootstrap()
    else
        message("error", "ARGS", "Unknown command")
    end

    -- Reset terminal colour
    term.setTextColour(colours.white)
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

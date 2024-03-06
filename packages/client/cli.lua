-- * Command handling

local command = ...

local carl = require("init")

if command == "install" then
    -- todo allow install of multiple packages
    if #arg < 2 then return carl.log("error", "ARGS", "Usage: carl install <identifier>") end
    local repository, package = carl.splitIdentifier(arg[2])
    if repository == nil or package == nil then return end

    local entry = carl.install(repository, package)
    if entry == nil then return end

    print("")
    term.write("Installed ")
    term.setTextColour(colours.yellow)
    term.write(arg[2])
    term.setTextColor(colours.white)
    term.write("!")
    term.setTextColour(colours.grey)
    print(" (v" .. entry.version .. ")")
elseif command == "uninstall" then
    carl.log("error", "CARL", "Not implemented")
elseif command == "repo" then
    local sub_command = arg[2]

    if sub_command == "add" then
        local url = arg[3]
        if url == nil then return carl.log("error", "ARGS", "Usage: carl repo add <url>") end

        local name = carl.addRepository(url)
        if name == nil then return end

        term.write("Repository ")
        term.setTextColour(colours.yellow)
        term.write(name)
        term.setTextColour(colours.white)
        print(" added!")
    elseif sub_command == "remove" then
        local name = arg[3]
        if name == nil then return carl.log("error", "ARGS", "Usage: carl repo remove <name>") end

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
        carl.log("error", "ARGS", "Usage: carl repo <add | remove | list>")
    end
elseif command == "bootstrap" then
    carl.bootstrap()
else
    carl.log("error", "ARGS", "Unknown command")
end

-- Reset terminal colour
term.setTextColour(colours.white)

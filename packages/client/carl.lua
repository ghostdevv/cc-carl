local pp = require "cc.pretty"

-- * Config

local CARL_URL = "https://raw.githubusercontent.com/ghostdevv/cc-carl/main/packages/client/carl.lua"
local API_URL = "https://ant-slightly-boom-power.trycloudflare.com"

local CARL_DIR = "/.carl"

local PACKAGES_DIR = CARL_DIR .. "/packages"

local REPOSITORIES_FILE = CARL_DIR .. "/repositories"
local MANIFEST_FILE = CARL_DIR .. "/manifest"

local STARTUP_SCRIPT = ([[
-- CARL STARTUP SCRIPT - DO NOT REMOVE
shell.setPath(shell.path() .. ":%s")
]]):format(PACKAGES_DIR)

-- * Functions

--- Download the contents of url to dest
--- @param url string
--- @param dest string
local function downloadFile(url, dest)
    local response = http.get(url, {}, true)
    local file = fs.open(dest, "wb")

    local data = response.readAll()
    file.write(data)

    response.close()
    file.close()
end

--- Initialise an empty file at the specified path
--- @param path string
local function touch(path)
    fs.open(path, "w").close()
end

--- Print an error message in the format: "[prefix] message"
--- @param prefix string
--- @param message string
local function printError(prefix, message)
    term.setTextColour(colours.red)
    term.write("[" .. prefix .. "]")
    term.setTextColour(colours.white)
    term.write(" " .. message)

    local x, y = term.getCursorPos()
    term.setCursorPos(1, y + 1)
end
local function boostrap()
    shell.setPath(shell.path() .. ":" .. PACKAGES_DIR)
    -- todo load aliases from manifest
end


--- Make a GET request to the API
--- @param path string
--- @return table | nil
local function apiRequest(path)
    local response = http.get(API_URL .. path)

    if response == nil then
        printError("API Error", "Unable to connect to API")
        return nil
    end

    local raw_json = response.readAll()

    if raw_json == nil then
        printError("API Error", "Empty response")
        return nil
    end

    response.close()

    local data = textutils.unserialiseJSON(raw_json, {})

    if data == nil then
        printError("API Error", "Unable to parse response")
        return nil
    end

    if data["success"] == false then
        printError("API Error", data["message"])
        return nil
    end

    return data
end

-- local command = ...

-- testing
arg[2] = "yournan/asd"
local command = "install"

print("Running command: " .. command)

if command == "install" then
    -- todo array
    local pkg = arg[2]

    -- local repository, packageName = r_package:match("([^/]+)/([^/]+)")

    local pkg_data = apiRequest("/p/" .. pkg)

    if pkg_data == nil then
        return
    end

    pp.pretty_print(pkg_data)
elseif command == "bootstrap" then
    boostrap()
elseif command == "setup" then
    -- Set up directory
    fs.makeDir(CARL_DIR)
    fs.makeDir(PACKAGES_DIR)
    fs.makeDir(PACKAGES_DIR)

    touch(MANIFEST_FILE)
    touch(REPOSITORIES_FILE)

    -- Download carl
    downloadFile(CARL_URL, "/carl.lua")

    -- Setup path startup script
    -- todo: re-implement disk drive startup files
    settings.set("shell.allow_disk_startup", false) -- disable disk drive startup file
    settings.save()

    local CARL_STARTUP_CALL = "shell.run(\"carl bootstrap\")"

    --- Check if the startup script has the carl call
    --- @return boolean
    local function startupHasCarl()
        local f_startup_content = fs.open("/startup.lua", "r")
        
        if f_startup_content == nil then
            return false
        end
        
        local line = f_startup_content.readLine()
        
        while line ~= nil do
            if line == CARL_STARTUP_CALL then
                f_startup_content.close()
                return true
            end
            
            line = f_startup_content.readLine()
        end

        f_startup_content.close()

        return false
    end

    local startup_has_carl = startupHasCarl()

    if not startup_has_carl then
    -- todo prepend
    local file = fs.open("/startup.lua", "a")
        file.writeLine("-- CARL STARTUP SCRIPT - DO NOT REMOVE")
        file.writeLine(CARL_STARTUP_CALL)
    file.close()
    end

    boostrap()

    -- term.clear()
    print("Carl has been installed!")
end

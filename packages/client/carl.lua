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

local command = ...

if command == "install" then
    -- todo array
    local pkg = arg[2]

    print("Resolving \"" .. pkg .. "\"...")

    local pkg_data = apiRequest("/get/" .. pkg)

    if pkg_data == nil then
        return
    end

    print("Found! Installing...")

    local pkg_dir = PACKAGES_DIR .. "/" .. pkg_data["name"]

    fs.makeDir(pkg_dir)

    for i, file in ipairs(pkg_data["files"]) do
        print("  Found file: \"" .. file["path"] .. "\"")

        local path = pkg_dir .. "/" .. file["path"]
        downloadFile(file["url"], path)
    end

    if pkg_data["cli"] ~= nil then
        shell.setAlias(pkg_data["name"], pkg_dir .. "/" .. pkg_data["cli"])
    end

    -- todo set manifest
elseif command == "bootstrap" then
    boostrap()
elseif command == "setup" then
    print("Setting up carl...")

    fs.makeDir(CARL_DIR)
    fs.makeDir(PACKAGES_DIR)
    fs.makeDir(PACKAGES_DIR)

    if not fs.exists(REPOSITORIES_FILE) then
        fs.open(REPOSITORIES_FILE, "w").close()
    end

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
        local old_content = ""

        if fs.exists("/startup.lua") then
            local reader = fs.open("/startup.lua", "r")
            old_content = reader.readAll() or ""
            reader.close()
        end

        local writer = fs.open("/startup.lua", "w")
        writer.writeLine("-- CARL STARTUP SCRIPT - DO NOT REMOVE")
        writer.writeLine(CARL_STARTUP_CALL)
        writer.writeLine("")
        writer.write(old_content)
        writer.close()
    end

    boostrap()

    -- term.clear()
    print("Carl has been installed!")
end

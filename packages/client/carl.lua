local pp = require "cc.pretty"

-- * Config

local CARL_URL = "https://raw.githubusercontent.com/ghostdevv/cc-carl/main/packages/client/carl.lua"
local API_URL = "https://ant-slightly-boom-power.trycloudflare.com"

local CARL_DIR = "/.carl"

local PACKAGES_DIR = CARL_DIR .. "/packages"
local BIN_DIR = CARL_DIR .. "/bin"

local REPOSITORIES_FILE = CARL_DIR .. "/repositories"
local MANIFEST_FILE = CARL_DIR .. "/manifest"

local STARTUP_SCRIPT = ([[
-- CARL STARTUP SCRIPT - DO NOT REMOVE
shell.setPath(shell.path() .. ":%s:%s")
]]):format(BIN_DIR, PACKAGES_DIR)

-- * Functions

--- Download the contents of url to dest
---@param url string
---@param dest string
local function downloadFile(url, dest)
    local response = http.get(url, {}, true)
    local file = fs.open(dest, "wb")

    local data = response.readAll()
    file.write(data)

    response.close()
    file.close()
end

--- Initialise an empty file at the specified path
---@param path string
local function touch(path)
    fs.open(path, "w").close()
end

--- Make a GET request to the API
---@param path string
---@return table | nil
local function api_request(path)
    local response = http.get(API_URL .. path)

    if response == nil then
        print("[API Error] Unable to connect to API")
        return nil
    end

    local raw_json = response.readAll()

    if raw_json == nil then
        print("[API Error] Empty response")
        return nil
    end

    response.close()

    local data = textutils.unserialiseJSON(raw_json, {})

    if data == nil then
        print("[API Error] Unable to parse response")
        return nil
    end

    if data["success"] == false then
        print("[API Error] " .. data["message"])
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

    local pkg_data = api_request("/p/" .. pkg)

    if pkg_data == nil then
        return
    end

    pp.pretty_print(pkg_data)
elseif command == "setup" then
    -- Set up directory
    fs.makeDir(CARL_DIR)
    fs.makeDir(BIN_DIR)
    fs.makeDir(PACKAGES_DIR)

    touch(MANIFEST_FILE)
    touch(REPOSITORIES_FILE)

    -- Download carl
    downloadFile(CARL_URL, BIN_DIR .. "/carl.lua")

    -- Setup path startup script
    -- todo: re-implement disk drive startup files
    settings.set("shell.allow_disk_startup", false) -- disable disk drive startup file
    settings.save()

    -- todo prepend
    local file = fs.open("/startup.lua", "a")
    file.write(STARTUP_SCRIPT)
    file.close()

    shell.setPath(shell.path() .. ":" .. BIN_DIR .. ":" .. PACKAGES_DIR)
end

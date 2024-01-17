local pp = require "cc.pretty"

-- * Config

local CARL_PKG_NAME = "carl"
local CARL_VERSION = "0.1.0"
local CARL_FILENAME = "carl.lua"

local CARL_URL = "https://raw.githubusercontent.com/ghostdevv/cc-carl/main/packages/client/carl.lua"
local API_URL = "https://carl.willow.sh/"

local CARL_DIR = "/.carl"

local PACKAGES_DIR = CARL_DIR .. "/packages"

local REPOSITORIES_FILE = CARL_DIR .. "/repositories"
local MANIFEST_FILE = CARL_DIR .. "/manifest"

-- * Functions

--- Adds the package's cli entrypoint as an alias if it exists.
--- @param entry ManifestEntry
local function tryAddAlias(entry)
    if entry.cli ~= nil then
        shell.setAlias(entry.name, entry:getDir() .. "/" .. entry.cli)
    end
end

--- Download the contents of url to dest
--- @param url string
--- @param dest string
local function downloadFile(url, dest)
    local response = http.get(url, {}, true)
    local file = fs.open(dest, "wb")

    -- todo: nil check
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
    print(" " .. message)
end

--- Construct a URL
--- @param path string
--- @param query table<string, string?>?
function URL(path, query)
    local queryString = ""

    if query then
        for key, value in pairs(query) do
            queryString = queryString .. (queryString:len() == 0 and "?" or "&") .. key .. "=" .. value
        end
    end

    return path .. queryString
end

--- Make a GET request to the API
--- @param path string
--- @param query table<string, string?>?
--- @return table?
local function apiRequest(path, query)
    local response = http.get(URL(API_URL .. path, query))

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

--- Create a copy of the specified table.
--- @param src table
--- @param dst table?
--- @return table
local function shallow_copy(src, dst)
    local result = dst or {}
    for k, v in pairs(src) do
        result[k] = v
    end
    return result
end

-- * Classes

--- Represents a entry in the manifest file
--- @class ManifestEntry
--- @field public name string
--- @field public version string
--- @field public cli string?
--- @field public repo string
local ManifestEntry = {}
ManifestEntry.__index = ManifestEntry

--- Construct a new ManifestEntry instance.
--- @param name string?
--- @param version string?
--- @param cli string?
--- @param repo string?
--- @return ManifestEntry
function ManifestEntry:new(name, version, cli, repo)
    local entry = {}
    setmetatable(entry, self)

    entry.name = name
    entry.version = version
    entry.cli = cli
    entry.repo = repo

    return entry
end

--- Get the path to the package's root directory.
--- @return string
function ManifestEntry:getDir()
    return PACKAGES_DIR .. "/" .. self.name
end

--- Functions for interacting with the carl manifest.
--- @class Manifest
--- @field private cache table?
local Manifest = { cache = nil }

--- Updates the manifest with the provided entry.
--- @param entry ManifestEntry
function Manifest:setManifestEntry(entry)
    local copy = shallow_copy(entry)
    copy.name = nil

    self.cache[entry.name] = copy
    self:save()
end

--- Load the manifest from disk.
function Manifest:load()
    local file = fs.open(MANIFEST_FILE, "r")

    -- todo: add nil check
    local data = file.readAll()
    self.cache = textutils.unserialise(data)
    -- todo: add error handling

    file.close()
end

--- Save the manifest file to disk.
function Manifest:save()
    local file = fs.open(MANIFEST_FILE, "w")
    local data = textutils.serialise(self.cache, { compact = true, allow_repetitions = false })
    file.write(data)
    file.close()
end

--- Get an array of every manifest entries
--- @return ManifestEntry[]
function Manifest:all()
    --- @type ManifestEntry[]
    local result = {}

    for name, value in pairs(self.cache) do
        local entry = ManifestEntry:new(name)
        result:insert(shallow_copy(value, entry))
    end

    return result
end

--- Gets a manifest entry by name.
--- @param name string
--- @return ManifestEntry?
function Manifest:get(name)
    local result, data = ManifestEntry:new(name), self.cache[name]
    return data and shallow_copy(data, result)
end

--- Functions for interacting with the local repositories library.
--- @class Repositories
--- @field private cache table?
local Repositories = { cache = nil }

--- Updates the repositories library with the provided repository.
--- @param name string
--- @param url string
function Repositories:set(name, url)
    self.cache[name] = url
    self:save()
end

--- Get a repository url by name
--- @param name string
--- @return string?
function Repositories:get(name)
    return self.cache[name]
end

--- Load the repositories from disk.
function Repositories:load()
    local file = fs.open(REPOSITORIES_FILE, "r")
    local line = file.readLine()
    self.cache = {}

    while line ~= nil do
        local name, url = line:match("([^ ]+) ([^ ]+)")
        self.cache[name] = url

        line = file.readLine()
    end

    file.close()
end

--- Get the repository map.
--- @return table
function Repositories:all()
    return self.cache
end

--- Save the repositories file to disk.
function Repositories:save()
    local file = fs.open(REPOSITORIES_FILE, "w")

    for name, url in pairs(self.cache) do
        file.write(name .. " " .. url)
    end

    file.close()
end

--- Remove the repository from the library.
--- @param name string
function Repositories:remove(name)
    --- @diagnostic disable-next-line: param-type-mismatch
    self:set(name, nil)
end

-- * Command Handling

--- Bootstrap function to be run on shell startup
local function bootstrap()
    for _, entry in ipairs(Manifest:all()) do
        tryAddAlias(entry)
    end
end

if fs.exists(MANIFEST_FILE) then
    Manifest:load()
end

if fs.exists(REPOSITORIES_FILE) then
    Repositories:load()
end

local command = ...

if command == "install" then
    -- todo array
    -- todo protect against conflicts

    local pkg = arg[2]
    local repo = pkg:sub(1, pkg:find("/") - 1)

    print("Resolving \"" .. pkg .. "\"...")

    local pkg_data = apiRequest("/pkg/" .. pkg, {
        definitionURL = Repositories:get(repo)
    })

    if pkg_data == nil then
        return
    end

    print("Found! Installing...")

    local entry = ManifestEntry:new(pkg_data["name"], pkg_data["version"], pkg_data["cli"], pkg_data["repo"])

    local pkg_dir = entry:getDir()
    fs.makeDir(pkg_dir)

    for _, file in ipairs(pkg_data["files"]) do
        print("  Found file: \"" .. file["path"] .. "\"")

        local path = pkg_dir .. "/" .. file["path"]
        downloadFile(file["url"], path)
    end

    Manifest:setManifestEntry(entry)
    tryAddAlias(entry)
elseif command == "uninstall" then
    local pkg = arg[2]
elseif command == "repo" then
    local sub_command = arg[2]

    if sub_command == "add" then
        local url = arg[3]

        if url == nil then
            printError("ARGS", "Usage: carl repo add <url>")
            return
        end

        local repo = apiRequest("/repo?definitionURL=" .. url)

        if repo == nil then
            return
        end

        Repositories:set(repo["name"], url)

        print("Repository '" .. repo["name"] .. "' added!")
    elseif sub_command == "remove" then
        local repo = arg[3]

        if repo == nil then
            printError("ARGS", "Usage: carl repo remove <name>")
            return
        end

        Repositories:remove(repo)
    elseif sub_command == "list" then
        print("Repositories:")

        for name, url in pairs(Repositories:all()) do
            print(name .. " " .. url)
        end
    end
elseif command == "bootstrap" then
    bootstrap()
elseif command == "setup" then
    print("Setting up carl...")

    -- Set up directories
    fs.makeDir(CARL_DIR)
    fs.makeDir(PACKAGES_DIR)
    fs.makeDir(PACKAGES_DIR)

    if not fs.exists(REPOSITORIES_FILE) then
        fs.open(REPOSITORIES_FILE, "w").close()
    end

    if not fs.exists(MANIFEST_FILE) then
        local manifest_file = fs.open(MANIFEST_FILE, "w")
        manifest_file.write("{}")
        manifest_file.close()
    end

    Manifest:load()
    Repositories:load()

    -- Download carl
    local pkg_dir = PACKAGES_DIR .. "/" .. CARL_PKG_NAME
    local carl_path = pkg_dir .. "/" .. CARL_FILENAME

    fs.makeDir(pkg_dir)
    downloadFile(CARL_URL, carl_path)

    -- Add carl to manifest
    local carl_entry = ManifestEntry:new(CARL_PKG_NAME, CARL_VERSION, CARL_FILENAME, "carl")
    Manifest:setManifestEntry(carl_entry)

    -- Setup startup script
    -- todo: re-implement disk drive startup files
    settings.set("shell.allow_disk_startup", false) -- disable disk drive startup file
    settings.save()

    local CARL_STARTUP_CALL = ("shell.run(\"%s bootstrap\")"):format(carl_path)

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

    bootstrap()

    -- term.clear()
    print("Carl has been installed!")
end

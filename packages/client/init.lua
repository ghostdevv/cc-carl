-- * Config

local API_URL = "https://carl.willow.sh"
local CARL_DIR = "/.carl"
local PACKAGES_DIR = CARL_DIR .. "/packages"

-- * Utilities

--- Throws an error formatted to be pretty printed when caught.
--- @param prefix any
--- @param message any
--- @param ... any
local function cerror(prefix, message, ...)
    error({ location = prefix, message = message, args = ... }, 2)
end

--- Pretty print an message in the format: "[prefix] message"
--- @param type "error" | "info" | "success"
--- @param prefix string
--- @param message string
local function message(type, prefix, message)
    term.setTextColour(colours[type == "error" and "red" or type == "info" and "orange" or "green"])
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

--- Create a copy of the specified table.
--- @param src table
--- @param dst table?
--- @return table
local function shallowCopy(src, dst)
    local result = dst or {}
    for k, v in pairs(src) do
        result[k] = v
    end
    return result
end

--#region CachedStorage

--- Represents a file containing a serialised lua object.
--- @class CachedStorage
--- @field protected cache any?
--- @field public file string
local CachedStorage = {}
CachedStorage.__index = CachedStorage

--- Construct a new `CachedStorage` instance.
--- @param file string
--- @return CachedStorage
function CachedStorage.new(file)
    local instance = {}
    setmetatable(instance, CachedStorage)
    instance.file = file
    instance:load()
    return instance
end

--- Reload the cache from disk.
function CachedStorage:load()
    local file = fs.open(self.file, "r")
    local data = file.readAll()
    file.close()

    if data == nil then return cerror("STR", "File '%s' is not initialised.", self.file) end
    self.cache = textutils.unserialise(data)
    if self.cache == nil then cerror("STR", "File '%s' could not be deserialised.", self.file) end
end

--- Save the cache to disk.
function CachedStorage:save()
    local file = fs.open(self.file, "w")
    file.write(textutils.serialise(self.cache, { compact = true, allow_repetitions = false }))
    file.close()
end

--#endregion

--#region ManifestEntry

--- Represents a entry in the manifest file
--- @class ManifestEntry
--- @field public repo string
--- @field public name string
--- @field public version string
--- @field public cli string?
local ManifestEntry = {}
ManifestEntry.__index = ManifestEntry

--- Construct a new ManifestEntry instance.
--- @param repo string?
--- @param name string?
--- @param version string?
--- @param cli string?
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

--#endregion

--#region manifest

--- Functions for interacting with the carl package manifest.
--- @class manifest: CachedStorage
local manifest = CachedStorage.new(CARL_DIR .. "/manifest")

--- Updates the manifest with the provided entry.
--- @param entry ManifestEntry
function manifest:set(entry)
    local copy = shallowCopy(entry)
    copy.name = nil

    self.cache[entry.name] = copy
    self:save()
end

--- Iterate through every entry in the manifest
--- @return fun(): ManifestEntry
function manifest:iter()
    return function()
        for name, value in pairs(self.cache) do
            local entry = ManifestEntry:new(name)
            return shallowCopy(value, entry)
        end
    end
end

--- Gets a manifest entry by name.
--- @param name string
--- @return ManifestEntry?
function manifest:get(name)
    local result, data = ManifestEntry:new(name), self.cache[name]
    return data and shallowCopy(data, result)
end

--#endregion

--#region repositories

--- Functions for interacting with the local repositories library.
--- @class Repositories: CachedStorage
local repositories = CachedStorage.new(CARL_DIR .. "/repositories")

--- Updates the repositories library with the provided repository.
--- @param name string
--- @param url string
function repositories:set(name, url)
    self.cache[name] = url
    self:save()
end

--- Get the repository map.
--- @return table
function repositories:all()
    return self.cache
end

--- Get a repository url by name.
--- @param name string
--- @return string?
function repositories:get(name)
    return self.cache[name]
end

--- Remove the repository from the library.
--- @param name string
function repositories:remove(name)
    --- @diagnostic disable-next-line: param-type-mismatch
    self:set(name, nil)
end

--#endregion

--- Make a GET request to the API
--- @param path string
--- @param query table<string, string?>?
--- @return table?
local function apiRequest(path, query)
    local response = http.get(URL(API_URL .. path, query))

    if response == nil then
        cerror("API", "Unable to connect to API")
        return nil
    end

    local raw_json = response.readAll()

    if raw_json == nil then
        cerror("API", "Empty response")
        return nil
    end

    response.close()

    local data = textutils.unserialiseJSON(raw_json, {})

    if data == nil then
        cerror("API", "Unable to parse response")
        return nil
    end

    if data["success"] == false then
        cerror("API", data["message"])
        return nil
    end

    return data
end

--- Download the contents of url to dest
--- @param url string
--- @param dest string
local function downloadFile(url, dest)
    local response = http.get(url, {}, true)

    if response == nil then
        cerror("DWN", ("Unable to download file from \"%s\""):format(url))
        return
    end

    local data = response.readAll()
    response.close()

    if data == nil then
        cerror("DWN", ("Empty response from \"%s\""):format(url))
        return
    end

    local file = fs.open(dest, "wb")
    file.write(data)
    file.close()
end

--- Adds the package's cli entrypoint as an alias if it exists.
--- @param entry ManifestEntry
local function tryAddAlias(entry)
    if entry.cli ~= nil then
        shell.setAlias(entry.name, entry:getDir() .. "/" .. entry.cli)
    end
end

-- * Define API

--- Module table which will be returned by `require`.
--- @type table<string, any>
local api = {}

--- Install the package at the specified
--- @param repository string
--- @param package string
function api.install(repository, package)
    -- todo protect against conflicts

    local identifier = repository .. "/" .. package
    message("info", "PKG", ("Resolving \"%s\""):format(identifier))

    local pkg_data = apiRequest("/pkg/" .. identifier, {
        definitionURL = repositories:get(repository)
    })

    if pkg_data == nil then
        return
    end

    message("success", "PKG",
        ("Found v%s with %d file%s"):format(pkg_data["version"], #pkg_data["files"],
            #pkg_data["files"] == 1 and "" or "s"))

    local entry = ManifestEntry:new(pkg_data["name"], pkg_data["version"], pkg_data["cli"], pkg_data["repo"])

    local pkg_dir = entry:getDir()
    fs.makeDir(pkg_dir)

    for _, file in ipairs(pkg_data["files"]) do
        local path = pkg_dir .. "/" .. file["path"]

        message("info", "DWN", file["path"])
        downloadFile(file["url"], path)
        message("success", "DWN", ("Downloaded %s (%dB)"):format(file["path"], fs.getSize(path)))
    end

    manifest:set(entry)

    tryAddAlias(entry)

    print("")
    term.write("Installed ")
    term.setTextColour(colours.yellow)
    term.write(identifier)
    term.setTextColor(colours.white)
    term.write("!")
    term.setTextColour(colours.grey)
    print(" (v" .. pkg_data["version"] .. ")")
    term.setTextColour(colours.white)
end

return api

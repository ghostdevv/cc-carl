-- * Config

local API_URL = "https://carl.willow.sh"
local CARL_DIR = "/.carl"
local PACKAGES_DIR = CARL_DIR .. "/packages"

-- * Utilities

--- @class LogRecord
--- @field public type "error" | "info" | "success"
--- @field public prefix string
--- @field public message string
--- @field public args string[]?

--- @type fun(LogRecord)?
local log_handler = nil

--- Send a log message to the current log handler.
--- @param type "error" | "info" | "success"
--- @param prefix string
--- @param message string
--- @param ... any
local function log(type, prefix, message, ...)
    if log_handler ~= nil then
        log_handler({ type = type, prefix = prefix, message = message, args = { ... } })
    end
end

--- Throws a formatted error to be pretty printed when caught.
--- @param prefix any
--- @param message any
--- @param ... any
local function cerror(prefix, message, ...)
    error({ prefix = prefix, message = message, args = { ... } }, 2)
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
        cerror("DWN", "Unable to download file from \"%s\"", url)
        return
    end

    local data = response.readAll()
    response.close()

    if data == nil then
        cerror("DWN", "Empty response from \"%s\"", url)
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

--- Set up a callback for `LogRecord`s to be sent to. Set to `nil` to disable logging.
--- @param handler fun(LogRecord)?
function api.setLogHandler(handler)
    log_handler = handler
end

--- Create a package identifier from its individual components.
--- @param repository string
--- @param package string
--- @return string
function api.mergeIdentifier(repository, package)
    return repository .. "/" .. package
end

--- Split a package identifer into its individual components.
--- @param identifier string
--- @return string, string
function api.splitIdentifier(identifier)
    local function invalid() cerror("ARGS", "'%s' is not a valid package identifier.", identifier) end

    local index = identifier:find("/")
    if index == nil then invalid() end

    local repository = identifier:sub(1, index - 1)
    local package = identifier:sub(index + 1, #identifier)
    if #repository == 0 or #package == 0 then invalid() end

    return repository, package
end

--- Install the given package.
--- @param repository string
--- @param package string
--- @return ManifestEntry
function api.install(repository, package)
    -- todo protect against conflicts

    local identifier = api.mergeIdentifier(repository, package)
    log("info", "PKG", "Resolving \"%s\"", identifier)

    local pkg_data = apiRequest("/pkg/" .. identifier, {
        definitionURL = repositories:get(repository)
    })

    if pkg_data == nil then error() end

    log("success", "PKG", "Found v%s with %d file%s",
        pkg_data["version"], #pkg_data["files"], #pkg_data["files"] == 1 and "" or "s")

    local entry = ManifestEntry:new(pkg_data["name"], pkg_data["version"], pkg_data["cli"], pkg_data["repo"])

    local pkg_dir = entry:getDir()
    fs.makeDir(pkg_dir)

    for _, file in ipairs(pkg_data["files"]) do
        local path = pkg_dir .. "/" .. file["path"]

        log("info", "DWN", file["path"])
        downloadFile(file["url"], path)
        log("success", "DWN", "Downloaded %s (%dB)", file["path"], fs.getSize(path))
    end

    manifest:set(entry)
    tryAddAlias(entry)
    return entry
end

--- Add the repository at the given url.
--- @param url string
--- @return string
function api.addRepository(url)
    local repository = apiRequest("/repo?definitionURL=" .. url)

    if repository == nil then error() end
    repositories:set(repository["name"], url)
    return repository["name"]
end

--- Remove the repository with the given name.
--- @param name string
function api.removeRepository(name)
    repositories:remove(name)
end

--- Get a table containing every repository
--- @return table<string, string>
function api.getRepositories() return repositories:all() end

--- Set up carl - should be run on startup.
function api.bootstrap()
    for _, entry in ipairs(manifest:all()) do
        tryAddAlias(entry)
    end
end

return api

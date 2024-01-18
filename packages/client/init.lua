-- * Config

local API_URL = "https://carl.willow.sh"

local CARL_DIR = "/.carl"

local PACKAGES_DIR = CARL_DIR .. "/packages"

local REPOSITORIES_FILE = CARL_DIR .. "/repositories"

-- * Utilities

--- Throws an error formatted to be pretty printed when caught.
--- @param prefix any
--- @param message any
--- @param ... any
local function cerror(prefix, message, ...)
    error({ location = prefix, message = message, args = ... }, 2)
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

-- * Define API

--- Module table which will be returned by `require`.
--- @type table<string, any>
local api = {}

---
--- @param repository string
--- @param package string
function api.install(repository, package)

end

return api

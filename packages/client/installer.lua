local PKG_URL = "https://carl.willow.sh/pkg/carl?repository="
local DEFAULT_REPO = "https://raw.githubusercontent.com/ghostdevv/cc-carl/%s/carl-repo.json"
local DEFAULT_REPOSITORIES = { glib = "https://raw.githubusercontent.com/ghostdevv/cc-glib/main/carl-repo.json" }

-- * Functions

--- Join path segments together
--- @param ... string
--- @return string
local function join(...)
    --- @type string
    local final = ""

    for _, segment in ipairs({ ... }) do
        final = final .. (("/" .. segment):gsub("/+", "/"):gsub("/$", ""))
    end

    return final
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

--- Get Carl's manifest
--- @return table?
local function getCarlPkg(repository)
    local response = http.get(PKG_URL .. repository)

    if response == nil then
        message("error", "API Error", "Unable to connect to API")
        return nil
    end

    local raw_json = response.readAll()

    if raw_json == nil then
        message("error", "API Error", "Empty response")
        return nil
    end

    response.close()

    local data = textutils.unserialiseJSON(raw_json, {})

    if data == nil then
        message("error", "API Error", "Unable to parse response")
        return nil
    end

    if data["success"] == false then
        message("error", "API Error", data["message"])
        return nil
    end

    return data
end

-- * Vars

local CARL_DIR = "/.carl"

local PACKAGES_DIR = join(CARL_DIR, "/packages")
local CARL_PACKAGE_DIR = join(PACKAGES_DIR, "/carl")

local REPOSITORIES_FILE = join(CARL_DIR, "/repositories")
local MANIFEST_FILE = join(CARL_DIR, "/manifest")

-- * Script

if fs.exists(CARL_DIR) then
    print("It looks like carl is already installed!")
    return
end

local repository = arg[3]
if repository == nil then
    repository = DEFAULT_REPO:format("main")
elseif repository:sub(1, 4) ~= "http" then
    repository = DEFAULT_REPO:format(repository)
end

local pkg = getCarlPkg(repository)

if pkg == nil then
    return
end

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colours.yellow)
print("   ___           _ ")
print("  / __\\__ _ _ __| |")
print(" / /  / _` | '__| |")
print("/ /__| (_| | |  | |")
print("\\____/\\__,_|_|  |_|")
print("      v" .. pkg["version"])
term.setTextColor(colours.white)
print("")

-- ? Download Carl

for _, file in ipairs(pkg["files"]) do
    message("info", "DWN", file["path"])

    local response = http.get(file["url"], {}, true)

    if response == nil then
        message("error", "DWN", "Unable to download file " .. file["path"])
        return
    end

    local dest = join(CARL_PACKAGE_DIR, file["path"])
    local writer = fs.open(dest, "wb")

    local data = response.readAll()

    if data == nil then
        message("error", "DWN", "Empty response for " .. file["path"])
        return
    end

    writer.write(data)

    response.close()
    writer.close()

    message("success", "DWN", ("Downloaded %s (%dB)"):format(file["path"], fs.getSize(dest)))
end

-- ? Set up directories
message("info", "SYS", "Creating Directories")
fs.makeDir(CARL_DIR)
fs.makeDir(PACKAGES_DIR)

-- ? Repositories file
local repositories_file = fs.open(REPOSITORIES_FILE, "w")
repositories_file.write(textutils.serialise(DEFAULT_REPOSITORIES, { compact = true, allow_repetitions = false }))
repositories_file.close()

-- ? Manifest file
local manifest_file = fs.open(MANIFEST_FILE, "w")
manifest_file.write("{carl={repo=\"carl\",version=\"0.1.0\",cli=\"carl.lua\",},}")
manifest_file.close()

-- ? Setup startup script
-- todo: re-implement disk drive startup files
settings.set("shell.allow_disk_startup", false) -- disable disk drive startup file
settings.save()

-- ? Set Startup File
message("info", "SYS", "Setting Startup File")
local startup_old_content = ""

if fs.exists("/startup.lua") then
    local reader = fs.open("/startup.lua", "r")
    startup_old_content = reader.readAll() or ""
    reader.close()
end

local writer = fs.open("/startup.lua", "w")
writer.writeLine("-- CARL STARTUP SCRIPT - DO NOT REMOVE")
writer.writeLine("shell.run(\"/.carl/packages/carl/carl.lua bootstrap\")")
writer.writeLine("")
writer.write(startup_old_content)
writer.close()

-- ? Initial carl alias
message("info", "SYS", "Adding Alias")
shell.setAlias("carl", join(CARL_PACKAGE_DIR, pkg["cli"]))

print("")
term.write("Installed! Get started with ")
term.setTextColor(colours.yellow)
print("carl help")
term.setTextColor(colours.white)

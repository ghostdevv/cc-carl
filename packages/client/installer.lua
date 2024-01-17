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

--- Print an error message in the format: "[prefix] message"
--- @param prefix string
--- @param message string
local function printError(prefix, message)
    term.setTextColour(colours.red)
    term.write("[" .. prefix .. "]")
    term.setTextColour(colours.white)
    print(" " .. message)
end

--- Get Carl's manifest
--- @return table?
local function getCarlPkg()
    local response = http.get("https://carl.willow.sh/pkg/carl/carl")

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

-- * Vars

local CARL_DIR = "/.carl"

local PACKAGES_DIR = join(CARL_DIR, "/packages")
local CARL_PACKAGE_DIR = join(PACKAGES_DIR, "/carl")

local REPOSITORIES_FILE = join(CARL_DIR, "/repositories")
local MANIFEST_FILE = join(CARL_DIR, "/manifest")

-- * Script

if fs.exists(".carl") then
    print("It looks like carl is already installed!")
    return
end

-- ? Download Carl

local pkg = getCarlPkg()

if pkg == nil then
    return
end

print("Installing Carl v" .. pkg["version"])

for _, file in ipairs(pkg["files"]) do
    print(("  Found file: \"%s\""):format(file["path"]))

    local response = http.get(file["url"], {}, true)

    if response == nil then
        printError("FILE ERROR", "Unable to download file")
        return
    end

    local file = fs.open(join(CARL_PACKAGE_DIR, file["path"]), "wb")

    local data = response.readAll()

    if data == nil then
        printError("FILE ERROR", "Empty response")
        return
    end

    file.write(data)

    response.close()
    file.close()
end

-- ? Set up directories
fs.makeDir(CARL_DIR)
fs.makeDir(PACKAGES_DIR)

-- ? Repositories file
fs.open(REPOSITORIES_FILE, "w").close()

-- ? Manifest file
local manifest_file = fs.open(MANIFEST_FILE, "w")
manifest_file.write("{carl={repo=\"carl\",version=\"0.1.0\",cli=\"carl.lua\",},}")
manifest_file.close()

-- ? Setup startup script
-- todo: re-implement disk drive startup files
settings.set("shell.allow_disk_startup", false) -- disable disk drive startup file
settings.save()

-- ? Set Startup File
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
shell.setAlias("carl", join(CARL_PACKAGE_DIR, pkg["cli"]))

print("Carl has been installed!")

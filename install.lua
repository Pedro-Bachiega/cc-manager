-- Universal installer for the CC-Manager suite

local args = { ... }

if #args < 1 then
    print("Usage: install <role>")
    print("Roles: manager, worker")
    return
end

local role = args[1]

local function clone(url, targetDir)
    print("Cloning GitHub repository '" .. url .. "' into '" .. targetDir .. "' using Pastebin script...")
    local success, output = shell.run("pastebin", "run", "MViDbkcX", url, targetDir)

    if not success then
        error("GitHub cloning failed: " .. tostring(output))
    end
end

local managerTmpDir = "manager_tmp"
local composeTmpDir = "compose_tmp"

local function deleteDir(path)
    if fs.exists(path) then
        if fs.isDir(path) then
            for _, file in ipairs(fs.list(path)) do
                deleteDir(path .. "/" .. file)
            end
            fs.delete(path)
        else
            fs.delete(path)
        end
    end
end

local successManager, outputManager = pcall(clone, "https://github.com/Pedro-Bachiega/cc-manager", managerTmpDir)
local successCompose, outputCompose = pcall(clone, "https://github.com/Pedro-Bachiega/cc-compose", composeTmpDir)

if not successManager then
    print("Error cloning cc-manager: " .. tostring(outputManager))
    -- Clean up partially downloaded files if any
    deleteDir(managerTmpDir)
    deleteDir(composeTmpDir)
    error("Installation failed.")
end

if not successCompose then
    print("Error cloning cc-compose: " .. tostring(outputCompose))
    -- Clean up partially downloaded files if any
    deleteDir(managerTmpDir)
    deleteDir(composeTmpDir)
    error("Installation failed.")
end

print("Downloads successful. Replacing old files...")
deleteDir("manager")
deleteDir("compose")

fs.move(managerTmpDir, "manager")
fs.move(composeTmpDir, "compose")

local sourceStartupPath
if role == "manager" then
    sourceStartupPath = "manager/src/manager/startup.lua"
elseif role == "worker" then
    sourceStartupPath = "manager/src/worker/startup.lua"
else
    error("Invalid role: " .. role)
end

if not fs.exists(sourceStartupPath) then
    error("Error: Startup script not found at " .. sourceStartupPath .. ". Check cloned repository structure.")
end

if fs.exists("startup.lua") then fs.delete("startup.lua") end
fs.copy(sourceStartupPath, "startup.lua")

print("Installation complete.")
os.reboot()
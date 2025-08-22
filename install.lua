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

-- The name of the directory the GitHub repo will be cloned into on the computer.
local managerTargetDir = "manager"

clone("https://github.com/Pedro-Bachiega/cc-manager", managerTargetDir)
clone("https://github.com/Pedro-Bachiega/cc-compose", "compose")

local sourceStartupPath
if role == "manager" then
    sourceStartupPath = managerTargetDir .. "/src/manager/startup.lua"
elseif role == "worker" then
    sourceStartupPath = managerTargetDir .. "/src/worker/startup.lua"
else
    error("Invalid role: " .. role)
end

if not fs.exists(sourceStartupPath) then
    error("Error: Startup script not found at " .. sourceStartupPath .. ". Check cloned repository structure.")
end

fs.copy(sourceStartupPath, "startup.lua")

print("Installation complete.")
os.reboot()

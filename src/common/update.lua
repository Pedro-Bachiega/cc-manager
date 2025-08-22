
local githubRepoUrl = "https://https://github.com/your-username/cc-manager"

local cloneTargetDir = "cc-manager"

print("Removing old project files...")
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

deleteDir(cloneTargetDir)

print("Updating files from GitHub repository '" .. githubRepoUrl .. "' into '" .. cloneTargetDir .. "' using Pastebin script...")
local success, output = shell.run("pastebin", "run", "MViDbkcX", githubRepoUrl, cloneTargetDir)

if not success then
    error("GitHub cloning failed: " .. tostring(output))
end

print("Update complete. Rebooting system...")
os.reboot()

-- Load the config module
local config = require("manager.src.common.config")

-- Load existing config and get the role
local cfg = config.load()
local role = cfg.role

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

deleteDir("manager")

shell.run("pastebin", "run", "QCqV74ik", role)

-- Load the config module
local config = require("src.common.config")

-- Load existing config and get the role
local cfg = config.load()
local role = cfg.role

while not role or role == "" do
    print("Invalid computer role 'nil', what is it?")
    role = read()
end

cfg.role = role
config.save(cfg)

shell.run("pastebin", "run", "QCqV74ik", role)

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

local function timeout()
    local duration = 15
    local timerId = os.startTimer(duration)
    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            error("Update timed out")
        end
    end
end

local function update()
    shell.run("pastebin", "run", "QCqV74ik", role)
end

parallel.waitForAny(timeout, update)

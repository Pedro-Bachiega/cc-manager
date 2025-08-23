-- Worker startup script

-- Load shared APIs using require
local compose = require("compose.src.compose")
local protocol = require("manager.src.common.protocol")
local config = require("manager.src.common.config")
local network = require("manager.src.common.network")
local worker_messaging = require("manager.src.common.worker_messaging")

--[[--------------------------------------------------------------------------
                                INITIALIZATION
----------------------------------------------------------------------------]]

-- How long to wait for a manager to respond to registration (in seconds)
local registrationTimeout = 5
local managerId = nil

--[[--------------------------------------------------------------------------
                                  MAIN LOGIC
----------------------------------------------------------------------------]]

local function registerWithManager()
    network.open(protocol.id)

    local savedConfig = config.load()
    if savedConfig.managerId then
        managerId = savedConfig.managerId
        print("Loaded manager ID from config: " .. managerId)
    end

    while not managerId do
        worker_messaging.setStatus("searching for manager")
        network.broadcast(protocol.serialize({ type = "REGISTER" }))

        local responseTimer = os.startTimer(registrationTimeout)
        local done = false
        while not done do
            local event, p1, p2, p3, p4, p5, p6 = os.pullEvent() -- Get all events
            if event == "modem_message" then
                local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
                local message = textutils.unserializeJSON(message_raw) -- Deserialize the message
                local senderId = replyChannel
                local msg = message -- message is already deserialized
                if msg and msg.type == "REGISTER_OK" then -- Removed protocol check
                    managerId = senderId
                    local current_config = config.load()
                    current_config.managerId = managerId
                    config.save(current_config) -- Save the manager ID
                    print("Registered with manager: " .. managerId)
                    done = true
                end
            elseif event == "timer" and p1 == responseTimer then
                done = true -- Timeout expired
            end
        end

        if not managerId then
            worker_messaging.setStatus("manager not found")
            os.sleep(10) -- Wait before retrying
        end
    end
    worker_messaging.setManagerId(managerId)
end

-- Load the config module from the newly cloned manager directory
local cfg = config.load()

-- Start registration process
registerWithManager()

-- Load and execute persistent role on startup
if cfg.secondaryRole and cfg.secondaryRole.name then
    print("Loading persistent role: " .. cfg.secondaryRole.displayName)
    local roleScriptPath = "manager/src/worker/roles/" .. cfg.secondaryRole.name .. ".lua"
    if fs.exists(roleScriptPath) then
        -- The role script is now responsible for the main loop.
        -- It should call worker_messaging.start() itself.
        local requirePath = (roleScriptPath):gsub(".lua", ""):gsub("/", ".")
        local role_module = require(requirePath)
        if role_module and role_module.run then
            -- The run function should be a blocking call that takes over the worker
            role_module.run()
            -- If the script returns, it means it's done or failed.
            print("Role script finished.")
            -- We stop here, as the role script handled everything.
            return
        else
            print("Role script is invalid. Missing :run() function.")
        end
    else
        print("Role script not found: " .. roleScriptPath)
    end
end

-- Default behavior if no role is assigned or role script finishes
worker_messaging.setStatus("idle")

local function WorkerStatusApp()
    local status = worker_messaging.getStatus()
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = "--- Worker Computer ---" }),
        compose.Text({ text = "ID: " .. os.getComputerID() }),
        compose.Text({ text = "Manager: " .. (worker_messaging.getManagerId() or "N/A") }),
        compose.Text({ text = "Status: " .. status:get() })
    })
end

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(WorkerStatusApp, monitor)
end

local function messageListenerTask()
    worker_messaging.start()
end

local tasks = {messageListenerTask}

local monitor = peripheral.find("monitor")
if monitor then
    table.insert(tasks, composeAppTask)
end

parallel.waitForAll(unpack(tasks))
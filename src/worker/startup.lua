-- Worker startup script

-- Load shared APIs using require
local compose = require("compose.src.compose")
local protocol = require("manager.src.common.protocol")
local config = require("manager.src.common.config")
local network = require("manager.src.common.network")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

-- How often to send a heartbeat to the manager (in seconds)
local heartbeatRate = 10
-- How long to wait for a manager to respond to registration (in seconds)
local registrationTimeout = 5

--[[--------------------------------------------------------------------------
                                INITIALIZATION
----------------------------------------------------------------------------]]

local status = compose.remember("booting", "workerStatus")
local managerId = nil

local function setStatus(newStatus)
    status:set(newStatus)
end

local function doTask(task)
    local scriptPath = task.script and "manager/src/" .. task.script or nil

    if not scriptPath then
        print("Error: Task received without a script path.")
        setStatus("idle")
        return { success = false, result = "No script path provided." }
    elseif not fs.exists(scriptPath) then
        print("Error: Script not found at " .. scriptPath)
        return { success = false, result = "Script not found." }
    end

    setStatus("working: " .. task.name)
    print("Executing task: " .. task.name .. " (script: " .. scriptPath .. ")")

    local success, result = pcall(shell.run, scriptPath, unpack(task.params or {}))

    if success then
        print("Task completed.")
        return { success = true, result = result }
    else
        print("Task failed: " .. tostring(result) )
        return { success = false, result = tostring(result) }
    end
end

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
        setStatus("searching for manager")
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
                    config.save({ managerId = managerId }) -- Save the manager ID
                    print("Registered with manager: " .. managerId)
                    done = true
                end
            elseif event == "timer" and p1 == responseTimer then
                done = true -- Timeout expired
            end
        end

        if not managerId then
            setStatus("manager not found")
            os.sleep(10) -- Wait before retrying
        end
    end
end

-- Load the config module from the newly cloned manager directory
local cfg = config.load()

-- Start registration process
registerWithManager()

-- Load and execute persistent role on startup
if cfg.secondaryRole then
    print("Loading persistent role: " .. cfg.secondaryRole.displayName)
    local task = {
        name = "assign_role",
        script = "worker/roles/" .. cfg.secondaryRole.name .. ".lua",
        params = {}
    }
    doTask(task)
end

setStatus("idle")

local function messageListenerTask()
    -- Start heartbeat timer
    local heartbeatTimer = os.startTimer(heartbeatRate)

    -- Open for messages
    network.open(os.getComputerID())

    -- Main event loop
    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent() -- Get all events

        if event == "terminate" then
            print("Shutting down...")
            network.close(protocol.id)
            return

        elseif event == "timer" and p1 == heartbeatTimer then
            network.send(managerId, os.getComputerID(), protocol.serialize({ type = "HEARTBEAT", status = status:get() }))
            heartbeatTimer = os.startTimer(heartbeatRate) -- Restart timer

        elseif event == "modem_message" then
            local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
            local msg = textutils.unserializeJSON(message_raw) -- Deserialize the message

            if replyChannel == managerId then
                if msg and msg.type == "TASK" then -- Removed protocol check
                    local taskResult = doTask(msg)
                    network.send(managerId, os.getComputerID(), {
                        type = "TASK_RESULT",
                        success = taskResult.success,
                        result = taskResult.result
                    })
                    setStatus("idle")
                elseif msg and msg.type == "COMMAND" and msg.command == "clear_role" then
                    cfg.secondaryRole = nil
                    config.save(cfg)
                    setStatus("idle")
                    print("Role cleared by manager.")
                elseif msg and msg.type == "SET_ROLE" then
                    cfg.secondaryRole = msg.role -- Update the role in config
                    config.save(cfg)
                    print("Role updated to: " .. msg.role.displayName)
                    local task = {
                        name = "assign_role",
                        script = "worker/roles/" .. msg.role.name .. ".lua",
                        params = {}
                    }
                    doTask(task)
                    setStatus("working: " .. msg.role.displayName)
                end
            end
        end
    end
end

local function WorkerStatusApp()
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = "--- Worker Computer ---" }),
        compose.Text({ text = "ID: " .. os.getComputerID() }),
        compose.Text({ text = "Manager: " .. (managerId or "N/A") }),
        compose.Text({ text = "Status: " .. status:get() })
    })
end

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(WorkerStatusApp, monitor)
end

local tasks = {messageListenerTask}

local monitor = peripheral.find("monitor")
if monitor then
    table.insert(tasks, composeAppTask)
end

parallel.waitForAll(unpack(tasks))
-- Worker startup script

-- Load shared APIs using require
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

local status = "booting"
local managerId = nil

local function setStatus(newStatus)
    status = newStatus
    term.clear()
    term.setCursorPos(1, 1)
    print("--- Worker Computer ---")
    print("Registered with Manager: " .. tostring(managerId))
    print("Status: " .. status)
end

local function doTask(task)
    local scriptPath = task.script
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

    local success, result = pcall(shell.run, "manager/src/" .. scriptPath, unpack(task.params or {}))

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
                if message and message.type == "REGISTER_OK" then -- Removed protocol check
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
local config = require("manager.src.common.config")

-- Load existing config, add the role, and save
local cfg = config.load()
cfg.role = "worker"
config.save(cfg)

-- Start registration process
registerWithManager()
setStatus("idle")

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
        network.send(managerId, os.getComputerID(), protocol.serialize({ type = "HEARTBEAT", status = status }))
        heartbeatTimer = os.startTimer(heartbeatRate) -- Restart timer

    elseif event == "modem_message" then
        local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5
        local message = textutils.unserializeJSON(message_raw)

        if replyChannel == managerId then
            if message and message.type == "TASK" then
                local taskResult = doTask(message)
                network.send(managerId, os.getComputerID(), protocol.serialize({
                    type = "TASK_RESULT",
                    success = taskResult.success,
                    result = taskResult.result
                }))
                setStatus("idle")
            elseif message and message.type == "COMMAND" and message.command == "clear_role" then
                cfg.role = nil
                config.save(cfg)
                setStatus("idle")
                print("Role cleared by manager.")
            end
        end
    end
end

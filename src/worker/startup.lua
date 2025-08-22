-- Worker startup script

-- Load shared APIs using require
local protocol = require("common.protocol")
local config = require("common.config")

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
        print("Task failed: " .. tostring(result))
        return { success = false, result = tostring(result) }
    end
end

--[[--------------------------------------------------------------------------
                                  MAIN LOGIC
----------------------------------------------------------------------------]]

local function registerWithManager()
    rednet.open(protocol.name)

    local savedConfig = config.load()
    if savedConfig.managerId then
        managerId = savedConfig.managerId
        print("Loaded manager ID from config: " .. managerId)
    end

    while not managerId do
        setStatus("searching for manager")
        rednet.broadcast(protocol.serialize({ type = "REGISTER" }), protocol.name)

        local responseTimer = os.startTimer(registrationTimeout)
        local done = false
        while not done do
            local event, p1, p2 = os.pullEvent()
            if event == "rednet_message" then
                local senderId, message = p1, p2
                local msg = protocol.deserialize(message)
                if msg and msg.type == "REGISTER_OK" then
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

-- Start registration process
registerWithManager()
setStatus("idle")

-- Start heartbeat timer
local heartbeatTimer = os.startTimer(heartbeatRate)

-- Main event loop
while true do
    local event, p1, p2 = os.pullEvent()

    if event == "terminate" then
        print("Shutting down...")
        rednet.close(protocol.name)
        return

    elseif event == "timer" and p1 == heartbeatTimer then
        rednet.send(managerId, protocol.serialize({ type = "HEARTBEAT", status = status }), protocol.name)
        heartbeatTimer = os.startTimer(heartbeatRate) -- Restart timer

    elseif event == "rednet_message" then
        local senderId, message = p1, p2
        if senderId == managerId then
            local msg = protocol.deserialize(message)
            if msg and msg.type == "TASK" then
                local taskResult = doTask(msg)
                rednet.send(managerId, protocol.serialize({
                    type = "TASK_RESULT",
                    success = taskResult.success,
                    result = taskResult.result
                }), protocol.name)
                setStatus("idle")
            end
        end
    end
end

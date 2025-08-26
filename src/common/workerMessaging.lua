-- common/workerMessaging.lua
local network = require("manager.src.common.network")
local config = require("manager.src.common.config")
local protocol = require("manager.src.common.protocol")
local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")

local M = {}

local status = compose.remember("booting", "workerStatus")
local managerId = nil

function M.setStatus(newStatus)
    status:set(newStatus)
end

function M.getStatus()
    return status
end

function M.getManagerId()
    return managerId
end

function M.setManagerId(id)
    managerId = id
end

local function executeScript(scriptPath, params)
    local requirePath = (scriptPath):gsub(".lua", ""):gsub("/", ".")
    local script = require(requirePath)
    local success, result = pcall(function() script.execute(unpack(params or {})) end)
    return success, result
end

local function doTask(task)
    local scriptPath = task.script and "manager/src/" .. task.script or nil

    if not scriptPath then
        print("Error: Task received without a script path.")
        M.setStatus("idle")
        return { success = false, result = "No script path provided." }
    elseif not fs.exists(scriptPath) then
        print("Error: Script not found at " .. scriptPath)
        return { success = false, result = "Script not found." }
    end

    M.setStatus("working: " .. task.name)
    print("Executing task: " .. task.name .. " (script: " .. scriptPath .. ")")

    local success, result
    ui.withLoading("Executing " .. task.name, function()
        success, result = executeScript(scriptPath, task.params)
    end)

    if success then
        print("Task completed.")
        return { success = true, result = result }
    else
        print("Task failed: " .. tostring(result))
        return { success = false, result = tostring(result) }
    end
end

function M.start(options)
    local messageHandler = options and options.messageHandler
    local periodicTask = options and options.periodicTask
    local taskInterval = options and options.taskInterval or 5

    local heartbeatRate = 10
    local heartbeatTimer = os.startTimer(heartbeatRate)
    local periodicTimer = nil
    if periodicTask then
        periodicTimer = os.startTimer(taskInterval)
    end

    network.open(os.getComputerID())

    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent()

        if event == "terminate" then
            print("Shutting down...")
            network.close(protocol.id)
            return
        elseif event == "timer" and p1 == heartbeatTimer then
            network.send(managerId, os.getComputerID(), protocol.serialize({ type = "HEARTBEAT", status = status:get() }))
            heartbeatTimer = os.startTimer(heartbeatRate)
        elseif periodicTimer and event == "timer" and p1 == periodicTimer then
            periodicTask()
            periodicTimer = os.startTimer(taskInterval)
        elseif event == "modem_message" then
            local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5
            local msg = textutils.unserializeJSON(message_raw)

            if replyChannel == managerId then
                if msg and msg.type == "TASK" then
                    local taskResult = doTask(msg)
                    network.send(managerId, os.getComputerID(), {
                        type = "TASK_RESULT",
                        success = taskResult.success,
                        result = taskResult.result
                    })
                    M.setStatus("idle")
                elseif msg and msg.type == "COMMAND" and msg.command == "clear_role" then
                    local cfg = config.load()
                    cfg.secondaryRole = nil
                    config.save(cfg)
                    M.setStatus("idle")
                    -- Send success reply before rebooting
                    network.send(replyChannel, os.getComputerID(), {
                        isReply = true,
                        replyTo = msg.requestId,
                        payload = { status = "success" }
                    })
                    print("Role cleared by manager. Rebooting.")
                    os.reboot()
                elseif msg and msg.type == "COMMAND" and msg.command == "update" then
                    print("Received update command. Running update script.")
                    shell.run("manager/update.lua")
                elseif msg and msg.type == "SET_ROLE" then
                    local cfg = config.load()
                    cfg.secondaryRole = msg.role
                    config.save(cfg)
                    print("Role updated to: " .. msg.role.displayName .. ". Rebooting.")
                    os.reboot()
                elseif messageHandler then
                    messageHandler(msg, replyChannel)
                end
            end
        end
    end
end

return M

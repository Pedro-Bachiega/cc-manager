-- Manager startup script

local compose = require("compose.src.compose")
local coroutineUtils = require("manager.src.common.coroutineUtils")
local network = require("manager.src.common.network")
local protocol = require("manager.src.common.protocol")
local taskQueue = require("manager.src.common.taskQueue")
local ManagerViewModel = require("manager.src.manager.viewModel.managerViewModel")
local managerView = require("manager.src.manager.view.managerView")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

-- How often the screen updates and we check for disconnected workers (in seconds)
local tickRate = 5
-- How long to wait for a heartbeat before marking a worker as disconnected (in seconds)
local disconnectTimeout = 15

--[[--------------------------------------------------------------------------
                                  MAIN LOOP
----------------------------------------------------------------------------]]

local viewModel = ManagerViewModel:new()

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(function() return managerView.App(viewModel) end, monitor)
end

local function messageListenerTask()
    network.open(protocol.id) -- Open the protocol using our wrapper

    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent()                              -- Get all events
        if event == "modem_message" then
            local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
            local message = protocol.deserialize(message_raw)                        -- Deserialize the message
            -- Try to dispatch as a reply first
            local wasReply = network.dispatch(replyChannel, message)
            if not wasReply then
                -- If it wasn't a reply, handle as a regular message
                viewModel:handleRednetMessage(replyChannel, message)
            end
        end
    end
end

local function inputTask()
    while true do
        local command = read()
        local parts = {}
        for part in command:gmatch("%S+") do table.insert(parts, part) end

        if parts[1] == "update" then
            shell.run("manager/update.lua")
        end
    end
end

local function saveStateTask()
    while true do
        sleep(10) -- Save every 10 seconds
        viewModel:saveState()
    end
end

local function workerStatusUpdateTask()
    while true do
        sleep(tickRate)
        viewModel:updateWorkerStatus(disconnectTimeout)
    end
end

parallel.waitForAll(composeAppTask, messageListenerTask, inputTask, saveStateTask, workerStatusUpdateTask,
taskQueue.runTaskWorker, coroutineUtils.coroutineScheduler, network.runUpdateTask)
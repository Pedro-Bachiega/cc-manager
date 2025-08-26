-- Mob Spawner Controller Role

local compose = require("compose.src.compose")
local coroutineUtils = require("manager.src.common.coroutineUtils")
local network = require("manager.src.common.network")
local taskQueue = require("manager.src.common.taskQueue")
local workerMessaging = require("manager.src.common.workerMessaging")
local MobSpawnerControllerViewModel = require("manager.src.worker.viewModel.mobSpawnerControllerViewModel")
local MobSpawnerControllerView = require("manager.src.worker.view.mobSpawnerControllerView")

local M = {}

function M.run()
    workerMessaging.setStatus("running mob spawner controller")

    local viewModel = MobSpawnerControllerViewModel:new()

    -- Initial setup
    if viewModel.redstoneSide:get() ~= nil then
        viewModel:setSpawnerState(viewModel.spawnerEnabled:get())
    end

    local function composeAppTask()
        local monitor = peripheral.find("monitor") or error("No monitor found", 0)
        compose.render(function() return MobSpawnerControllerView.App(viewModel) end, monitor)
    end

    local function messageHandler(message, replyChannel)
        if message.role == "mob_spawner_controller" and message.command == "toggle_state" then
            viewModel:toggleSpawner()
            network.send(replyChannel, os.getComputerID(), {
                isReply = true,
                replyTo = message.requestId,
                payload = { status = "success" }
            })
        end
    end

    local function messageListenerTask()
        workerMessaging.start({
            messageHandler = messageHandler
        })
    end

    local tasks = {messageListenerTask, taskQueue.runTaskWorker, coroutineUtils.coroutineScheduler}
    local monitor = peripheral.find("monitor")
    if monitor then
        table.insert(tasks, composeAppTask)
    end

    parallel.waitForAll(unpack(tasks))
end

return M
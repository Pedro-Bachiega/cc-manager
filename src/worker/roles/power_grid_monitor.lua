-- Power Grid Monitor Role

local compose = require("compose.src.compose")
local workerMessaging = require("manager.src.common.workerMessaging")
local PowerGridMonitorViewModel = require("manager.src.worker.viewModel.powerGridMonitorViewModel")
local PowerGridMonitorView = require("manager.src.worker.view.powerGridMonitorView")

-- How often to update the item counts (in seconds)
local updateInterval = 5

local M = {}

function M.run()
    workerMessaging.setStatus("running power grid monitor")

    local viewModel = PowerGridMonitorViewModel:new()
    viewModel:askForEnergyCellName()

    -- Initial setup
    viewModel:getPowerLevel()

    local function composeAppTask()
        local monitor = peripheral.find("monitor") or error("No monitor found", 0)
        compose.render(function() return PowerGridMonitorView.App(viewModel) end, monitor)
    end

    local function messageHandler(message)
        if message.role == "power_grid_monitor" then
            if message.command == "add_machine" then
                viewModel:addMachine(message.payload.side, message.payload.name)
            elseif message.command == "remove_machine" then
                viewModel:removeMachine(message.payload.side)
            elseif message.command == "set_machine_state" then
                viewModel:setMachineState(message.payload.side, message.payload.enabled)
            end
        end
    end

    local function messageListenerTask()
        workerMessaging.start({
            messageHandler = messageHandler,
            periodicTask = function() viewModel:getPowerLevel() end,
            taskInterval = updateInterval
        })
    end

    local monitor = peripheral.find("monitor")
    if monitor then
        parallel.waitForAll(composeAppTask, messageListenerTask)
    else
        messageListenerTask()
    end
end

return M
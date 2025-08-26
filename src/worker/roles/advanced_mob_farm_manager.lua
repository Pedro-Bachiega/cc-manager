-- Advanced Mob Farm Manager Role

local compose = require("compose.src.compose")
local workerMessaging = require("manager.src.common.workerMessaging")
local AdvancedMobFarmManagerViewModel = require("manager.src.worker.viewModel.advancedMobFarmManagerViewModel")
local AdvancedMobFarmManagerView = require("manager.src.worker.view.advancedMobFarmManagerView")

-- How often to update the item counts (in seconds)
local updateInterval = 5

local M = {}

function M.run()
    workerMessaging.setStatus("running advanced mob farm manager")

    local viewModel = AdvancedMobFarmManagerViewModel:new()
    viewModel:askForContainerName()

    -- Initial setup
    if viewModel.redstoneSide:get() ~= nil then
        viewModel:setFarmState(viewModel.farmEnabled:get())
        viewModel:countItems()
    end

    local function composeAppTask()
        local monitor = peripheral.find("monitor") or error("No monitor found", 0)
        compose.render(function() return AdvancedMobFarmManagerView.App(viewModel) end, monitor)
    end

    local function messageHandler(message)
        if message.role == "advanced_mob_farm_manager" and message.command == "set_state" then
            if message.payload and message.payload.enabled ~= nil then
                viewModel:setFarmState(message.payload.enabled)
            end
        end
    end

    local function messageListenerTask()
        workerMessaging.start({
            messageHandler = messageHandler,
            periodicTask = function() viewModel:countItems() end,
            taskInterval = updateInterval
        })
    end

    parallel.waitForAll(composeAppTask, messageListenerTask)
end

return M
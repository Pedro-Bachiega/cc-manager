-- Advanced Mob Farm Manager Role

local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")
local worker_messaging = require("manager.src.common.worker_messaging")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

-- How often to update the item counts (in seconds)
local updateInterval = 5

--[[--------------------------------------------------------------------------
                                  LOGIC
----------------------------------------------------------------------------]]

local itemCounts = compose.remember({}, "itemCounts", true)
local chosenContainer = compose.remember(nil, "chosenContainer", true)
local farmEnabled = compose.remember(false, "farmEnabled", true)
local redstoneSide = compose.remember(nil, "redstoneSide", true)

local term = peripheral.find("monitor") or term

local function askForContainerName()
    if chosenContainer:get() == nil then
        term.write("Enter inventory peripheral name (default: minecraft:chest): ")
        local input = term.read()
        local containerName = input and input:len() > 0 and input or "minecraft:chest"
        chosenContainer:set(containerName)
    end
end

local function setFarmState(enabled)
    local side = redstoneSide:get()
    if side then
        redstone.setOutput(side, enabled)
    end
    farmEnabled:set(enabled)
end

local function toggleFarm()
    local newStatus = not farmEnabled:get()
    setFarmState(newStatus)
end

local function countItems()
    local peripheralName = chosenContainer:get()
    if not peripheralName then
        return
    end
    local p = peripheral.wrap(peripheralName)
    if not p or not p.list then
        print("Error: Could not find a valid inventory peripheral named '" .. peripheralName .. "'")
        return
    end

    local items = p.list()
    local newCounts = {}
    for slot, item in pairs(items) do
        if item then
            local currentCount = newCounts[item.name] or 0
            newCounts[item.name] = currentCount + item.count
        end
    end
    itemCounts:set(newCounts)
end

--[[--------------------------------------------------------------------------
                                  UI
----------------------------------------------------------------------------]]

local function MainView()
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center
    }, {
        compose.Text({ text = "--- Advanced Mob Farm Manager ---" }),
        compose.Row({}, {
            compose.Text({ text = "Farm Status: " }),
            farmEnabled:get(function(enabled)
                local statusText = enabled and "ON" or "OFF"
                local statusColor = enabled and colors.green or colors.red
                return compose.Text({ text = statusText, textColor = statusColor })
            end)
        }),
        compose.Button({
            text = "Toggle Farm",
            onClick = toggleFarm
        }),
        compose.Column({
            modifier = compose.Modifier:new():fillMaxSize()
        }, {
            compose.Text({ text = "Item Count" }),
            -- Table data
            itemCounts:get(function(currentItems)
                local rows = {}
                for name, count in pairs(currentItems) do
                    table.insert(rows, compose.Row({}, {
                        compose.Text({ text = name }),
                        compose.Text({ text = tostring(count) })
                    }))
                end
                return compose.Column({}, rows)
            end)
        }),
        chosenContainer:get(function(container)
            local text = container and ("Selected Container: " .. container) or "No Container Selected"
            local textColor = container and colors.white or colors.red
            return compose.Text({ text = text, textColor = textColor })
        end)
    })
end

local function App()
    if redstoneSide:get() == nil then
        return ui.SideSelector(compose, function(side) redstoneSide:set(side) end)
    else
        return MainView()
    end
end

--[[--------------------------------------------------------------------------
                                  MAIN LOOP
----------------------------------------------------------------------------]]

local M = {}

function M.run()
    worker_messaging.setStatus("running advanced mob farm manager")
    askForContainerName()

    -- Initial setup
    if redstoneSide:get() ~= nil then
        setFarmState(farmEnabled:get())
        countItems()
    end

    local function composeAppTask()
        local monitor = peripheral.find("monitor") or error("No monitor found", 0)
        compose.render(App, monitor)
    end

    local function messageHandler(message)
        if message.role == "advanced_mob_farm_manager" and message.command == "set_state" then
            if message.payload and message.payload.enabled ~= nil then
                setFarmState(message.payload.enabled)
            end
        end
    end

    local function messageListenerTask()
        worker_messaging.start({
            messageHandler = messageHandler,
            periodicTask = countItems,
            taskInterval = updateInterval
        })
    end

    parallel.waitForAll(composeAppTask, messageListenerTask)
end

return M
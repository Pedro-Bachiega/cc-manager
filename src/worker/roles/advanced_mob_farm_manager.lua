-- Advanced Mob Farm Manager Role

local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")
local network = require("manager.src.common.network")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

-- How often to update the item counts (in seconds)
local updateInterval = 5
local controlProtocol = 54321

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

askForContainerName()

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
    local peripheral = peripheral.wrap(chosenContainer:get())
    if not peripheral or not peripheral.list then
        print("Error: Could not find a valid inventory peripheral named '" .. chosenContainer:get() .. "'")
        return
    end

    local items = peripheral.list()
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
                        compose.Text({ text = count })
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

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(App, monitor)
end

local function periodicUpdateTask()
    network.open(controlProtocol)

    local timer = os.startTimer(updateInterval)
    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent() -- Get all events

        if event == "terminate" then
            compose.exit() -- Signal compose app to terminate
            network.close(controlProtocol)
            return
        elseif event == "timer" and p1 == timer then
            if redstoneSide:get() ~= nil then
                countItems() -- This will update the itemCounts state and trigger recomposition
            end
            timer = os.startTimer(updateInterval)
        elseif event == "modem_message" then
            local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
            local message = textutils.unserializeJSON(message_raw) -- Deserialize the message
            if message.role == "advanced_mob_farm_manager" and message.command == "set_state" then
                if message.payload and message.payload.enabled ~= nil then
                    setFarmState(message.payload.enabled)
                end
            end
        end
    end
end

local S = {}

function S.execute()
    -- Initial setup
    if redstoneSide:get() ~= nil then
        setFarmState(farmEnabled:get())
        countItems()
    end

    -- Run both tasks in parallel
    parallel.waitForAll(composeAppTask, periodicUpdateTask)
end

return S
-- Mob Spawner Controller Role

local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

local controlProtocol = "worker_control"

--[[--------------------------------------------------------------------------
                                  LOGIC
----------------------------------------------------------------------------]]

local spawnerEnabled = compose.remember(false, "spawnerEnabled", true)
local redstoneSide = compose.remember(nil, "redstoneSide", true)

local function setSpawnerState(enabled)
    local side = redstoneSide:get()
    if side then
        redstone.setOutput(side, enabled)
    end
    spawnerEnabled:set(enabled)
end

local function toggleSpawner()
    local newStatus = not spawnerEnabled:get()
    setSpawnerState(newStatus)
end

--[[--------------------------------------------------------------------------
                                  UI
----------------------------------------------------------------------------]]

local function MainView()
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = "--- Mob Spawner Controller ---" }),
        compose.Row({}, {
            compose.Text({ text = "Spawner Status: " }),
            spawnerEnabled:get(function(enabled)
                local statusText = enabled and "ON" or "OFF"
                local statusColor = enabled and colors.green or colors.red
                return compose.Text({ text = statusText, textColor = statusColor })
            end)
        }),
        compose.Button({
            text = "Toggle Spawner",
            onClick = toggleSpawner
        })
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

local function messageListenerTask()
    local modem = peripheral.find("modem", rednet.open)
    if not modem then
        error("No wireless modem found. Please attach one to the computer.")
    end
    while true do
        local event, senderId, message, protocol = os.pullEvent("rednet_message")
        if protocol == controlProtocol then
            if message.role == "mob_spawner_controller" and message.command == "toggle_state" then
                toggleSpawner()
            end
        end
    end
end

-- Initial setup
if redstoneSide:get() ~= nil then
    setSpawnerState(spawnerEnabled:get())
end

local monitor = peripheral.find("monitor")
if monitor then
    parallel.waitForAll(composeAppTask, messageListenerTask)
else
    -- No monitor attached, just listen for messages
    messageListenerTask()
end

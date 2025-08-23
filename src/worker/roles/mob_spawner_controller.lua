-- Mob Spawner Controller Role

local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")
local network = require("manager.src.common.network")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

local controlProtocol = 54321

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
    network.open(controlProtocol)
    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent() -- Get all events
        if event == "modem_message" then
            local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
            local message = textutils.unserializeJSON(message_raw) -- Deserialize the message
            print("Received message: " .. textutils.serializeJSON(message))
            if message.role == "mob_spawner_controller" and message.command == "toggle_state" then
                toggleSpawner()
                print("Toggled spawner state to: " .. tostring(spawnerEnabled:get()))
            end
        end
    end
end

local S = {}

function S.execute()
    -- Initial setup
    if redstoneSide:get() ~= nil then
        setSpawnerState(spawnerEnabled:get())
    end

    local monitor = peripheral.find("monitor")
    local tasks = {messageListenerTask}

    if monitor then
        table.insert(tasks, composeAppTask)
    end

    parallel.waitForAll(unpack(tasks))
end

return S
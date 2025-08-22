-- Power Grid Monitor Role

local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

local updateInterval = 5
local controlProtocol = "worker_control"

--[[--------------------------------------------------------------------------
                                  LOGIC
----------------------------------------------------------------------------]]

local powerLevel = compose.remember(0, "powerLevel")
local energyCellName = compose.remember(nil, "energyCellName", true)
local controlledMachines = compose.remember({}, "controlledMachines", true)

local term = peripheral.find("monitor") or term

local function askForEnergyCellName()
    if energyCellName:get() == nil then
        term.write("Enter the peripheral name of the Powah energy cell: ")
        local name = term.read()
        energyCellName:set(name)
    end
end

askForEnergyCellName()

local function getPowerLevel()
    local cell = peripheral.wrap(energyCellName:get())
    if cell and cell.getEnergy and cell.getMaxEnergy then
        local current = cell.getEnergy()
        local max = cell.getMaxEnergy()
        if max > 0 then
            powerLevel:set(current / max)
        end
    else
        print("Error: Could not find a valid Powah energy cell named '" .. energyCellName:get() .. "'")
    end
end

local function setMachineState(side, enabled)
    redstone.setOutput(side, enabled)
    local machines = controlledMachines:get()
    if machines[side] then
        machines[side].enabled = enabled
        controlledMachines:set(machines)
    end
end

--[[--------------------------------------------------------------------------
                                  UI
----------------------------------------------------------------------------]]

local function MainView()
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center
    }, {
        compose.Text({ text = "--- Power Grid Monitor ---" }),
        compose.Row({}, {
            compose.Text({ text = "Power Level: " }),
            powerLevel:get(function(level)
                return compose.Text({ text = string.format("%.2f%%", level * 100) })
            end)
        }),
        compose.Text({ text = "Controlled Machines:"}),
        controlledMachines:get(function(machines)
            local rows = {}
            for side, data in pairs(machines) do
                table.insert(rows, compose.Row({}, {
                    compose.Text({ text = data.machine_name .. " (" .. side .. "): " }),
                    compose.Text({ text = data.enabled and "ON" or "OFF" }),
                    compose.Button({ text = "Toggle", onClick = function() setMachineState(side, not data.enabled) end })
                }))
            end
            return compose.Column({}, rows)
        end)
    })
end

--[[--------------------------------------------------------------------------
                                  MAIN LOOP
----------------------------------------------------------------------------]]

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(MainView, monitor)
end

local function messageListenerTask()
    rednet.open(controlProtocol)
    while true do
        local event, senderId, message, protocol = os.pullEvent("rednet_message")
        if protocol == controlProtocol then
            if message.role == "power_grid_monitor" then
                if message.command == "add_machine" then
                    local machines = controlledMachines:get()
                    machines[message.payload.side] = {
                        machine_name = message.payload.name,
                        enabled = true
                    }
                    controlledMachines:set(machines)
                elseif message.command == "remove_machine" then
                    local machines = controlledMachines:get()
                    machines[message.payload.side] = nil
                    controlledMachines:set(machines)
                elseif message.command == "set_machine_state" then
                    setMachineState(message.payload.side, message.payload.enabled)
                end
            end
        end
    end
end

local function periodicUpdateTask()
    local timer = os.startTimer(updateInterval)
    while true do
        local event, p1 = os.pullEvent("timer")
        if p1 == timer then
            getPowerLevel()
            timer = os.startTimer(updateInterval)
        end
    end
end

-- Initial setup
getPowerLevel()

local monitor = peripheral.find("monitor")
if monitor then
    parallel.waitForAll(composeAppTask, messageListenerTask, periodicUpdateTask)
else
    -- No monitor attached, just listen for messages and update power level
    parallel.waitForAll(messageListenerTask, periodicUpdateTask)
end

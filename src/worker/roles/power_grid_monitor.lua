-- Power Grid Monitor Role

local compose = require("compose.src.compose")
local worker_messaging = require("manager.src.common.worker_messaging")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

local updateInterval = 5

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

local function getPowerLevel()
    local cellName = energyCellName:get()
    if not cellName then
        return
    end
    local cell = peripheral.wrap(cellName)
    if cell and cell.getEnergy and cell.getMaxEnergy then
        local current = cell.getEnergy()
        local max = cell.getMaxEnergy()
        if max > 0 then
            powerLevel:set(current / max)
        end
    else
        print("Error: Could not find a valid Powah energy cell named '" .. cellName .. "'")
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

local M = {}

function M.run()
    worker_messaging.setStatus("running power grid monitor")
    askForEnergyCellName()

    -- Initial setup
    getPowerLevel()

    local function composeAppTask()
        local monitor = peripheral.find("monitor") or error("No monitor found", 0)
        compose.render(MainView, monitor)
    end

    local function messageHandler(message)
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

    local function messageListenerTask()
        worker_messaging.start({
            messageHandler = messageHandler,
            periodicTask = getPowerLevel,
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
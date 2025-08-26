local compose = require("compose.src.compose")

--- @module PowerGridMonitorViewModel
--- @brief Manages the state and logic for the Power Grid Monitor worker role.
--- This ViewModel handles monitoring energy levels and controlling connected machines via redstone.

--- @class PowerGridMonitorViewModel
--- @field powerLevel State A Compose state object holding the current power level (0-1) of the energy cell.
--- @field energyCellName State A Compose state object holding the peripheral name of the energy cell to monitor.
--- @field controlledMachines State A Compose state object holding a table of controlled machines (side -> {machine_name, enabled}).
--- @field loadingText State A Compose state object holding text to display during loading operations.
local M = {}
M.__index = M

--- Creates a new PowerGridMonitorViewModel instance.
--- @return PowerGridMonitorViewModel A new instance of the ViewModel.
function M:new()
    local instance = setmetatable({}, M)
    instance.powerLevel = compose.remember(0, "powerLevel")
    instance.energyCellName = compose.remember(nil, "energyCellName", true)
    instance.controlledMachines = compose.remember({}, "controlledMachines", true)
    instance.loadingText = compose.remember(nil, "loading")
    return instance
end

--- Prompts the user to enter the peripheral name of the Powah energy cell.
function M:askForEnergyCellName()
    if self.energyCellName:get() == nil then
        local term = peripheral.find("monitor") or term
        term.write("Enter the peripheral name of the Powah energy cell: ")
        local name = term.read()
        self.energyCellName:set(name)
    end
end

--- Retrieves the current power level from the energy cell and updates the powerLevel state.
function M:getPowerLevel()
    local cellName = self.energyCellName:get()
    if not cellName then
        return
    end
    local p = peripheral.wrap(cellName)
    if p and p.getEnergy and p.getMaxEnergy then
        local current = p.getEnergy()
        local max = p.getMaxEnergy()
        if max > 0 then
            self.powerLevel:set(current / max)
        end
    else
        print("Error: Could not find a valid Powah energy cell named '" .. cellName .. "'")
    end
end

--- Sets the redstone output state for a controlled machine.
--- @param side string The side of the machine (e.g., "top", "bottom", "front").
--- @param enabled boolean True to enable (redstone high), false to disable (redstone low).
function M:setMachineState(side, enabled)
    self.loadingText:set("Setting machine state...")
    parallel.waitForAll(function()
        redstone.setOutput(side, enabled)
        local machines = self.controlledMachines:get()
        if machines[side] then
            machines[side].enabled = enabled
            self.controlledMachines:set(machines)
        end
        self.loadingText:set(nil)
    end)
end

--- Adds a machine to the list of controlled machines.
--- @param side string The side of the machine.
--- @param name string The name or description of the machine.
function M:addMachine(side, name)
    local machines = self.controlledMachines:get()
    machines[side] = {
        machine_name = name,
        enabled = true
    }
    self.controlledMachines:set(machines)
end

--- Removes a machine from the list of controlled machines.
--- @param side string The side of the machine to remove.
function M:removeMachine(side)
    local machines = self.controlledMachines:get()
    machines[side] = nil
    self.controlledMachines:set(machines)
end

--- Retrieves the current power level from the energy cell and updates the powerLevel state.
function M:getPowerLevel()
    local cellName = self.energyCellName:get()
    if not cellName then
        return
    end
    local p = peripheral.wrap(cellName)
    if p and p.getEnergy and p.getMaxEnergy then
        local current = p.getEnergy()
        local max = p.getMaxEnergy()
        if max > 0 then
            self.powerLevel:set(current / max)
        end
    else
        print("Error: Could not find a valid Powah energy cell named '" .. cellName .. "'")
    end
end

--- Sets the redstone output state for a controlled machine.
--- @param side string The side of the machine (e.g., "top", "bottom", "front").
--- @param enabled boolean True to enable (redstone high), false to disable (redstone low).
function M:setMachineState(side, enabled)
    self.loadingText:set("Setting machine state...")
    parallel.waitForAll(function()
        redstone.setOutput(side, enabled)
        local machines = self.controlledMachines:get()
        if machines[side] then
            machines[side].enabled = enabled
            self.controlledMachines:set(machines)
        end
        self.loadingText:set(nil)
    end)
end

--- Adds a machine to the list of controlled machines.
--- @param side string The side of the machine.
--- @param name string The name or description of the machine.
function M:addMachine(side, name)
    local machines = self.controlledMachines:get()
    machines[side] = {
        machine_name = name,
        enabled = true
    }
    self.controlledMachines:set(machines)
end

--- Removes a machine from the list of controlled machines.
--- @param side string The side of the machine to remove.
function M:removeMachine(side)
    local machines = self.controlledMachines:get()
    machines[side] = nil
    self.controlledMachines:set(machines)
end

return M

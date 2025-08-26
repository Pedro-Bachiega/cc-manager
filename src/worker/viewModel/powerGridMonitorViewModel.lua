local compose = require("compose.src.compose")

local M = {}
M.__index = M

function M:new()
    local instance = setmetatable({}, M)
    instance.powerLevel = compose.remember(0, "powerLevel")
    instance.energyCellName = compose.remember(nil, "energyCellName", true)
    instance.controlledMachines = compose.remember({}, "controlledMachines", true)
    instance.loadingText = compose.remember(nil, "loading")
    return instance
end

function M:askForEnergyCellName()
    if self.energyCellName:get() == nil then
        local term = peripheral.find("monitor") or term
        term.write("Enter the peripheral name of the Powah energy cell: ")
        local name = term.read()
        self.energyCellName:set(name)
    end
end

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

function M:addMachine(side, name)
    local machines = self.controlledMachines:get()
    machines[side] = {
        machine_name = name,
        enabled = true
    }
    self.controlledMachines:set(machines)
end

function M:removeMachine(side)
    local machines = self.controlledMachines:get()
    machines[side] = nil
    self.controlledMachines:set(machines)
end

return M

local compose = require("compose.src.compose")

--- @module AdvancedMobFarmManagerViewModel
--- @brief Manages the state and logic for the Advanced Mob Farm Manager worker role.
--- This ViewModel handles inventory monitoring, farm state toggling, and redstone control.

--- @class AdvancedMobFarmManagerViewModel
--- @field itemCounts State A Compose state object holding a table of item counts in the connected container.
--- @field chosenContainer State A Compose state object holding the name of the chosen inventory peripheral.
--- @field farmEnabled State A Compose state object indicating whether the mob farm is currently enabled.
--- @field redstoneSide State A Compose state object holding the side for redstone output to control the farm.
--- @field loadingText State A Compose state object holding text to display during loading operations.
local M = {}
M.__index = M

--- Creates a new AdvancedMobFarmManagerViewModel instance.
--- @return AdvancedMobFarmManagerViewModel A new instance of the ViewModel.
function M:new()
    local instance = setmetatable({}, M)
    instance.itemCounts = compose.remember({}, "itemCounts", true)
    instance.chosenContainer = compose.remember(nil, "chosenContainer", true)
    instance.farmEnabled = compose.remember(false, "farmEnabled", true)
    instance.redstoneSide = compose.remember(nil, "redstoneSide", true)
    instance.loadingText = compose.remember(nil, "loading")
    return instance
end

--- Prompts the user to enter the name of the inventory peripheral if not already chosen.
function M:askForContainerName()
    if self.chosenContainer:get() == nil then
        local term = peripheral.find("monitor") or term
        term.write("Enter inventory peripheral name (default: minecraft:chest): ")
        local input = term.read()
        local containerName = input and input:len() > 0 and input or "minecraft:chest"
        self.chosenContainer:set(containerName)
    end
end

--- Sets the state of the mob farm (enabled/disabled) via redstone output.
--- @param enabled boolean True to enable the farm, false to disable.
function M:setFarmState(enabled)
    local side = self.redstoneSide:get()
    if side then
        redstone.setOutput(side, enabled)
    end
    self.farmEnabled:set(enabled)
end

--- Toggles the current state of the mob farm.
function M:toggleFarm()
    self.loadingText:set("Toggling farm...")
    parallel.waitForAll(function()
        local newStatus = not self.farmEnabled:get()
        self:setFarmState(newStatus)
        self.loadingText:set(nil)
    end)
end

--- Counts the items in the chosen inventory peripheral and updates the itemCounts state.
function M:countItems()
    local peripheralName = self.chosenContainer:get()
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
    self.itemCounts:set(newCounts)
end

return M


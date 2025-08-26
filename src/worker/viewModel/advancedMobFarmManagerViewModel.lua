local compose = require("compose.src.compose")

local M = {}
M.__index = M

function M:new()
    local instance = setmetatable({}, M)
    instance.itemCounts = compose.remember({}, "itemCounts", true)
    instance.chosenContainer = compose.remember(nil, "chosenContainer", true)
    instance.farmEnabled = compose.remember(false, "farmEnabled", true)
    instance.redstoneSide = compose.remember(nil, "redstoneSide", true)
    instance.loadingText = compose.remember(nil, "loading")
    return instance
end

function M:askForContainerName()
    if self.chosenContainer:get() == nil then
        local term = peripheral.find("monitor") or term
        term.write("Enter inventory peripheral name (default: minecraft:chest): ")
        local input = term.read()
        local containerName = input and input:len() > 0 and input or "minecraft:chest"
        self.chosenContainer:set(containerName)
    end
end

function M:setFarmState(enabled)
    local side = self.redstoneSide:get()
    if side then
        redstone.setOutput(side, enabled)
    end
    self.farmEnabled:set(enabled)
end

function M:toggleFarm()
    self.loadingText:set("Toggling farm...")
    parallel.waitForAll(function()
        local newStatus = not self.farmEnabled:get()
        self:setFarmState(newStatus)
        self.loadingText:set(nil)
    end)
end

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

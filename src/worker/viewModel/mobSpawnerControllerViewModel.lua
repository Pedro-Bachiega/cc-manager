local compose = require("compose.src.compose")
local coroutineUtils = require("manager.src.common.coroutineUtils")
local taskQueue = require("manager.src.common.taskQueue")

local M = {}
M.__index = M

function M:new()
    local instance = setmetatable({}, M)
    instance.spawnerEnabled = compose.remember(false, "spawnerEnabled", true)
    instance.redstoneSide = compose.remember(nil, "redstoneSide", true)
    instance.loadingText = compose.remember(nil, "loading")
    return instance
end

function M:setSpawnerState(enabled)
    local side = self.redstoneSide:get()
    if side then
        redstone.setOutput(side, enabled)
    end
    self.spawnerEnabled:set(enabled)
end

function M:toggleSpawner()
    self.loadingText:set("Toggling spawner...")
    taskQueue.addTask(function()
        local newStatus = not self.spawnerEnabled:get()
        self:setSpawnerState(newStatus)
        coroutineUtils.delay(1)
        self.loadingText:set(nil)
    end)
end

return M

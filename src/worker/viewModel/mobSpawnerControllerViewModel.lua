local compose = require("compose.src.compose")
local coroutineUtils = require("manager.src.common.coroutineUtils")
local taskQueue = require("manager.src.common.taskQueue")

--- @module MobSpawnerControllerViewModel
--- @brief Manages the state and logic for the Mob Spawner Controller worker role.
--- This ViewModel handles toggling the spawner state via redstone.

--- @class MobSpawnerControllerViewModel
--- @field spawnerEnabled State A Compose state object indicating whether the mob spawner is currently enabled.
--- @field redstoneSide State A Compose state object holding the side for redstone output to control the spawner.
--- @field loadingText State A Compose state object holding text to display during loading operations.
local M = {}
M.__index = M

--- Creates a new MobSpawnerControllerViewModel instance.
--- @return MobSpawnerControllerViewModel A new instance of the ViewModel.
function M:new()
    local instance = setmetatable({}, M)
    instance.spawnerEnabled = compose.remember(false, "spawnerEnabled", true)
    instance.redstoneSide = compose.remember(nil, "redstoneSide", true)
    instance.loadingText = compose.remember(nil, "loading")
    return instance
end

--- Sets the state of the mob spawner (enabled/disabled) via redstone output.
--- @param enabled boolean True to enable the spawner, false to disable.
function M:setSpawnerState(enabled)
    local side = self.redstoneSide:get()
    if side then
        redstone.setOutput(side, enabled)
    end
    self.spawnerEnabled:set(enabled)
end

--- Toggles the current state of the mob spawner.
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

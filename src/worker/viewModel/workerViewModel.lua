local workerMessaging = require("manager.src.common.workerMessaging")

--- @module WorkerViewModel
--- @brief Manages the state and display for a Worker computer's UI.
--- This ViewModel provides access to the worker's current status and manager connection details.

--- @class WorkerViewModel
--- @field status State A Compose state object holding the worker's current status (e.g., "online", "idle").
--- @field managerId number The ID of the manager computer this worker is connected to.
local M = {}
M.__index = M

--- Creates a new WorkerViewModel instance.
--- @return WorkerViewModel A new instance of the ViewModel.
function M:new()
    local instance = setmetatable({}, M)
    instance.status = workerMessaging.getStatus()
    instance.managerId = workerMessaging.getManagerId()
    return instance
end

--- Retrieves the worker's current status.
--- @return string The current status of the worker.
function M:getStatus()
    return self.status:get()
end

--- Retrieves the ID of the manager computer.
--- @return number The ID of the manager computer.
function M:getManagerId()
    return self.managerId
end

return M

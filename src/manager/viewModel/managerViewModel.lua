local compose = require("compose.src.compose")
local workerService = require("manager.src.manager.services.workerService")
local coroutineUtils = require("manager.src.common.coroutineUtils")
local network = require("manager.src.common.network")
local protocol = require("manager.src.common.protocol")

--- @module ManagerViewModel
--- @brief Manages the state and logic for the Manager computer's UI.
--- This ViewModel interacts with the WorkerService to orchestrate worker computers,
--- handle Rednet messages, and manage the application's UI state.

--- @class ManagerViewModel
--- @field workers State A Compose state object holding a table of worker data (id, status, last_heartbeat).
--- @field assignedRoles State A Compose state object holding a table of assigned roles for workers (workerId -> role).
--- @field selectedWorkerId State A Compose state object holding the ID of the currently selected worker.
--- @field loadingText State A Compose state object holding text to display during loading operations.
local M = {}
M.__index = M

--- Creates a new ManagerViewModel instance.
--- @return ManagerViewModel A new instance of the ManagerViewModel.
function M:new()
    local instance = setmetatable({}, M)

    local initialWorkers, initialAssignedRoles = workerService.loadInitialData()
    instance.workers = compose.remember(initialWorkers, "workers", true)
    instance.assignedRoles = compose.remember(initialAssignedRoles, "assignedRoles", true)
    instance.selectedWorkerId = compose.remember(nil, "selectedWorkerId")
    instance.loadingText = compose.remember(nil, "loading", true)

    if instance.loadingText:get() then instance.loadingText:set(nil) end

    return instance
end

--- Selects a worker by its ID.
--- @param workerId number The ID of the worker to select.
function M:selectWorker(workerId)
    self.selectedWorkerId:set(workerId)
end

--- Clears the currently selected worker.
function M:clearSelection()
    self.selectedWorkerId:set(nil)
end

--- Assigns a role to the currently selected worker.
--- @param role table The role to assign. Expected to have a 'name' field.
function M:assignRole(role)
    local workerId = self.selectedWorkerId:get()
    if not workerId then return end

    self.loadingText:set("Assigning role...")
    workerService.assignRole(workerId, role)
    coroutineUtils.delay(2)
    self.loadingText:set(nil)
    self:clearSelection()
end

--- Updates the currently selected worker by sending an update command.
function M:updateSelectedWorker()
    local workerId = self.selectedWorkerId:get()
    if not workerId then return end

    self.loadingText:set("Updating worker...")
    workerService.updateWorker(workerId,
        function(senderId, payload)
            if payload.status == "success" then
                self.loadingText:set("Worker updated.")
                self:clearSelection()
            else
                self.loadingText:set("Error: " .. (payload.message or "Unknown"))
            end
            coroutineUtils.delay(1)
            self.loadingText:set(nil)
        end,
        function()
            self.loadingText:set("Error: Request timed out.")
            coroutineUtils.delay(1)
            self.loadingText:set(nil)
        end
    )
end

--- Clears the assigned role for the currently selected worker.
function M:clearRoleForSelectedWorker()
    local workerId = self.selectedWorkerId:get()
    if not workerId then return end

    self.loadingText:set("Clearing role...")
    workerService.clearRole(workerId,
        function(senderId, payload)
            if payload.status == "success" then
                local currentAssignedRoles = self.assignedRoles:get()
                currentAssignedRoles[workerId] = nil
                self.assignedRoles:set(currentAssignedRoles)
                self.loadingText:set("Role cleared.")
                self:clearSelection()
            else
                self.loadingText:set("Error: " .. (payload.message or "Unknown"))
            end
            coroutineUtils.delay(1)
            self.loadingText:set(nil)
        end,
        function()
            self.loadingText:set("Error: Request timed out.")
            coroutineUtils.delay(1)
            self.loadingText:set(nil)
        end
    )
end

--- Toggles the state (e.g., on/off) for the currently selected worker's assigned role.
function M:toggleStateForSelectedWorker()
    local workerId = self.selectedWorkerId:get()
    if not workerId then return end

    local role = self.assignedRoles:get()[workerId]
    if not role then return end

    self.loadingText:set("Toggling state...")
    workerService.toggleWorkerState(workerId, role.name,
        function(senderId, payload)
            if payload.status == "success" then
                self.loadingText:set("State toggled.")
            else
                self.loadingText:set("Error: " .. (payload.message or "Unknown"))
            end
            coroutineUtils.delay(1)
            self.loadingText:set(nil)
        end,
        function()
            self.loadingText:set("Error: Request timed out.")
            coroutineUtils.delay(1)
            self.loadingText:set(nil)
        end
    )
end

--- Handles incoming Rednet messages, updating worker status and handling registration.
--- @param senderId number The ID of the computer that sent the message.
--- @param message table The received message, expected to have a 'type' field.
function M:handleRednetMessage(senderId, message)
    if not message or not message.type then return end

    local currentWorkers = self.workers:get()

    if message.type == "REGISTER" then
        currentWorkers[senderId] = { id = senderId, status = "online", last_heartbeat = os.time() }
        network.send(senderId, os.getComputerID(), protocol.serialize({ type = "REGISTER_OK" }))
        local assignedRole = self.assignedRoles:get()[senderId]
        if assignedRole then
            workerService.assignRole(senderId, assignedRole)
        end
    elseif message.type == "HEARTBEAT" then
        if currentWorkers[senderId] then
            currentWorkers[senderId].status = message.status or "online"
            currentWorkers[senderId].last_heartbeat = os.time()
        end
    elseif message.type == "TASK_RESULT" then
        if currentWorkers[senderId] then
            currentWorkers[senderId].status = "idle"
        end
    end

    self.workers:set(currentWorkers)
end

--- Updates the status of workers based on a disconnect timeout.
-- Workers that haven't sent a heartbeat within the timeout are marked as 'disconnected'.
--- @param disconnectTimeout number The time in seconds after which a worker is considered disconnected.
function M:updateWorkerStatus(disconnectTimeout)
    local currentWorkers = self.workers:get()
    local updated = false
    for id, data in pairs(currentWorkers) do
        if data.status == "online" and os.time() - data.last_heartbeat > disconnectTimeout then
            currentWorkers[id].status = "disconnected"
            updated = true
        end
    end
    if updated then
        self.workers:set(currentWorkers)
    end
end

--- Saves the current state of workers to persistent storage.
function M:saveState()
    workerService.saveWorkersState(self.workers:get())
end

return M

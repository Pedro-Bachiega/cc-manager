--- @private
--- @brief Loads assigned roles from a file into the assignedRoles table.
local network = require("manager.src.common.network")

--- @class WorkerService
--- @brief Handles communication and data management for worker computers from the manager's perspective.
--- This service manages assigned roles, worker states, and facilitates network requests to workers.
local M = {}

--- @private
--- @brief The filename for storing assigned roles.
local assignedRolesFile = "assigned_roles.dat"
--- @private
--- @brief The filename for storing worker states.
local workersStateFile = "workers_state.dat"

--- @private
--- @brief Table holding currently assigned roles for workers.
local assignedRoles = {}

--- @private
--- @brief Saves the current assigned roles to a file.
local function saveAssignedRoles()
    local file = fs.open(assignedRolesFile, "w")
    if file then
        file.write(textutils.serialize(assignedRoles))
        file.close()
    end
end

--- @private
--- @brief Loads assigned roles from a file into the assignedRoles table.
local function loadAssignedRoles()
    local file = fs.open(assignedRolesFile, "r")
    if file then
        local content = file.readAll()
        file.close()
        assignedRoles = textutils.unserialize(content) or {}
    end
end

--- Loads initial worker data and assigned roles from persistent storage.
--- @return table initialWorkers A table of initial worker states.
--- @return table assignedRoles A table of initially assigned roles.
function M.loadInitialData()
    loadAssignedRoles()
    local initialWorkers = {}
    local file = fs.open(workersStateFile, "r")
    if file then
        local content = file.readAll()
        file.close()
        initialWorkers = textutils.unserialize(content) or {}
    end
    return initialWorkers, assignedRoles
end

--- Saves the current state of workers to persistent storage.
--- @param workers table A table containing the current states of all workers.
function M.saveWorkersState(workers)
    local file = fs.open(workersStateFile, "w")
    if file then
        file.write(textutils.serialize(workers))
        file.close()
    end
end

--- Assigns a role to a specific worker and sends a network message to the worker.
--- @param workerId number The ID of the worker computer.
--- @param role table The role to assign. Expected to have a 'name' field.
function M.assignRole(workerId, role)
    if workerId and role then
        assignedRoles[workerId] = role
        saveAssignedRoles()
        network.send(workerId, os.getComputerID(), {
            type = "SET_ROLE",
            role = role
        })
    end
end

--- Clears the assigned role for a worker and sends a network request to the worker.
--- @param workerId number The ID of the worker computer.
--- @param onSuccess fun(senderId: number, payload: table) Callback function for successful response.
--- @param onTimeout fun() Callback function for request timeout.
function M.clearRole(workerId, onSuccess, onTimeout)
    network.request(
        workerId,
        os.getComputerID(),
        { type = "COMMAND", command = "clear_role" },
        function(senderId, payload)
            if payload.status == "success" then
                assignedRoles[workerId] = nil
                saveAssignedRoles()
            end
            onSuccess(senderId, payload)
        end,
        onTimeout
    )
end

--- Sends an update command to a specific worker.
--- @param workerId number The ID of the worker computer.
--- @param onSuccess fun(senderId: number, payload: table) Callback function for successful response.
--- @param onTimeout fun() Callback function for request timeout.
function M.updateWorker(workerId, onSuccess, onTimeout)
    network.request(
        workerId,
        os.getComputerID(),
        { type = "COMMAND", command = "update" },
        onSuccess,
        onTimeout
    )
end

--- Toggles the state of a worker's assigned role (e.g., on/off) via a network request.
--- @param workerId number The ID of the worker computer.
--- @param roleName string The name of the role whose state is to be toggled.
--- @param onSuccess fun(senderId: number, payload: table) Callback function for successful response.
--- @param onTimeout fun() Callback function for request timeout.
function M.toggleWorkerState(workerId, roleName, onSuccess, onTimeout)
    network.request(
        workerId,
        os.getComputerID(),
        { role = roleName, command = "toggle_state" },
        onSuccess,
        onTimeout
    )
end

return M

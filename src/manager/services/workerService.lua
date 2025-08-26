local network = require("manager.src.common.network")

local M = {}

local assignedRolesFile = "assigned_roles.dat"
local workersStateFile = "workers_state.dat"

local assignedRoles = {}

local function saveAssignedRoles()
    local file = fs.open(assignedRolesFile, "w")
    if file then
        file.write(textutils.serialize(assignedRoles))
        file.close()
    end
end

local function loadAssignedRoles()
    local file = fs.open(assignedRolesFile, "r")
    if file then
        local content = file.readAll()
        file.close()
        assignedRoles = textutils.unserialize(content) or {}
    end
end

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

function M.saveWorkersState(workers)
    local file = fs.open(workersStateFile, "w")
    if file then
        file.write(textutils.serialize(workers))
        file.close()
    end
end

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

function M.updateWorker(workerId, onSuccess, onTimeout)
    network.request(
        workerId,
        os.getComputerID(),
        { type = "COMMAND", command = "update" },
        onSuccess,
        onTimeout
    )
end

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

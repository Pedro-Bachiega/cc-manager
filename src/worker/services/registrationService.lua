local network = require("manager.src.common.network")
local protocol = require("manager.src.common.protocol")
local config = require("manager.src.common.config")
local workerMessaging = require("manager.src.common.workerMessaging")

--- @class RegistrationService
--- @brief Handles the registration process for a worker computer with a manager computer.
--- This service manages broadcasting registration requests, listening for manager responses,
--- and persisting the manager's ID.
local M = {}

--- @private
--- @brief How long to wait for a manager to respond to registration (in seconds).
local registrationTimeout = 5

--- Attempts to register the worker computer with a manager computer.
-- It first checks for a saved manager ID, then broadcasts registration requests until a manager responds.
--- @return number The ID of the registered manager computer.
function M.registerWithManager()
    local managerId = nil
    network.open(protocol.id)

    local savedConfig = config.load()
    if savedConfig.managerId then
        managerId = savedConfig.managerId
        print("Loaded manager ID from config: " .. managerId)
    end

    while not managerId do
        workerMessaging.setStatus("searching for manager")
        network.broadcast(protocol.serialize({ type = "REGISTER" }))

        local responseTimer = os.startTimer(registrationTimeout)
        local done = false
        while not done do
            local event, p1, p2, p3, p4, p5, p6 = os.pullEvent() -- Get all events
            if event == "modem_message" then
                local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
                local message = textutils.unserializeJSON(message_raw) -- Deserialize the message
                local senderId = replyChannel
                local msg = message -- message is already deserialized
                if msg and msg.type == "REGISTER_OK" then -- Removed protocol check
                    managerId = senderId
                    local current_config = config.load()
                    current_config.managerId = managerId
                    config.save(current_config) -- Save the manager ID
                    print("Registered with manager: " .. managerId)
                    done = true
                end
            elseif event == "timer" and p1 == responseTimer then
                done = true -- Timeout expired
            end
        end

        if not managerId then
            workerMessaging.setStatus("manager not found")
            sleep(10) -- Wait before retrying
        end
    end
    workerMessaging.setManagerId(managerId)
    return managerId
end

return M

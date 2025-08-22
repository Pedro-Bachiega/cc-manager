-- Defines the network protocol for communication between manager and workers.

local protocol = {}

-- The name of the rednet protocol to use.
-- All computers on the network must use the same protocol name.
protocol.id = 12345

--- Helper function to safely encode a Lua table into a JSON string.
function protocol.serialize(data)
    return textutils.serializeJSON(data)
end

--- Helper function to safely decode a JSON string into a Lua table.
function protocol.deserialize(text)
    local ok, data = pcall(textutils.unserializeJSON, text)
    if ok then
        return data
    end
    return nil
end

--[[--------------------------------------------------------------------------

                                MESSAGE TYPES

----------------------------------------------------------------------------]]

--[[*
 * Worker -> Manager
 * Sent by a worker when it first starts up to register itself.
 * 
 * { type = "REGISTER" }
]]

--[[*
 * Manager -> Worker
 * Sent by the manager to acknowledge a worker's registration.
 * 
 * { type = "REGISTER_OK", id = <manager_id> }
]]

--[[*
 * Worker -> Manager
 * Sent periodically by a worker to show it is still online.
 * 
 * { type = "HEARTBEAT", status = <current_status> }
]]

--[[*
 * Manager -> Worker
 * Sent by the manager to assign a new task.
 * 
 * { type = "TASK", name = <task_name>, params = { ... } }
]]

--[[*
 * Worker -> Manager
 * Sent by a worker when it has finished a task.
 * 
 * { type = "TASK_RESULT", success = <true/false>, result = <data> }
]]

return protocol
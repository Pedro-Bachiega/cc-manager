-- src/common/network.lua
local protocol = require("manager.src.common.protocol")

local network = {}
local modem = nil
local open_channels = {}
local pending_requests = {}
local nextRequestId = 1

local function getModem()
    if not modem then
        modem = peripheral.find("modem")
        if not modem then
            error("No wireless modem found.")
        end
    end
    return modem
end

function network.open(protocol_id)
    local m = getModem()
    if not open_channels[protocol_id] then
        m.open(protocol_id)
        open_channels[protocol_id] = true
    end
end

function network.close(protocol_id)
    local m = getModem()
    if open_channels[protocol_id] then
        m.close(protocol_id)
        open_channels[protocol_id] = nil
    end
end

-- This is a fire-and-forget send.
function network.send(channel, replyChannel, message)
    local m = getModem()
    m.transmit(channel, replyChannel, protocol.serialize(message))
end

function network.broadcast(message)
    network.send(protocol.id, os.getComputerID(), message)
end

--- Sends a request and waits for a response, with callbacks.
function network.request(channel, replyChannel, message, onSuccess, onTimeout, timeout)
    timeout = timeout or 5
    local requestId = nextRequestId
    nextRequestId = nextRequestId + 1

    message.requestId = requestId

    pending_requests[requestId] = {
        onSuccess = onSuccess,
        onTimeout = onTimeout,
        timeoutAt = os.time() + (timeout / 50) -- Must be divided by 50
    }

    network.send(channel, replyChannel, message)
end

--- Dispatches incoming messages. Should be called from the main message loop.
--- @return boolean Returns true if the message was a reply and was handled.
function network.dispatch(senderId, message)
    if message.isReply and message.replyTo then
        local requestId = message.replyTo
        local request = pending_requests[requestId]
        if request then
            if request.onSuccess then
                request.onSuccess(senderId, message.payload)
            end
            pending_requests[requestId] = nil
            return true
        end
    end
    return false
end

--- Checks for timed out requests. Should be called periodically.
function network.update()
    local now = os.time()
    for requestId, request in pairs(pending_requests) do
        if now >= request.timeoutAt then
            if request.onTimeout then
                request.onTimeout()
            end
            pending_requests[requestId] = nil
        end
    end
end

return network

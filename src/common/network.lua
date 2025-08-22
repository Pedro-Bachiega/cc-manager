-- src/common/network.lua
local network = {}
local modem = nil
local open_channels = {}

local function getModem()
    if not modem then
        modem = peripheral.find("modem")
        if not modem then
            error("No wireless modem found.")
        end
    end
    return modem
end

function network.open(protocol)
    local m = getModem()
    if not open_channels[protocol] then
        m.open(protocol)
        open_channels[protocol] = true
    end
end

function network.close(protocol)
    local m = getModem()
    if open_channels[protocol] then
        m.close(protocol)
        open_channels[protocol] = nil
    end
end

function network.send(channel, replyChannel, message)
    local m = getModem()
    m.transmit(channel, replyChannel, textutils.serializeJSON(message))
end

function network.receive()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if event == "modem_message" then
            return event, side, channel, replyChannel, message, distance
        end
    end
end

function network.broadcast(channel, message)
    local m = getModem()
    m.transmit(channel, nil, textutils.serializeJSON(message)) -- nil recipientId for broadcast
end

-- For receive, we will rely on os.pullEvent("modem_message")
-- The existing code uses rednet.receive, which is blocking.
-- We will need to adapt the calling code to use os.pullEvent.
-- This wrapper will not provide a direct blocking 'receive' function.

return network
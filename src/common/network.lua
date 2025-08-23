-- src/common/network.lua
local network = {}
local modem = nil
local open_channels = {}
local protocol = require("manager.src.common.protocol") -- Added this line

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
    m.transmit(channel, replyChannel, protocol.serialize(message))
end

function network.broadcast(message)
    network.send(protocol.id, os.getComputerID(), message)
end

return network
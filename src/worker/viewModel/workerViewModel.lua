local compose = require("compose.src.compose")
local workerMessaging = require("manager.src.common.workerMessaging")

local M = {}
M.__index = M

function M:new()
    local instance = setmetatable({}, M)
    instance.status = workerMessaging.getStatus()
    instance.managerId = workerMessaging.getManagerId()
    return instance
end

function M:getStatus()
    return self.status:get()
end

function M:getManagerId()
    return self.managerId
end

return M

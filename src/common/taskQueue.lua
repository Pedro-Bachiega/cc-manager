--!non-executable
local taskQueue = {}

local M = {}

function M.addTask(task)
    table.insert(taskQueue, task)
end

function M.runTaskWorker()
    while true do
        if #taskQueue > 0 then
            local task = table.remove(taskQueue, 1)
            local co = coroutine.create(task)
            local ok, err = coroutine.resume(co)
            if not ok then
                printError("Task error: " .. tostring(err))
            end
        end
        sleep(0.1) -- Prevent busy-waiting
    end
end

return M
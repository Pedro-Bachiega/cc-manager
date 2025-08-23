-- Local table to store coroutine states for scheduling
local scheduled_coroutines = {}

local M = {}

function M.delay(duration)
    local wakeTime = os.time() + (duration / 50)
    -- Store the coroutine and its wake time for the scheduler
    scheduled_coroutines[coroutine.running()] = { wakeTime = wakeTime }
    coroutine.yield() -- Yield control to the scheduler
end

function M.coroutineScheduler()
    while true do
        for co, data in pairs(scheduled_coroutines) do
            if data.wakeTime and os.time() >= data.wakeTime then
                scheduled_coroutines[co] = nil -- Remove from scheduled list
                local success, err = coroutine.resume(co)
                if not success then
                    print("Coroutine error:", err)
                end
            end
        end
        os.sleep(0.1)
    end
end

return M

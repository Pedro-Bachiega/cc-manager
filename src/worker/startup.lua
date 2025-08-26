-- Worker startup script

-- Load shared APIs using require
local compose = require("compose.src.compose")
local config = require("manager.src.common.config")
local workerMessaging = require("manager.src.common.workerMessaging")
local registrationService = require("manager.src.worker.services.registrationService")
local WorkerView = require("manager.src.worker.view.workerView")
local WorkerViewModel = require("manager.src.worker.viewModel.workerViewModel")

-- Start registration process
registrationService.registerWithManager()

-- Load the config module from the newly cloned manager directory
local cfg = config.load()

-- Load and execute persistent role on startup
if cfg.secondaryRole and cfg.secondaryRole.name then
    print("Loading persistent role: " .. cfg.secondaryRole.displayName)
    local roleScriptPath = "manager/src/worker/roles/" .. cfg.secondaryRole.name .. ".lua"
    if fs.exists(roleScriptPath) then
        -- The role script is now responsible for the main loop.
        -- It should call workerMessaging.start() itself.
        local requirePath = (roleScriptPath):gsub(".lua", ""):gsub("/", ".")
        local role_module = require(requirePath)
        if role_module and role_module.run then
            -- The run function should be a blocking call that takes over the worker
            role_module.run()
            -- If the script returns, it means it's done or failed.
            print("Role script finished.")
            -- We stop here, as the role script handled everything.
            return
        else
            print("Role script is invalid. Missing :run() function.")
        end
    else
        print("Role script not found: " .. roleScriptPath)
    end
end

-- Default behavior if no role is assigned or role script finishes
workerMessaging.setStatus("idle")

local viewModel = WorkerViewModel:new()

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(function() return WorkerView.WorkerStatusApp(viewModel) end, monitor)
end

local function messageListenerTask()
    workerMessaging.start()
end

local tasks = {messageListenerTask}

local monitor = peripheral.find("monitor")
if monitor then
    table.insert(tasks, composeAppTask)
end

parallel.waitForAll(unpack(tasks))

-- Manager startup script

local compose = require("compose.src.compose")
local protocol = require("manager.src.common.protocol")
local network = require("manager.src.common.network")

--[[--------------------------------------------------------------------------
                                CONFIGURATION
----------------------------------------------------------------------------]]

local assignedRolesFile = "assigned_roles.dat"
local workersStateFile = "workers_state.dat"

-- How often the screen updates and we check for disconnected workers (in seconds)
local tickRate = 5
-- How long to wait for a heartbeat before marking a worker as disconnected (in seconds)
local disconnectTimeout = 15

--[[--------------------------------------------------------------------------
                                  LOGIC
----------------------------------------------------------------------------]]

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
loadAssignedRoles()

local initialWorkers = {}
local file = fs.open(workersStateFile, "r")
if file then
    local content = file.readAll()
    file.close()
    initialWorkers = textutils.unserialize(content) or {}
end

local workers = compose.remember(initialWorkers, "workers", true)
local selectedWorkerId = compose.remember(nil, "selectedWorkerId")

local function handleRednetMessage(senderId, message)
    local msg = protocol.deserialize(message)
    if not msg or not msg.type then return end

    local currentWorkers = workers:get()

    if msg.type == "REGISTER" then
        currentWorkers[senderId] = { id = senderId, status = "online", last_heartbeat = os.time() }
        network.send(senderId, os.getComputerId(), protocol.serialize({ type = "REGISTER_OK" }))
        local assignedRole = assignedRoles[senderId]
        if assignedRole then
            network.send(senderId, os.getComputerId(),
                protocol.serialize({ type = "TASK", name = "assign_role", script = "worker/roles/" ..
                assignedRole .. ".lua", params = {} }))
        end
    elseif msg.type == "HEARTBEAT" then
        if currentWorkers[senderId] then
            currentWorkers[senderId].status = msg.status or "online"
            currentWorkers[senderId].last_heartbeat = os.time()
        end
    elseif msg.type == "TASK_RESULT" then
        if currentWorkers[senderId] then
            currentWorkers[senderId].status = "idle"
        end
    end

    workers:set(currentWorkers)
end

--[[--------------------------------------------------------------------------
                                  UI
----------------------------------------------------------------------------]]

local function WorkerDetails(worker, role)
    local actions = {}
    if role == "advanced_mob_farm_manager" or role == "mob_spawner_controller" then
        table.insert(actions, compose.Button({
            text = "Toggle State",
            onClick = function()
                network.send(worker.id, os.getComputerId(), { role = role, command = "toggle_state" })
            end
        }))
    end

    return compose.Column({}, {
        compose.Text({ text = "Worker " .. worker.id }),
        compose.Text({ text = "Role: " .. (role or "N/A") }),
        compose.Row({}, actions),
        compose.Button({ text = "Back", onClick = function() selectedWorkerId:set(nil) end })
    })
end

local function App()
    local selectedId = selectedWorkerId:get()
    if selectedId then
        local worker = workers:get()[selectedId]
        local role = assignedRoles[selectedId]
        return WorkerDetails(worker, role)
    else
        return compose.Column({
            modifier = compose.Modifier:new():fillMaxSize(),
            horizontalAlignment = compose.HorizontalAlignment.Center
        }, {
            compose.Text({ text = "--- Manager Control Panel ---" }),
            compose.Text({ text = "Listening on protocol: " .. protocol.id }),
            compose.Text({ text = "-----------------------------" }),
            workers:get(function(w)
                local rows = {}
                for id, data in pairs(w) do
                    local status = data.status
                    local statusColor = colors.white

                    if status == "online" then
                        status = "healthy"
                    end

                    if status == "healthy" then
                        statusColor = colors.green
                    elseif status == "timed out" then
                        statusColor = colors.red
                    elseif status == "idle" then
                        statusColor = colors.yellow
                    end

                    local roleInfo = assignedRoles[id] and (" (Role: " .. assignedRoles[id] .. ")") or ""
                    table.insert(rows, compose.Row({
                        modifier = compose.Modifier:new():clickable(function() selectedWorkerId:set(id) end)
                    }, {
                        compose.Text({ text = string.format("Worker %d: ", id) }),
                        compose.Text({ text = status, textColor = statusColor }),
                        compose.Text({ text = roleInfo })
                    }))
                end
                if #rows == 0 then
                    return compose.Text({ text = "No workers connected." })
                end
                return compose.Column({}, rows)
            end)
        })
    end
end

--[[--------------------------------------------------------------------------
                                  MAIN LOOP
----------------------------------------------------------------------------]]

local function composeAppTask()
    local monitor = peripheral.find("monitor") or error("No monitor found", 0)
    compose.render(App, monitor)
end

local function messageListenerTask()
    network.open(protocol.id) -- Open the protocol using our wrapper

    while true do
        local event, p1, p2, p3, p4, p5, p6 = os.pullEvent() -- Get all events
        if event == "modem_message" then
            local side, channel, replyChannel, message_raw, distance = p1, p2, p3, p4, p5 -- Map to user's desired names
            local message = textutils.unserializeJSON(message_raw) -- Deserialize the message
            -- No protocol check needed here
            handleRednetMessage(replyChannel, message)
        end
    end
end

local function inputTask()
    while true do
        local command = read()
        local parts = {}
        for part in command:gmatch("%S+") do table.insert(parts, part) end

        if parts[1] == "assign_role" and #parts == 3 then
            local targetId, roleName = tonumber(parts[2]), parts[3]
            if targetId and workers:get()[targetId] then
                assignedRoles[targetId] = roleName
                saveAssignedRoles()
                network.send(targetId, os.getComputerId(),
                    protocol.serialize({ type = "TASK", name = "assign_role", script = "worker/roles/" ..
                    roleName .. ".lua", params = {} }))
            end
        end
    end
end

local function saveStateTask()
    while true do
        sleep(10) -- Save every 10 seconds
        local file = fs.open(workersStateFile, "w")
        if file then
            file.write(textutils.serialize(workers:get()))
            file.close()
        end
    end
end

local function workerStatusUpdateTask()
    while true do
        sleep(tickRate)
        local currentWorkers = workers:get()
        local updated = false
        for id, data in pairs(currentWorkers) do
            if data.status == "online" and os.time() - data.last_heartbeat > disconnectTimeout then
                currentWorkers[id].status = "disconnected"
                updated = true
            end
        end
        if updated then
            workers:set(currentWorkers)
        end
    end
end

parallel.waitForAll(composeAppTask, messageListenerTask, inputTask, saveStateTask, workerStatusUpdateTask)
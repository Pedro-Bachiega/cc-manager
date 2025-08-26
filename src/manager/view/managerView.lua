local compose = require("compose.src.compose")
local protocol = require("manager.src.common.protocol")

local M = {}

local availableRoles = {
    {
        name = "advanced_mob_farm_manager",
        displayName = "Advanced Mob Farm Manager"
    },
    {
        name = "mob_spawner_controller",
        displayName = "Mob Spawner Controller"
    },
    {
        name = "power_grid_monitor",
        displayName = "Power Grid Monitor"
    }
}

local function map(tbl, func)
    local newTbl = {}
    for k, v in pairs(tbl) do
        newTbl[k] = func(v)
    end
    return newTbl
end

local function WorkerDetails(viewModel)
    local worker = viewModel.workers:get()[viewModel.selectedWorkerId:get()]
    local role = viewModel.assignedRoles:get()[viewModel.selectedWorkerId:get()]

    local actions = {}

    table.insert(actions, compose.Button({
        text = "Update Worker",
        onClick = function() viewModel:updateSelectedWorker() end
    }))

    local footer = nil

    if role then -- Only show clear role if a role is assigned
        table.insert(actions, compose.Button({
            text = "Clear Role",
            onClick = function() viewModel:clearRoleForSelectedWorker() end
        }))

        if role.name == "advanced_mob_farm_manager" or role.name == "mob_spawner_controller" then
            table.insert(actions, compose.Button({
                text = "Toggle State",
                onClick = function() viewModel:toggleStateForSelectedWorker() end
            }))
        end

        footer = compose.Column({
            modifier = compose.Modifier:new():fillMaxWidth(),
            verticalArrangement = compose.Arrangement.SpacedBy,
            spacing = 1
        }, actions)
    else
        -- Conditional role assignment UI
        footer = compose.Column({}, {
            compose.Text({ text = "Assign Role:" }),
            compose.Column({
                verticalArrangement = compose.Arrangement.SpacedBy,
                spacing = 1
            }, map(availableRoles, function(roleOption)
                return compose.Column({}, {
                    compose.Button({
                        text = roleOption.displayName,
                        onClick = function() viewModel:assignRole(roleOption) end
                    })
                })
            end))
        })
    end

    return compose.Column({ modifier = compose.Modifier:new():fillMaxSize() }, {
        compose.Button({
            text = "Back",
            backgroundColor = colors.red,
            textColor = colors.white,
            onClick = function() viewModel:clearSelection() end
        }),
        compose.Spacer({ modifier = compose.Modifier:new():height(1) }),
        compose.Text({ text = "Worker " .. worker.id }),
        compose.Text({ text = "Role: " .. (role and role.displayName or "N/A") }),
        compose.Spacer({ modifier = compose.Modifier:new():height(1) }),
        footer
    })
end

local function MainScreen(viewModel)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center
    }, {
        compose.Text({ text = "--- Manager Control Panel ---" }),
        compose.Text({ text = "Listening on protocol: " .. protocol.id }),
        compose.Text({ text = "-----------------------------" }),
        viewModel.workers:get(function(w)
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

                local roleInfo = viewModel.assignedRoles:get()[id] and
                    ("Role: " .. viewModel.assignedRoles:get()[id].displayName) or ""
                table.insert(rows, compose.Column({
                    modifier = compose.Modifier:new():clickable(function() viewModel:selectWorker(id) end)
                }, {
                    compose.Row({}, {
                        compose.Text({ text = string.format("Worker %d: ", id) }),
                        compose.Text({ text = status, textColor = statusColor })
                    }),
                    compose.Text({ text = roleInfo })
                }))
            end

            if #rows == 0 then
                table.insert(rows, compose.Text({ text = "No workers connected." }))
            end

            return compose.Column({ modifier = compose.Modifier:new():weight(1) }, rows)
        end),
        compose.Button({
            text = "Update Manager",
            onClick = function()
                viewModel.loadingText:set("Updating manager...")
                shell.run("manager/update.lua")
            end
        })
    })
end

function M.App(viewModel)
    if viewModel.loadingText:get() then
        return compose.Column({
            modifier = compose.Modifier:new():fillMaxSize(),
            verticalArrangement = compose.Arrangement.SpaceAround,
            horizontalAlignment = compose.HorizontalAlignment.Center
        }, {
            compose.ProgressBar({ text = viewModel.loadingText:get() })
        })
    end

    local selectedId = viewModel.selectedWorkerId:get()
    if selectedId then
        return WorkerDetails(viewModel)
    else
        return MainScreen(viewModel)
    end
end

return M

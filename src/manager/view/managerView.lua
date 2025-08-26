local compose = require("compose.src.compose")
local protocol = require("manager.src.common.protocol")

local M = {}

local availableRoles = {
    {
        name = "advanced_mob_farm_manager",
        displayName = "Advanced Mob Farm Manager",
        abbreviation = "AMFM"
    },
    {
        name = "mob_spawner_controller",
        displayName = "Mob Spawner Controller",
        abbreviation = "MSC"
    },
    {
        name = "power_grid_monitor",
        displayName = "Power Grid Monitor",
        abbreviation = "PGM"
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

    if role then
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

-- New MainScreen function (now primarily for the main content of the drawer)
local function MainContent(viewModel, drawerOpen) -- Renamed from MainScreen to MainContent
    local selectedId = viewModel.selectedWorkerId:get()
    if selectedId then
        return WorkerDetails(viewModel)
    else
        return compose.Column({
            modifier = compose.Modifier:new():fillMaxSize(),
            horizontalAlignment = compose.HorizontalAlignment.Center,
            verticalArrangement = compose.Arrangement.Center
        }, {
            compose.Text({ text = "--- Manager Control Panel ---" }),
            compose.Text({ text = "Listening on protocol: " .. protocol.id }),
            compose.Text({ text = "-----------------------------" }),
            compose.Spacer({ modifier = compose.Modifier:new():height(2) }),
            compose.Text({ text = "Select a worker from the drawer" }),
            compose.Spacer({ modifier = compose.Modifier:new():weight(1) }),
            compose.Row({ modifier = compose.Modifier:new():fillMaxWidth() }, {
                compose.Button({
                    text = "Open Drawer",
                    onClick = function() drawerOpen:set(true) end
                }),
                compose.Spacer({ modifier = compose.Modifier:new():height(2) }),
                compose.Button({
                    text = "Update Manager",
                    onClick = function()
                        viewModel.loadingText:set("Updating manager...")
                        shell.run("manager/update.lua")
                    end
                })
            })
        })
    end
end

--- New DrawerContent function
--- @param viewModel ManagerViewModel
--- @param drawerOpen State<boolean>
local function DrawerContent(viewModel, drawerOpen)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize():background(colors.lightGray),
        horizontalAlignment = compose.HorizontalAlignment.Start
    }, {
        compose.Text({ text = "--- Workers ---", textColor = colors.black }),
        compose.Spacer({ modifier = compose.Modifier:new():height(1) }),
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

                local role = viewModel.assignedRoles:get()[id]
                local roleInfo = role and ("Role: " .. (role.abbreviation or "N/A")) or nil
                table.insert(rows, compose.Column({
                    backgroundColor = statusColor,
                    modifier = compose.Modifier:new():clickable(function()
                        viewModel:selectWorker(id)
                        drawerOpen:set(false)         -- Close drawer on worker selection
                    end):fillMaxWidth():padding(1, 0) -- Add padding for better look
                }, (function()
                    local items = {
                        compose.Text({ text = string.format("Worker %d", id), textColor = colors.black })
                    }
                    if roleInfo then
                        table.insert(items, compose.Text({ text = roleInfo, textColor = colors.black }))
                    end

                    return items
                end)()))
            end

            if #rows == 0 then
                table.insert(rows, compose.Text({ text = "No workers connected.", textColor = colors.black }))
            end

            return compose.Column({ modifier = compose.Modifier:new():weight(1) }, rows)
        end),
        compose.Spacer({ modifier = compose.Modifier:new():height(1) }),
        compose.Button({
            text = "Close Drawer",
            onClick = function() drawerOpen:set(false) end,
            modifier = compose.Modifier:new():fillMaxWidth():background(colors.red)
        })
    })
end

--- New App function
--- @param viewModel ManagerViewModel
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

    local drawerOpen = compose.remember(true, "manager_drawer_open") -- State for drawer

    return compose.NavigationDrawer({
        drawerContent = DrawerContent(viewModel, drawerOpen),
        content = MainContent(viewModel, drawerOpen),
        isOpen = drawerOpen,
        onClose = function() drawerOpen:set(false) end
    })
end

return M

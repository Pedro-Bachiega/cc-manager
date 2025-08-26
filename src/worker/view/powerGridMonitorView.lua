local compose = require("compose.src.compose")

local M = {}

local function MainView(viewModel)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center
    }, {
        compose.Text({ text = "--- Power Grid Monitor ---" }),
        compose.Row({}, {
            compose.Text({ text = "Power Level: " }),
            viewModel.powerLevel:get(function(level)
                return compose.Text({ text = string.format("%.2f%%", level * 100) })
            end)
        }),
        compose.Text({ text = "Controlled Machines:"}),
        viewModel.controlledMachines:get(function(machines)
            local rows = {}
            for side, data in pairs(machines) do
                table.insert(rows, compose.Row({}, {
                    compose.Text({ text = data.machine_name .. " (" .. side .. "): " }),
                    compose.Text({ text = data.enabled and "ON" or "OFF" }),
                    compose.Button({ text = "Toggle", onClick = function() viewModel:setMachineState(side, not data.enabled) end })
                }))
            end
            return compose.Column({}, rows)
        end)
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

    return MainView(viewModel)
end

return M

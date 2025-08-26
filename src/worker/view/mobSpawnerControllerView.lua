local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")

local M = {}

local function MainView(viewModel)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = "--- Mob Spawner Controller ---" }),
        compose.Row({}, {
            compose.Text({ text = "Spawner Status: " }),
            viewModel.spawnerEnabled:get(function(enabled)
                local statusText = enabled and "ON" or "OFF"
                local statusColor = enabled and colors.green or colors.red
                return compose.Text({ text = statusText, textColor = statusColor })
            end)
        }),
        compose.Button({
            text = "Toggle Spawner",
            onClick = function() viewModel:toggleSpawner() end
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

    if viewModel.redstoneSide:get() == nil then
        return ui.SideSelector(function(side) viewModel.redstoneSide:set(side) end)
    else
        return MainView(viewModel)
    end
end

return M

local compose = require("compose.src.compose")
local ui = require("manager.src.common.ui")

local M = {}

local function MainView(viewModel)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center
    }, {
        compose.Text({ text = "--- Advanced Mob Farm Manager ---" }),
        compose.Row({}, {
            compose.Text({ text = "Farm Status: " }),
            viewModel.farmEnabled:get(function(enabled)
                local statusText = enabled and "ON" or "OFF"
                local statusColor = enabled and colors.green or colors.red
                return compose.Text({ text = statusText, textColor = statusColor })
            end)
        }),
        compose.Button({
            text = "Toggle Farm",
            onClick = function() viewModel:toggleFarm() end
        }),
        compose.Column({
            modifier = compose.Modifier:new():fillMaxSize()
        }, {
            compose.Text({ text = "Item Count" }),
            -- Table data
            viewModel.itemCounts:get(function(currentItems)
                local rows = {}
                for name, count in pairs(currentItems) do
                    table.insert(rows, compose.Row({}, {
                        compose.Text({ text = name }),
                        compose.Text({ text = tostring(count) })
                    }))
                end
                return compose.Column({}, rows)
            end)
        }),
        viewModel.chosenContainer:get(function(container)
            local text = container and ("Selected Container: " .. container) or "No Container Selected"
            local textColor = container and colors.white or colors.red
            return compose.Text({ text = text, textColor = textColor })
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

    if viewModel.redstoneSide:get() == nil then
        return ui.SideSelector(function(side) viewModel.redstoneSide:set(side) end)
    else
        return MainView(viewModel)
    end
end

return M

local compose = require("compose.src.compose")

local M = {}

function M.WorkerStatusApp(viewModel)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = "--- Worker Computer ---" }),
        compose.Text({ text = "ID: " .. os.getComputerID() }),
        compose.Text({ text = "Manager: " .. (viewModel:getManagerId() or "N/A") }),
        compose.Text({ text = "Status: " .. viewModel:getStatus() })
    })
end

return M

local compose = require("compose.src.compose")

local M = {}

function M.SideSelector(onSideSelected)
    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = "Select Redstone Output Side" }),
        compose.Row({ verticalAlignment = compose.VerticalAlignment.Center }, {
            compose.Button({ text = "Left", onClick = function() onSideSelected("left") end }),
            compose.Column({}, {
                compose.Button({ text = "Front", onClick = function() onSideSelected("front") end }),
                compose.Text({ text = "[PC]" }),
                compose.Button({ text = "Back", onClick = function() onSideSelected("back") end })
            }),
            compose.Button({ text = "Right", onClick = function() onSideSelected("right") end })
        })
    })
end

function M.StateSelector(title, options, onStateSelected)
    local buttons = {}
    for _, option in ipairs(options) do
        table.insert(buttons, compose.Button({ text = option, onClick = function() onStateSelected(option) end }))
    end

    return compose.Column({
        modifier = compose.Modifier:new():fillMaxSize(),
        horizontalAlignment = compose.HorizontalAlignment.Center,
        verticalArrangement = compose.Arrangement.Center
    }, {
        compose.Text({ text = title }),
        compose.Row({}, buttons)
    })
end

return M

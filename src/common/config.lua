-- Handles reading and writing configuration from a JSON file.

local config = {}
local configFilePath = "config.json"

--- Loads configuration from the config.json file.
-- @return table The loaded configuration, or an empty table if the file doesn't exist or is invalid.
function config.load()
    if fs.exists(configFilePath) then
        local file = fs.open(configFilePath, "r")
        if file then
            local content = file.readAll()
            file.close()
            local success, data = pcall(textutils.unserializeJSON, content)
            if success and type(data) == "table" then
                return data
            else
                print("Warning: Could not parse config.json. Starting with empty config.")
            end
        end
    end
    return {}
end

--- Saves configuration to the config.json file.
-- @param data table The table to save as configuration.
function config.save(data)
    local content = textutils.serializeJSON(data)
    local file = fs.open(configFilePath, "w")
    if file then
        file.write(content)
        file.close()
    else
        error("Could not open config.json for writing.")
    end
end

return config

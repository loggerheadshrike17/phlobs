obs = obslua

------------------------------------------------------------
-- User Settings
------------------------------------------------------------
red_raw_file = ""
blue_raw_file = ""
red_clean_file = ""
blue_clean_file = ""

update_interval = 1.0  -- seconds

last_red_value = ""
last_blue_value = ""

------------------------------------------------------------
-- Utility: Read from file
------------------------------------------------------------
function read_file(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil
end

------------------------------------------------------------
-- Utility: Write to file
------------------------------------------------------------
function write_file(path, content)
    local file = io.open(path, "w")
    if file then
        file:write(content)
        file:close()
    end
end

------------------------------------------------------------
-- Utility: Convert seconds to MM:SS
------------------------------------------------------------
function seconds_to_mmss(seconds)
    local total_seconds = math.floor(tonumber(seconds) or 0)
    local minutes = math.floor(total_seconds / 60)
    local secs = total_seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

------------------------------------------------------------
-- Update Loop
------------------------------------------------------------
function update_possession()
    -- Read raw files
    local red_raw = read_file(red_raw_file)
    local blue_raw = read_file(blue_raw_file)

    -- Format Red
    if red_raw and red_raw ~= last_red_value then
        local formatted_red = seconds_to_mmss(red_raw)
        write_file(red_clean_file, formatted_red)
        last_red_value = red_raw
    end

    -- Format Blue
    if blue_raw and blue_raw ~= last_blue_value then
        local formatted_blue = seconds_to_mmss(blue_raw)
        write_file(blue_clean_file, formatted_blue)
        last_blue_value = blue_raw
    end
end

------------------------------------------------------------
-- OBS Script Tick
------------------------------------------------------------
local accumulator = 0
function script_tick(seconds)
    accumulator = accumulator + seconds
    if accumulator >= update_interval then
        update_possession()
        accumulator = 0
    end
end

------------------------------------------------------------
-- OBS Script Properties
------------------------------------------------------------
function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_path(props, "red_raw_file", "Red Raw File",
        obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_path(props, "blue_raw_file", "Blue Raw File",
        obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_path(props, "red_clean_file", "Red Clean Output File",
        obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_path(props, "blue_clean_file", "Blue Clean Output File",
        obs.OBS_PATH_FILE, "*.txt", nil)

    return props
end

------------------------------------------------------------
-- OBS Script Update
------------------------------------------------------------
function script_update(settings)
    red_raw_file = obs.obs_data_get_string(settings, "red_raw_file")
    blue_raw_file = obs.obs_data_get_string(settings, "blue_raw_file")
    red_clean_file = obs.obs_data_get_string(settings, "red_clean_file")
    blue_clean_file = obs.obs_data_get_string(settings, "blue_clean_file")
end

------------------------------------------------------------
-- Script Description
------------------------------------------------------------
function script_description()
    return "Reads Red and Blue raw possession files in seconds, converts to MM:SS format, and writes to clean output files."
end

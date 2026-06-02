obs = obslua

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------
txt_file_path = ""            -- Path to the input TXT file
update_interval = 250         -- ms
blue_source_name = "BLUE SHOTS"
red_source_name = "RED SHOTS"

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------
-- Trim whitespace and newlines
function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

-- Read two lines from a text file
function read_two_lines(path)
    local f = io.open(path, "r")
    if not f then
        print("[Blue/Red Shots] Cannot open file:", path)
        return nil, nil
    end

    local line1 = f:read("*l")
    local line2 = f:read("*l")
    f:close()

    return line1, line2
end

-- Force update an OBS Text source
function force_update_text_source(source_name, value)
    if not value then return end
    value = trim(value)
    local source = obs.obs_get_source_by_name(source_name)
    if source then
        local settings = obs.obs_source_get_settings(source)
        obs.obs_data_set_string(settings, "text", tostring(value))
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
        print("[Blue/Red Shots] Updated source:", source_name, "to", value)
    else
        print("[Blue/Red Shots] Source not found:", source_name)
    end
end

------------------------------------------------------------
-- MAIN UPDATE LOOP
------------------------------------------------------------
function update_shots()
    if txt_file_path == "" then return end

    local blue_val, red_val = read_two_lines(txt_file_path)
    if not blue_val and not red_val then return end

    force_update_text_source(blue_source_name, blue_val)
    force_update_text_source(red_source_name, red_val)
end

------------------------------------------------------------
-- OBS SCRIPT INTERFACE
------------------------------------------------------------
function script_description()
    return [[
Reads a text file with 2 lines:
Line 1 → Blue shots
Line 2 → Red shots
Always updates the OBS text sources "BLUE SHOTS" and "RED SHOTS".
]]
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_path(props, "txt_file_path", "Input TXT File", obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_text(props, "blue_source_name", "Blue Shots Source Name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "red_source_name", "Red Shots Source Name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "update_interval", "Update Interval (ms)", 100, 5000, 100)
    return props
end

function script_update(settings)
    txt_file_path = obs.obs_data_get_string(settings, "txt_file_path")
    blue_source_name = obs.obs_data_get_string(settings, "blue_source_name")
    red_source_name = obs.obs_data_get_string(settings, "red_source_name")
    update_interval = obs.obs_data_get_int(settings, "update_interval")

    obs.timer_remove(update_shots)
    obs.timer_add(update_shots, update_interval)

    -- Run immediately
    update_shots()
end

function script_unload()
    obs.timer_remove(update_shots)
end

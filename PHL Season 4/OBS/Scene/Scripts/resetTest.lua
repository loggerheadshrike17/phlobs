obs = obslua

------------------------------------------------------------
-- User Settings
------------------------------------------------------------
red_file_path = ""
blue_file_path = ""
text_source_name = "ShotCounterText"

------------------------------------------------------------
-- Shot Values
------------------------------------------------------------
red_shots = 0
blue_shots = 0

------------------------------------------------------------
-- Per-Team Lock State
------------------------------------------------------------
red_locked = false
blue_locked = false

last_red_value = 0
last_blue_value = 0

hotkey_id = obs.OBS_INVALID_HOTKEY_ID

------------------------------------------------------------
-- Utility: Read number from file
------------------------------------------------------------
function read_shots_from_file(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local num = tonumber(content)
        if num ~= nil then
            return num
        end
    end
    return 0
end

------------------------------------------------------------
-- Utility: Write number to file
------------------------------------------------------------
function write_shots_to_file(path, value)
    local file = io.open(path, "w")
    if file then
        file:write(tostring(value))
        file:close()
    end
end

------------------------------------------------------------
-- Update OBS Text Source
------------------------------------------------------------
function update_text_source()
    local source = obs.obs_get_source_by_name(text_source_name)
    if source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text",
            "Blue: " .. tostring(blue_shots) ..
            " | Red: " .. tostring(red_shots))
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

------------------------------------------------------------
-- Hard Reset Hotkey
------------------------------------------------------------
function hard_reset_pressed(pressed)
    if not pressed then return end

    -- Force both files to 0
    write_shots_to_file(red_file_path, 0)
    write_shots_to_file(blue_file_path, 0)

    -- Lock both teams
    red_locked = true
    blue_locked = true

    -- Reset OBS counters
    red_shots = 0
    blue_shots = 0

    -- Reset last values
    last_red_value = 0
    last_blue_value = 0

    update_text_source()
    print("[ShotCounter] HARD RESET - Both teams locked at 0")
end

------------------------------------------------------------
-- Main Tick Loop
------------------------------------------------------------
function script_tick(seconds)

    if red_file_path == "" or blue_file_path == "" then
        return
    end

    local file_red = read_shots_from_file(red_file_path)
    local file_blue = read_shots_from_file(blue_file_path)

    --------------------------------------------------------
    -- BLUE TEAM LOGIC
    --------------------------------------------------------
    if blue_locked then
        -- Only unlock when blue file changes
        if file_blue ~= last_blue_value then
            blue_locked = false
            blue_shots = file_blue
            print("[ShotCounter] Blue team unlocked")
        else
            -- Keep it at 0 while locked
            blue_shots = 0
        end
    else
        blue_shots = file_blue
    end

    --------------------------------------------------------
    -- RED TEAM LOGIC
    --------------------------------------------------------
    if red_locked then
        -- Only unlock when red file changes
        if file_red ~= last_red_value then
            red_locked = false
            red_shots = file_red
            print("[ShotCounter] Red team unlocked")
        else
            red_shots = 0
        end
    else
        red_shots = file_red
    end

    -- Save last file values for change detection
    last_red_value = file_red
    last_blue_value = file_blue

    update_text_source()
end

------------------------------------------------------------
-- OBS Script Properties
------------------------------------------------------------
function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_path(props, "red_file", "Red Team File",
        obs.OBS_PATH_FILE, "*.txt", nil)

    obs.obs_properties_add_path(props, "blue_file", "Blue Team File",
        obs.OBS_PATH_FILE, "*.txt", nil)

    obs.obs_properties_add_text(props, "text_source",
        "Text Source Name", obs.OBS_TEXT_DEFAULT)

    return props
end

------------------------------------------------------------
-- Update Settings
------------------------------------------------------------
function script_update(settings)
    red_file_path = obs.obs_data_get_string(settings, "red_file")
    blue_file_path = obs.obs_data_get_string(settings, "blue_file")
    text_source_name = obs.obs_data_get_string(settings, "text_source")
end

------------------------------------------------------------
-- Register Hotkey
------------------------------------------------------------
function script_load(settings)
    hotkey_id = obs.obs_hotkey_register_frontend(
        "hard_reset_shots",
        "Hard Reset Shots",
        hard_reset_pressed
    )

    local hotkey_save_array = obs.obs_data_get_array(settings, "hard_reset_shots")
    obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

function script_save(settings)
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
    obs.obs_data_set_array(settings, "hard_reset_shots", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

obs = obslua

------------------------------------------------------------
-- 🧠 CONFIGURATION
------------------------------------------------------------
input_file_path = "C:\\path\\to\\period.txt"         -- file from Puck mod
output_file_path = "C:\\path\\to\\period_clean.txt"  -- file OBS will read
check_interval_ms = 200                              -- how often to check (in milliseconds)

last_content = "" -- stores the last known file content

------------------------------------------------------------
-- 🧩 transform function
------------------------------------------------------------
function transform_period(text)
    if not text or text == "" then return "" end

    -- Trim whitespace/newlines
    text = text:gsub("^%s*(.-)%s*$", "%1")

    -- Create lowercase version for case-insensitive matching
    local lower = string.lower(text)

    -- Handle warmup
    if lower == "warmup" then
        return ""
    end

    -- Handle standard periods
    if lower == "period 1" then
        return "1st"
    elseif lower == "period 2" then
        return "2nd"
    elseif lower == "period 3" then
        return "3rd"
    end

    -- Handle overtime
    local ot_number = string.match(lower, "overtime%s+(%d+)")
    if ot_number then
        if ot_number == "1" then
            return "OT"
        else
            return ot_number .. "OT"
        end
    end

    -- fallback for unexpected text
    return text
end

------------------------------------------------------------
-- 🧩 watcher
------------------------------------------------------------
function check_for_updates()
    local file = io.open(input_file_path, "r")
    if not file then return end

    local content = file:read("*all")
    file:close()

    if not content then return end
    content = content:gsub("[\r\n]+", "") -- remove newlines

    if content ~= last_content then
        last_content = content
        local transformed = transform_period(content)

        local out = io.open(output_file_path, "w")
        if out then
            out:write(transformed)
            out:close()
        end

        print(string.format("[Puck Period Cleaner] %s → %s", content, transformed))
    end
end

------------------------------------------------------------
-- 🧩 OBS integration
------------------------------------------------------------
function script_description()
    return [[
Automatically reformats Puck period names for stream display.

Examples:
 - "Period 1" → "1st"
 - "Period 2" → "2nd"
 - "Period 3" → "3rd"
 - "Overtime 1" → "OT"
 - "Overtime 2" → "2OT"
 - "Warmup" → (blank)

OBS should display output_file_path in a Text (GDI+) source.
    ]]
end

function script_load(settings)
    obs.timer_add(check_for_updates, check_interval_ms)
    print("[Puck Period Cleaner] Started watching for updates.")
end

function script_unload()
    obs.timer_remove(check_for_updates)
    print("[Puck Period Cleaner] Stopped.")
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_path(props, "input_file_path", "Input File", obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_path(props, "output_file_path", "Output File", obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_int(props, "check_interval_ms", "Check Interval (ms)", 100, 2000, 100)
    return props
end

function script_update(settings)
    input_file_path = obs.obs_data_get_string(settings, "input_file_path")
    output_file_path = obs.obs_data_get_string(settings, "output_file_path")
    check_interval_ms = obs.obs_data_get_int(settings, "check_interval_ms")
end

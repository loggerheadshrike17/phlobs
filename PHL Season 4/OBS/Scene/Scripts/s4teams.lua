obs = obslua

-- ===============================
-- USER SETTINGS
-- ===============================
txt_file_path = ""  -- path selected in script properties

-- Animation source names
home_anim_source = "HomeGoalAnimation"
away_anim_source = "AwayGoalAnimation"

-- Scene names
home_logo_scene  = "HOME TEAM LOGO"
away_logo_scene  = "AWAY TEAM LOGO"
home_score_scene = "HOME TEAM Scorebug"
away_score_scene = "AWAY TEAM Scorebug"

-- Hotkey ID
hotkey_id = obs.OBS_INVALID_HOTKEY_ID

-- Timer interval (ms)
update_interval = 500

-- Last file contents
last_file_contents = ""

-- Team tricodes (existing + new)
team_codes = {
    "HOO","VIC","OTT","SEA","ALB","RMR", "USA", "CAN",  -- old codes
    -- Contender Division
    "KLW","NEN","SWS","SCC","BTA","GPA","KCP","ISL","NEV","NOV",
    -- Prospect Division
    "FER","WPG","APB","STA","NOC","HQM","MAC","ROT","WCK","HOB","PHI","RAV"
}

-- ===============================
-- Trim whitespace helper
-- ===============================
function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- ===============================
-- Read two lines from txt file: away first, home second
-- Ignores empty lines and trims spaces
-- ===============================
function read_tricodes(file_path)
    local away = nil
    local home = nil

    local f = io.open(file_path, "r")
    if f == nil then
        return nil, nil
    end

    repeat
        away = f:read("*line")
        if away then away = trim(away) end
    until away == nil or away ~= ""

    repeat
        home = f:read("*line")
        if home then home = trim(home) end
    until home == nil or home ~= ""

    f:close()

    if away ~= nil then away = away:sub(1,3) end
    if home ~= nil then home = home:sub(1,3) end

    return away, home
end

-- ===============================
-- Animation filter functions (unchanged)
-- ===============================
function show_filters_safe(source_name, tricode)
    local src = obs.obs_get_source_by_name(source_name)
    if src == nil then return end

    local filters = obs.obs_source_enum_filters(src)
    for _, f in ipairs(filters) do
        if f ~= nil then
            local fname = obs.obs_source_get_name(f)
            obs.obs_source_set_enabled(f, fname:sub(1,3) == tricode)
        end
    end

    obs.source_list_release(filters)
    obs.obs_source_release(src)
end

-- ===============================
-- Toggle visibility of all scene items in a scene
-- Only the source matching the tricode is visible; rest hidden
-- ===============================
function enforce_scene_visibility(scene_name, tricode)
    local scene_src = obs.obs_get_source_by_name(scene_name)
    if scene_src == nil then return end

    local scene = obs.obs_scene_from_source(scene_src)
    if scene == nil then
        obs.obs_source_release(scene_src)
        return
    end

    local items = obs.obs_scene_enum_items(scene)
    for _, item in ipairs(items) do
        local src = obs.obs_sceneitem_get_source(item)
        local src_name = obs.obs_source_get_name(src)
        if src_name ~= nil and #src_name >= 3 then
            local visible = (src_name:sub(1,3) == tricode)
            obs.obs_sceneitem_set_visible(item, visible)
        end
    end

    obs.sceneitem_list_release(items)
    obs.obs_source_release(scene_src)
end

-- ===============================
-- Update everything from txt
-- ===============================
function update_from_txt()
    if txt_file_path == "" then return end

    local f = io.open(txt_file_path, "r")
    if f == nil then return end

    local contents = f:read("*a")
    f:close()

    if contents == last_file_contents then
        return  -- file hasn't changed
    end
    last_file_contents = contents

    local away_tricode, home_tricode = read_tricodes(txt_file_path)
    if away_tricode == nil or home_tricode == nil then
        return
    end

    -- Logos
    enforce_scene_visibility(home_logo_scene, home_tricode)
    enforce_scene_visibility(away_logo_scene, away_tricode)

    -- Scorebugs
    enforce_scene_visibility(home_score_scene, home_tricode)
    enforce_scene_visibility(away_score_scene, away_tricode)

    -- Animation filters
    show_filters_safe(home_anim_source, home_tricode)
    show_filters_safe(away_anim_source, away_tricode)

    print("Auto-updated for Away: "..away_tricode.." | Home: "..home_tricode)
end

-- ===============================
-- Timer callback
-- ===============================
function timer_callback()
    update_from_txt()
end

-- ===============================
-- HOTKEY CALLBACK (optional)
-- ===============================
function on_hotkey_pressed(pressed)
    if not pressed then return end
    update_from_txt()
end

-- ===============================
-- OBS SCRIPT HOOKS
-- ===============================
function script_description()
    return [[
Automatically updates logo/scorebug sources and goal animation filters based on a .txt file:

- Away tricode on first non-empty line, home tricode on first non-empty line after that.
- Only the source matching the tricode is visible; all others hidden (eyeball toggle).
- Animation filter code unchanged (works exactly as before).
- Fully safe: no crashes, no deleted sources.
- Auto-refresh every 0.5s. Hotkey also supported.
- Supports team codes: HOO, VIC, OTT, SEA, ALB, RMR
  and new tricodes: KLW, NEN, SWS, SCC, BTA, GPA, KCP, ISL, NEV, NOV,
  FER, WPG, APB, STA, NOC, HQM, MAC, ROT, WCK, HOB, PHI, RAV
]]
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_path(props, "txt_file_path", "Tricode Input File", obs.OBS_PATH_FILE, "Text Files (*.txt)", nil)
    return props
end

function script_update(settings)
    txt_file_path = obs.obs_data_get_string(settings, "txt_file_path")
    last_file_contents = ""
end

function script_load(settings)
    obs.timer_add(timer_callback, update_interval)
    hotkey_id = obs.obs_hotkey_register_frontend("refresh_tricodes", "Refresh Tricode Sources", on_hotkey_pressed)
    local hotkey_array = obs.obs_data_get_array(settings, "refresh_tricodes_hotkey")
    obs.obs_hotkey_load(hotkey_id, hotkey_array)
    obs.obs_data_array_release(hotkey_array)
end

function script_save(settings)
    local hotkey_array = obs.obs_hotkey_save(hotkey_id)
    obs.obs_data_set_array(settings, "refresh_tricodes_hotkey", hotkey_array)
    obs.obs_data_array_release(hotkey_array)
end

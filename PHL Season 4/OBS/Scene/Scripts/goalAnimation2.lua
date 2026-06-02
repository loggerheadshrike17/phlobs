-- Goal animation script for OBS (Scorebug version)
-- Watches two score files: Red & Blue.
-- Triggers only when score increments by exactly +1.
-- When a score increases:
--   • After 0.5s → show goal animation scene source
--   • Hide after 6 seconds
-- If both scores = 0 → hide everything immediately (warmup reset).

obs = obslua

------------------------------------------------------------
-- USER CONFIG
------------------------------------------------------------
red_score_file = ""
blue_score_file = ""
check_interval_ms = 200

------------------------------------------------------------
-- INTERNAL STATE
------------------------------------------------------------
last_red_score = 0
last_blue_score = 0

timers = {
    red  = { show_fn = nil, hide_fn = nil },
    blue = { show_fn = nil, hide_fn = nil }
}

------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------
local function trim(s)
    if not s then return s end
    return s:match("^%s*(.-)%s*$")
end

local function read_number_from_file(path)
    if not path or path == "" then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return tonumber(trim(content))
end

local function set_source_visibility(scene_name, source_name, visible)
    local scene_src = obs.obs_get_source_by_name(scene_name)
    if scene_src == nil then return end
    local scene = obs.obs_scene_from_source(scene_src)

    if scene ~= nil then
        local item = obs.obs_scene_find_source(scene, source_name)
        if item ~= nil then
            obs.obs_sceneitem_set_visible(item, visible)
        end
    end

    obs.obs_source_release(scene_src)
end

local function hide_red()
    set_source_visibility("Scorebug", "Away Goal Anim", false)
end

local function hide_blue()
    set_source_visibility("Scorebug", "Home Goal Anim", false)
end

------------------------------------------------------------
-- TIMER HELPERS
------------------------------------------------------------
local function remove_timer(team, name)
    if timers[team][name] then
        obs.timer_remove(timers[team][name])
        timers[team][name] = nil
    end
end

local function start_one_shot(team, ms, name, fn)
    remove_timer(team, name)
    timers[team][name] = fn
    obs.timer_add(fn, ms)
end

------------------------------------------------------------
-- GOAL TRIGGERS
------------------------------------------------------------
local function trigger_red_goal()
    remove_timer("red", "show_fn")
    remove_timer("red", "hide_fn")

    local function show_anim()
        set_source_visibility("Scorebug", "Away Goal Anim", true)
        obs.timer_remove(show_anim)
        timers.red.show_fn = nil
    end

    local function hide_anim()
        hide_red()
        obs.timer_remove(hide_anim)
        timers.red.hide_fn = nil
    end

    start_one_shot("red", 500,  "show_fn", show_anim)
    start_one_shot("red", 6500, "hide_fn", hide_anim)
end

local function trigger_blue_goal()
    remove_timer("blue", "show_fn")
    remove_timer("blue", "hide_fn")

    local function show_anim()
        set_source_visibility("Scorebug", "Home Goal Anim", true)
        obs.timer_remove(show_anim)
        timers.blue.show_fn = nil
    end

    local function hide_anim()
        hide_blue()
        obs.timer_remove(hide_anim)
        timers.blue.hide_fn = nil
    end

    start_one_shot("blue", 500,  "show_fn", show_anim)
    start_one_shot("blue", 6500, "hide_fn", hide_anim)
end

------------------------------------------------------------
-- MAIN CHECK LOOP
------------------------------------------------------------
function check_scores()
    local red  = read_number_from_file(red_score_file)
    local blue = read_number_from_file(blue_score_file)

    -- Prevent false triggers on failed reads
    if not red or not blue then return end

    -- Warmup reset (0–0)
    if red == 0 and blue == 0 then
        remove_timer("red", "show_fn")
        remove_timer("red", "hide_fn")
        remove_timer("blue", "show_fn")
        remove_timer("blue", "hide_fn")

        hide_red()
        hide_blue()

        last_red_score = 0
        last_blue_score = 0
        return
    end

    -- Trigger ONLY on +1 increments
    if red - last_red_score == 1 then
        trigger_red_goal()
    end

    if blue - last_blue_score == 1 then
        trigger_blue_goal()
    end

    last_red_score  = red
    last_blue_score = blue
end

------------------------------------------------------------
-- OBS INTERFACE
------------------------------------------------------------
function script_description()
    return "Scorebug goal animation trigger with +1 detection and warmup protection."
end

function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_path(
        props, "red_score_file", "Red Score File",
        obs.OBS_PATH_FILE, "Text Files (*.txt)", nil
    )

    obs.obs_properties_add_path(
        props, "blue_score_file", "Blue Score File",
        obs.OBS_PATH_FILE, "Text Files (*.txt)", nil
    )

    return props
end

function script_update(settings)
    red_score_file  = obs.obs_data_get_string(settings, "red_score_file")
    blue_score_file = obs.obs_data_get_string(settings, "blue_score_file")
end

function script_load(settings)
    obs.timer_add(check_scores, check_interval_ms)
end

function script_unload()
    obs.timer_remove(check_scores)
end

obs = obslua

------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------
csv_path = ""
phase_path = ""
red_output_path = ""
blue_output_path = ""
check_interval_ms = 500
tmp_copy = ""

------------------------------------------------------------
-- STATE
------------------------------------------------------------
player_team = {}        -- steamid -> current team
player_shots = {}       -- steamid -> current team shot count
display_red = 0
display_blue = 0
total_red_shots = 0     -- cumulative total (no decrease on switches)
total_blue_shots = 0
is_warmup = false
current_phase = ""
last_player_ids = {}

------------------------------------------------------------
-- FILE HELPERS
------------------------------------------------------------
function copy_file(src, dest)
    local input = io.open(src, "rb")
    if not input then
        print("[Puck Shots] ❌ Cannot open CSV: " .. tostring(src))
        return false
    end
    local data = input:read("*all")
    input:close()

    local output, err = io.open(dest, "wb")
    if not output then
        print("[Puck Shots] ❌ Cannot write temp file: " .. tostring(dest) .. " (" .. tostring(err) .. ")")
        return false
    end
    output:write(data)
    output:close()
    return true
end

function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

function write_file(path, data)
    if path == "" then return end
    local f, err = io.open(path, "w")
    if not f then
        print("[Puck Shots] ❌ Could not write: " .. tostring(path) .. " (" .. tostring(err) .. ")")
        return
    end
    f:write(tostring(data))
    f:close()
end

------------------------------------------------------------
-- CSV PARSE
------------------------------------------------------------
function process_csv(content)
    local seen_ids = {}

    for line in string.gmatch(content, "([^\r\n]+)") do
        if not line:match("^%s*$") and not line:lower():match("username") then
            local name, number, team, steamid, shots =
                line:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)")

            if team and steamid and shots then
                local team_clean = team:lower():gsub("%s+", "")
                local shot_count = tonumber(shots) or 0
                seen_ids[steamid] = true

                local prev_team = player_team[steamid]
                local prev_shots = player_shots[steamid] or 0

                -- Detect new player or increased shots
                local delta = math.max(0, shot_count - prev_shots)

                -- Add only positive deltas to team total
                if delta > 0 then
                    if team_clean == "red" then
                        total_red_shots = total_red_shots + delta
                    elseif team_clean == "blue" then
                        total_blue_shots = total_blue_shots + delta
                    end
                end

                player_team[steamid] = team_clean
                player_shots[steamid] = shot_count
            end
        end
    end

    -- Detect large roster change (new lobby)
    detect_new_lobby(seen_ids)

    -- Clean up removed players
    for id, _ in pairs(player_team) do
        if not seen_ids[id] then
            player_team[id] = nil
            player_shots[id] = nil
        end
    end
end

------------------------------------------------------------
-- LOBBY DETECTION
------------------------------------------------------------
function detect_new_lobby(current_ids)
    local old_count, new_count = 0, 0
    for _ in pairs(last_player_ids) do old_count = old_count + 1 end
    for _ in pairs(current_ids) do new_count = new_count + 1 end

    local overlap = 0
    for id, _ in pairs(current_ids) do
        if last_player_ids[id] then overlap = overlap + 1 end
    end

    local overlap_ratio = 0
    if math.max(old_count, new_count) > 0 then
        overlap_ratio = overlap / math.max(old_count, new_count)
    end

    -- Detect new lobby if:
    -- - no overlap (new set of players)
    -- - or > 50% player turnover
    if overlap_ratio < 0.5 and old_count > 0 then
        print("[Puck Shots] 🔄 New lobby detected — resetting totals and player data")
        reset_all_totals()
    end

    last_player_ids = current_ids
end

------------------------------------------------------------
-- RESET
------------------------------------------------------------
function reset_all_totals()
    display_red, display_blue = 0, 0
    total_red_shots, total_blue_shots = 0, 0
    player_team = {}
    player_shots = {}
    write_file(red_output_path, 0)
    write_file(blue_output_path, 0)
end

------------------------------------------------------------
-- UPDATE LOOP
------------------------------------------------------------
function check_for_updates()
    if csv_path == "" or not csv_path:match("%S") then return end

    local phase = read_file(phase_path)
    local warmup_now = (not phase) or (phase:match("^%s*$"))
    local phase_clean = phase and phase:gsub("%s+", "") or ""

    if phase_clean ~= current_phase then
        current_phase = phase_clean
        if warmup_now then
            print("[Puck Shots] 🧊 Phase changed → WARMUP")
        else
            print("[Puck Shots] 🏁 Phase changed → " .. current_phase)
        end
    end

    -- Warmup handling
    if warmup_now and not is_warmup then
        print("[Puck Shots] 🧊 Entered warmup — resetting all totals to 0")
        reset_all_totals()
        is_warmup = true
        return
    end

    if not warmup_now and is_warmup then
        print("[Puck Shots] 🟢 Game start detected (" .. current_phase .. ") — totals reset")
        reset_all_totals()
        is_warmup = false
    end

    if warmup_now then return end

    local copied = copy_file(csv_path, tmp_copy)
    if not copied then return end

    local content = read_file(tmp_copy)
    if not content then return end

    process_csv(content)

    display_red = total_red_shots
    display_blue = total_blue_shots

    write_file(red_output_path, display_red)
    write_file(blue_output_path, display_blue)
end

------------------------------------------------------------
-- TIMER CONTROL
------------------------------------------------------------
function start_timer()
    obs.timer_remove(check_for_updates)
    obs.timer_add(check_for_updates, check_interval_ms)
    print(string.format("[Puck Shots] Timer started (%d ms)", check_interval_ms))
end

------------------------------------------------------------
-- OBS HOOKS
------------------------------------------------------------
function script_description()
    return [[
🏒 **Puck Shots Tracker (Stable Totals + Warmup Reset + Lobby Detection)**  
- Totals no longer drop from spectators/team switches  
- Detects new lobbies automatically and resets  
- Resets properly during warmup  
- Logs phases (1st, 2nd, etc.)  
- Writes red/blue totals to .txt files for OBS display  
]]
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_path(props, "csv_path", "Input CSV File", obs.OBS_PATH_FILE, "*.csv", nil)
    obs.obs_properties_add_path(props, "phase_path", "Phase Input File", obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_path(props, "red_output_path", "Red Output File", obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_path(props, "blue_output_path", "Blue Output File", obs.OBS_PATH_FILE, "*.txt", nil)
    obs.obs_properties_add_int(props, "check_interval_ms", "Update Interval (ms)", 100, 5000, 100)
    return props
end

function script_update(settings)
    csv_path = obs.obs_data_get_string(settings, "csv_path")
    phase_path = obs.obs_data_get_string(settings, "phase_path")
    red_output_path = obs.obs_data_get_string(settings, "red_output_path")
    blue_output_path = obs.obs_data_get_string(settings, "blue_output_path")
    check_interval_ms = obs.obs_data_get_int(settings, "check_interval_ms")

    tmp_copy = csv_path:gsub("[^\\/]+$", "puck_tmp.csv")

    print("[Puck Shots] Watching CSV:", csv_path)
    print("[Puck Shots] Watching Phase File:", phase_path)
    print("[Puck Shots] Output → Red:", red_output_path)
    print("[Puck Shots] Output → Blue:", blue_output_path)

    start_timer()
    check_for_updates()
end

function script_load(settings)
    print("[Puck Shots] Script loaded — waiting 1s to start timer")
    obs.timer_add(function()
        start_timer()
        check_for_updates()
    end, 1000)
end

function script_unload()
    obs.timer_remove(check_for_updates)
    print("[Puck Shots] Script unloaded.")
end

local Preferences = require("preferences")
local pref = Preferences:new("rotasi_lolistore_config.json")

local config = {
    block_id             = pref:get("block_id",             0),
    search_name          = pref:get("search_name",          ""),
    pnb_x                = pref:get("pnb_x",                0),
    pnb_y                = pref:get("pnb_y",                0),
    pnb_mode             = pref:get("pnb_mode",             1),
    
    -- AUTOFARM SETTINGS
    enable_verify_punch  = pref:get("enable_verify_punch",  true),
    enable_break         = pref:get("enable_break",         true),
    enable_place         = pref:get("enable_place",         true),
    hit_count            = pref:get("hit_count",            1),
    faster_break         = pref:get("faster_break",         false),
    
    -- DROP SEED/BLOCK UTAMA
    high_trigger         = pref:get("high_trigger",          180),
    low_trigger          = pref:get("low_trigger",           10),
    farm_world           = pref:get("farm_world",           ""),
    farm_door            = pref:get("farm_door",            ""),
    drop_world           = pref:get("drop_world",           ""),
    drop_door            = pref:get("drop_door",            ""),
    drop_item_id         = pref:get("drop_item_id",         0),
    min_drop_amt         = pref:get("min_drop_amt",         20),
    drop_x               = pref:get("drop_x",               0),
    drop_y               = pref:get("drop_y",               0),
    
    -- TRASH / EXTRA ITEM DROP CONFIG (PRE-FILLED WITH CHI & DAILY DROPS)
    enable_trash_drop    = pref:get("enable_trash_drop",    true),
    trash_item_ids       = pref:get("trash_item_ids",       "1120,1122,1124,1126,1362,1210,1422,1294,818,356,1364,226"),
    trash_drop_world     = pref:get("trash_drop_world",     ""),
    trash_drop_door      = pref:get("trash_drop_door",      ""),
    trash_drop_x         = pref:get("trash_drop_x",         0),
    trash_drop_y         = pref:get("trash_drop_y",         0),

    -- SECURITY & DELAY
    enable_anti_player   = pref:get("enable_anti_player",   true),
    anti_player_cd       = pref:get("anti_player_cd",       120),
    enable_fly           = pref:get("enable_fly",           true),
    work_min             = pref:get("work_min",             45),
    rest_min             = pref:get("rest_min",             10),
    enable_jitter        = pref:get("enable_jitter",        false),
    show_punch           = pref:get("show_punch",           true),
    
    delay_place          = pref:get("delay_place",          80),
    delay_punch          = pref:get("delay_punch",          180),
    delay_harvest        = pref:get("delay_harvest",        180),
    delay_plant          = pref:get("delay_plant",          120),
    enable_safe_delay    = pref:get("enable_safe_delay",    true),
    enable_smart_delay   = pref:get("enable_smart_delay",   true),
    enable_anti_miss     = pref:get("enable_anti_miss",     true),

    pnb_timeout          = 4000,
    pnb_retry            = 3,
}

local seed_id            = 0
local running            = false
local reconnecting       = false
local action_count       = 0
local gc_counter         = 0
local thread_instance    = 0
local session_start_time = 0

local last_action_time   = 0
local current_work_sec   = 0
local current_rest_sec   = 0

local farm_world_list    = {}
local current_farm_index = 1

local doDrop
local doTrashDrop

local function Log(msg)
    LogToConsole("`5[LoliStore 24/7] `0" .. tostring(msg))
end

local function updateActionTime()
    last_action_time = os.time()
    gc_counter = gc_counter + 1
    if gc_counter >= 50 then
        collectgarbage("collect")
        gc_counter = 0
    end
end

local function invCount(item_id)
    local ok, inv = pcall(getInventory)
    if not ok or type(inv) ~= "table" then return 0 end
    for _, item in pairs(inv) do
        if item and item.id == item_id then return item.amount end
    end
    return 0
end

local function isThreadActive(my_id)
    return running and not reconnecting and (thread_instance == my_id)
end

local function parseIdList(raw_str)
    local result = {}
    if not raw_str or raw_str == "" then return result end
    for id_str in string.gmatch(raw_str, "([^,%s]+)") do
        local id_num = tonumber(id_str)
        if id_num then
            table.insert(result, id_num)
        end
    end
    return result
end

local function checkPriorityDrop(my_id)
    if not isThreadActive(my_id) then return false end

    if config.enable_trash_drop then
        local trash_list = parseIdList(config.trash_item_ids)
        for _, t_id in ipairs(trash_list) do
            if invCount(t_id) > 0 then
                Log("`3[TRASH DROP] Item sampah/extra terdeteksi (ID: " .. t_id .. " | Jumlah: " .. invCount(t_id) .. "). Langsung drop!`0")
                doTrashDrop(my_id, t_id)
                return true
            end
        end
    end

    local target_item = (config.drop_item_id > 0) and config.drop_item_id or seed_id
    if invCount(target_item) >= config.high_trigger then
        Log("`3[PRIORITY DROP] Item penuh (" .. invCount(target_item) .. "). Langsung drop dulu!`0")
        doDrop(my_id)
        return true
    end
    return false
end

local function randomizeTimers()
    local work_var = math.random(-3, 5)
    local rest_var = math.random(-2, 3)

    local final_work = math.max(10, config.work_min + work_var)
    local final_rest = math.max(2, config.rest_min + rest_var)

    current_work_sec = final_work * 60
    current_rest_sec = final_rest * 60
    Log("Siklus Kerja Baru: " .. final_work .. " min | Istirahat: " .. final_rest .. " min")
end

local function applyModFly()
    if config.enable_fly then
        pcall(function()
            if setFly then
                setFly(true)
            elseif growtopia and growtopia.setFly then
                growtopia.setFly(true)
            end
        end)
    end
end

local function parseWorldList(raw_str)
    local result = {}
    if not raw_str or raw_str == "" then return result end
    for w in string.gmatch(raw_str, "([^,%s]+)") do
        table.insert(result, w)
    end
    return result
end

local function getCurrentFarmWorld()
    if #farm_world_list == 0 then return "" end
    if current_farm_index > #farm_world_list then
        current_farm_index = 1
    end
    return farm_world_list[current_farm_index] or ""
end

local function nextFarmWorld()
    if #farm_world_list <= 1 then return end
    current_farm_index = current_farm_index + 1
    if current_farm_index > #farm_world_list then
        current_farm_index = 1
    end
    Log("Rotasi berpindah ke World Farm berikutnya: " .. getCurrentFarmWorld())
end

local function ActionSleep(base_ms)
    local ms = base_ms

    if config.enable_safe_delay and ms < 100 then
        ms = 100
    end

    if config.enable_smart_delay then
        ms = ms + math.random(15, 65)
        action_count = action_count + 1
        if action_count % math.random(15, 25) == 0 then
            ms = ms + math.random(100, 300)
        end
    elseif config.enable_jitter then
        ms = ms + math.random(10, 40)
    end

    Sleep(ms)
end

local function getPlayer()
    local ok, p = pcall(getLocal)
    if ok and p then return p end
    return nil
end

local function getPlayerTile()
    local p = getPlayer()
    if not p then return nil, nil end
    return math.floor(p.posX / 32), math.floor(p.posY / 32)
end

local function safeGetPlayerList()
    local ok, list = pcall(getPlayerList)
    if ok and type(list) == "table" then return list end
    return nil
end

local function safeGetWorldName()
    local ok, w = pcall(GetWorldName)
    if ok and w and w ~= "" and string.upper(w) ~= "EXIT" then return w end
    return nil
end

local function warpToWorld(target_world, door_id, my_id, force)
    if not target_world or target_world == "" then return false end
    local current_w = safeGetWorldName()

    if not force and current_w and string.upper(current_w) == string.upper(target_world) then
        return true
    end

    local warp_str = target_world
    if door_id and door_id ~= "" then
        warp_str = warp_str .. "|" .. door_id
    end

    Log("Warp ke World: " .. warp_str)
    growtopia.warpTo(warp_str)

    local elapsed = 0
    while elapsed < 15000 do
        if not isThreadActive(my_id) then return false end
        local w = safeGetWorldName()
        if w and string.upper(w) == string.upper(target_world) then
            Sleep(1000)
            applyModFly()
            collectgarbage("collect")
            updateActionTime()
            return true
        end
        Sleep(1000)
        elapsed = elapsed + 1000
    end
    return false
end

local function checkAntiPlayer(my_id)
    if not config.enable_anti_player then return true end
    local players = safeGetPlayerList()
    local local_p = getPlayer()
    if not players or not local_p or not local_p.netID then return true end

    for _, p in pairs(players) do
        if p and p.netID and p.netID ~= local_p.netID then
            Log("`4[DANGER] Player/Mod terdeteksi! Warp EXIT & Cooldown " .. config.anti_player_cd .. " detik...")
            growtopia.warpTo("EXIT")

            local cd_elapsed = 0
            while cd_elapsed < config.anti_player_cd do
                if not isThreadActive(my_id) then return false end
                Sleep(1000)
                cd_elapsed = cd_elapsed + 1
            end

            Log("Cooldown selesai, kembali ke world kerja...")
            warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
            return false
        end
    end
    return true
end

local function checkWorkRestCycle(my_id)
    if config.work_min <= 0 or config.rest_min <= 0 then return end
    local elapsed_work = os.time() - session_start_time

    if elapsed_work >= current_work_sec then
        Log("Waktunya istirahat AFK (Warp ke EXIT)...")
        growtopia.warpTo("EXIT")

        local rest_elapsed = 0
        while rest_elapsed < current_rest_sec do
            if not running or (thread_instance ~= my_id) then return end
            Sleep(2000)
            if not reconnecting then
                rest_elapsed = rest_elapsed + 2
            end
        end

        session_start_time = os.time()
        randomizeTimers()
        Log("Istirahat selesai! Kembali ke world farm...")
        warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
    end
end

local function checkWatchdog(my_id)
    if last_action_time == 0 then return end
    local idle_time = os.time() - last_action_time

    if idle_time >= 180 then
        Log("`4[WATCHDOG] Bot terdeteksi stuck/freeze (" .. idle_time .. " detik)! Memaksa re-warp...")
        last_action_time = os.time()
        warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
    end
end

local function safeGetTile(tx, ty)
    if tx < 0 or tx >= 100 or ty < 0 or ty >= 60 then return nil end
    local ok, tile = pcall(getTile, tx, ty)
    if ok then return tile end
    return nil
end

local function safeGetTiles()
    local ok, tiles = pcall(getTiles)
    if ok and type(tiles) == "table" then return tiles end
    return nil
end

local function safeGetObjects()
    local ok, objs = pcall(getObjectList)
    if ok and type(objs) == "table" then return objs end
    return nil
end

local function punchTile(tx, ty)
    if not config.enable_break then return end
    local p = getPlayer()
    if not p then return end

    if config.enable_verify_punch then
        local tile = safeGetTile(tx, ty)
        if not tile or (config.block_id > 0 and tile.fg ~= config.block_id) then
            return
        end
    end

    local hits = math.max(1, config.hit_count or 1)
    for h = 1, hits do
        sendPacketRaw(not config.show_punch, {
            type  = 3,
            value = 18,
            x     = p.posX,
            y     = p.posY,
            px    = tx,
            py    = ty
        })
        updateActionTime()

        local delay = config.faster_break and math.max(80, config.delay_punch - 40) or config.delay_punch
        ActionSleep(delay)
    end
end

local function placeBlock(tx, ty, item_id, is_plant)
    if not config.enable_place then return end
    local p = getPlayer()
    if not p then return end
    sendPacketRaw(not config.show_punch, {
        type  = 3,
        value = item_id,
        x     = p.posX,
        y     = p.posY,
        px    = tx,
        py    = ty
    })
    updateActionTime()
    ActionSleep(is_plant and config.delay_plant or config.delay_place)
end

local function walkTo(tx, ty)
    FindPath(tx, ty)
    ActionSleep(250)
    local cx, cy = getPlayerTile()
    if cx and cy then
        if (math.abs(cx - tx) <= 2 and math.abs(cy - ty) <= 2) then
            updateActionTime()
            return true
        end
    end
    return false
end

local function collectNearby(radius_px)
    radius_px = radius_px or 96
    local p = getPlayer()
    if not p then return end
    local objs = safeGetObjects()
    if not objs then return end
    for _, obj in pairs(objs) do
        if obj and obj.posX and obj.posY and obj.id then
            local dx = math.abs(p.posX - obj.posX)
            local dy = math.abs(p.posY - obj.posY)
            if dx < radius_px and dy < radius_px then
                sendPacketRaw(false, {
                    type  = 11,
                    value = obj.id,
                    x     = obj.posX + 6,
                    y     = 0
                })
                Sleep(20)
            end
        end
    end
end

local function getReadyHarvestTiles()
    local tiles  = safeGetTiles()
    local result = {}
    if not tiles then return result end
    for _, tile in pairs(tiles) do
        if tile and tile.fg == seed_id and tile.readyharvest == true then
            table.insert(result, {x = tile.x, y = tile.y})
        end
    end
    table.sort(result, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return result
end

local function getPlantableTiles()
    local tiles  = safeGetTiles()
    local result = {}
    if not tiles then return result end
    for _, tile in pairs(tiles) do
        if tile and tile.fg == 0 then
            local below = safeGetTile(tile.x, tile.y + 1)
            if below and below.fg ~= 0 and below.fg ~= seed_id then
                table.insert(result, {x = tile.x, y = tile.y})
            end
        end
    end
    table.sort(result, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return result
end

local function doPlant(my_id)
    if not config.enable_place then return end
    if invCount(seed_id) < config.low_trigger then return end

    local plant_tiles = getPlantableTiles()
    if #plant_tiles == 0 then return end

    for _, t in ipairs(plant_tiles) do
        if not isThreadActive(my_id) or not checkAntiPlayer(my_id) then return end
        if checkPriorityDrop(my_id) then end
        if invCount(seed_id) <= config.low_trigger then break end

        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == 0 then
            if walkTo(t.x, t.y) then
                local retry = 0
                while retry < config.pnb_retry do
                    if not isThreadActive(my_id) then return end
                    placeBlock(t.x, t.y, seed_id, true)

                    if config.enable_anti_miss then
                        local check_tile = safeGetTile(t.x, t.y)
                        if check_tile and check_tile.fg == seed_id then
                            break
                        else
                            retry = retry + 1
                            ActionSleep(100)
                        end
                    else
                        break
                    end
                end
            end
        end
    end
end

local function doHarvestLoop(my_id)
    local ready_tiles = getReadyHarvestTiles()
    if #ready_tiles == 0 then return end

    for _, t in ipairs(ready_tiles) do
        if not isThreadActive(my_id) or not checkAntiPlayer(my_id) then return end
        if checkPriorityDrop(my_id) then end
        if invCount(config.block_id) >= config.high_trigger then break end

        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == seed_id and tile.readyharvest == true then
            local reached = walkTo(t.x, t.y)
            if reached then
                local retry = 0
                while retry < config.pnb_retry do
                    if not isThreadActive(my_id) then return end
                    punchTile(t.x, t.y)

                    if config.enable_anti_miss then
                        local check_tile = safeGetTile(t.x, t.y)
                        if check_tile and check_tile.fg == 0 then
                            break
                        else
                            retry = retry + 1
                            ActionSleep(100)
                        end
                    else
                        break
                    end
                end
                collectNearby()
                checkPriorityDrop(my_id)
            end
        end
    end
end

doTrashDrop = function(my_id, item_id)
    local count = invCount(item_id)
    if count <= 0 then return end

    local target_trash_world = (config.trash_drop_world and config.trash_drop_world ~= "") and config.trash_drop_world or getCurrentFarmWorld()
    local ok_warp = warpToWorld(target_trash_world, config.trash_drop_door, my_id, true)
    
    if not ok_warp then
        Log("Gagal warp ke Trash Storage World!")
        return
    end

    if not isThreadActive(my_id) then return end

    local try_x = config.trash_drop_x
    local try_y = config.trash_drop_y

    walkTo(try_x, try_y)
    Sleep(300)

    sendPacket(2, "action|drop\nitemID|" .. item_id .. "\n")
    Sleep(200)
    sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. item_id .. "|\ncount|" .. count .. "\n")
    Sleep(300)

    Log("TRASH DROP Berhasil! Item ID: " .. item_id .. " (" .. count .. " pcs) di X=" .. try_x .. ", Y=" .. try_y)
    
    warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
end

doDrop = function(my_id)
    local target_item = (config.drop_item_id > 0) and config.drop_item_id or seed_id
    local total_item  = invCount(target_item)
    
    local keep_amount    = math.floor(total_item / 2)
    local amount_to_drop = total_item - keep_amount

    if amount_to_drop < config.min_drop_amt then
        Log("Jumlah item yang akan di-drop (" .. amount_to_drop .. ") kurang dari minimal (" .. config.min_drop_amt .. "). Batal warp storage.")
        return
    end

    if amount_to_drop > 200 then
        amount_to_drop = 200
    end

    local target_drop_world = (config.drop_world and config.drop_world ~= "") and config.drop_world or getCurrentFarmWorld()

    local ok_drop_warp = warpToWorld(target_drop_world, config.drop_door, my_id, true)
    if not ok_drop_warp then
        Log("Gagal warp ke Storage World! Batal drop item demi keamanan.")
        return
    end

    if not isThreadActive(my_id) then return end

    local try_x = config.drop_x
    local try_y = config.drop_y
    local dropped = false
    local max_shifts = 10

    for i = 1, max_shifts do
        if not isThreadActive(my_id) then break end
        if try_x < 0 then break end

        walkTo(try_x, try_y)
        Sleep(300)

        local before_count = invCount(target_item)
        sendPacket(2, "action|drop\nitemID|" .. target_item .. "\n")
        Sleep(200)
        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. target_item .. "|\ncount|" .. amount_to_drop .. "\n")
        Sleep(300)

        if invCount(target_item) < before_count then
            dropped = true
            updateActionTime()
            Log("DROP berhasil di X=" .. try_x .. ", Y=" .. try_y .. " (" .. amount_to_drop .. " item, menyisakan " .. invCount(target_item) .. ")")
            
            if try_x ~= config.drop_x then
                config.drop_x = try_x
                pref:set("drop_x", config.drop_x)
                pref:save()
                pcall(function() editValue("drop_x", config.drop_x) end)
                Log("Titik Drop X diperbarui secara permanen ke X=" .. try_x)
            end
            break
        else
            Log("Titik X=" .. try_x .. " penuh/gagal drop. Coba mundur ke X=" .. (try_x - 1))
            try_x = try_x - 1
        end
    end

    if not dropped then
        Log("DROP gagal di semua titik percobaan!")
    end

    warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
end

local function getPnbTargets(cx, cy)
    local mode = config.pnb_mode or 1
    if mode == 2 then
        return {
            {x = cx - 1, y = cy - 1},
            {x = cx,     y = cy - 1},
            {x = cx + 1, y = cy - 1},
        }
    elseif mode == 3 then
        return {
            {x = cx, y = cy + 1},
            {x = cx, y = cy + 2},
        }
    else
        return {
            {x = cx - 2, y = cy - 1},
            {x = cx - 1, y = cy - 1},
            {x = cx,     y = cy - 1},
            {x = cx + 1, y = cy - 1},
            {x = cx + 2, y = cy - 1},
        }
    end
end

local function doPnb(my_id)
    Log("START PNB (Mode: " .. config.pnb_mode .. ")")
    walkTo(config.pnb_x, config.pnb_y)
    Sleep(300)

    while isThreadActive(my_id) do
        if not checkAntiPlayer(my_id) then return end
        
        if checkPriorityDrop(my_id) then
            walkTo(config.pnb_x, config.pnb_y)
            Sleep(300)
        end

        if invCount(config.block_id) <= config.low_trigger then
            return "low_block"
        end

        local cx, cy = getPlayerTile()
        if not cx or cx ~= config.pnb_x or cy ~= config.pnb_y then
            walkTo(config.pnb_x, config.pnb_y)
            Sleep(300)
            cx, cy = getPlayerTile()
            if not cx then return end
        end

        local targets = getPnbTargets(cx, cy)

        if config.enable_place then
            for _, t in ipairs(targets) do
                if not isThreadActive(my_id) then return end
                if invCount(config.block_id) <= 0 then break end
                local tile = safeGetTile(t.x, t.y)
                if tile and tile.fg == 0 then
                    placeBlock(t.x, t.y, config.block_id, false)
                end
            end
        end

        if config.enable_break then
            while isThreadActive(my_id) do
                local all_broken = true
                for _, t in ipairs(targets) do
                    local cur = safeGetTile(t.x, t.y)
                    if cur and cur.fg ~= 0 then
                        all_broken = false
                        punchTile(t.x, t.y)
                    end
                end
                if all_broken then break end
            end
        end

        collectNearby()
        checkPriorityDrop(my_id)
    end
end

local function processCurrentWorld(my_id)
    while isThreadActive(my_id) do
        if not checkAntiPlayer(my_id) then return false end
        applyModFly()
        checkWatchdog(my_id)

        checkPriorityDrop(my_id)

        local ready_tiles = getReadyHarvestTiles()
        local plant_tiles = getPlantableTiles()
        local current_blocks = invCount(config.block_id)

        if #ready_tiles == 0 and (#plant_tiles == 0 or invCount(seed_id) < config.low_trigger) and current_blocks < config.high_trigger then
            Log("World ini sudah bersih (tidak ada tanaman/lahan/block PnB). Pindah world!")
            return true
        end

        if #ready_tiles > 0 and current_blocks < config.high_trigger then
            doHarvestLoop(my_id)
            if not isThreadActive(my_id) then return false end
        end

        current_blocks = invCount(config.block_id)

        if current_blocks >= config.high_trigger then
            doPnb(my_id)
            if not isThreadActive(my_id) then return false end
        end

        if invCount(seed_id) >= config.low_trigger then
            doPlant(my_id)
            if not isThreadActive(my_id) then return false end
        end

        Sleep(200)
    end
    return false
end

local function reconnectMonitor(my_id)
    local retry_delay = 5000
    while running and (thread_instance == my_id) do
        Sleep(3000)
        local p = getPlayer()
        local w = safeGetWorldName()
        if not p or not w then
            reconnecting = true
            Log("`4[DISCONNECT] Mencoba reconnecting ke world...")
            
            while running and (thread_instance == my_id) do
                Sleep(retry_delay)
                local target_w = getCurrentFarmWorld()
                local ok = warpToWorld(target_w, config.farm_door, my_id, true)
                if ok then
                    Log("Berhasil reconnect ke world " .. tostring(target_w))
                    retry_delay = 5000
                    break
                else
                    retry_delay = math.min(60000, retry_delay + 5000)
                    Log("Gagal reconnect, mencoba lagi dalam " .. math.floor(retry_delay / 1000) .. " detik...")
                end
            end
            reconnecting = false
        end
    end
end

local function onConsoleMessage(msg)
    if running and type(msg) == "string" then
        local lower = string.lower(msg)
        if string.find(lower, "mod") or string.find(lower, "suspended") or string.find(lower, "maintenance") then
            Log("`4[ALERT CONSOLE] Pesan bahaya terdeteksi: " .. msg)
            pcall(function() growtopia.warpTo("EXIT") end)
        end
    end
end

local function onVariant(var, pkt)
    if running and var and var.v1 == "OnDialogRequest" then
        if type(var.v2) == "string" and string.find(var.v2, "drop_item") then
            return true
        end
    end
end

local function mainLoop(my_id)
    math.randomseed(os.time())

    seed_id            = config.block_id + 1
    reconnecting       = false
    action_count       = 0
    gc_counter         = 0
    session_start_time = os.time()
    last_action_time   = os.time()

    randomizeTimers()

    farm_world_list    = parseWorldList(config.farm_world)
    current_farm_index = 1

    if #farm_world_list == 0 then
        local cw = safeGetWorldName()
        if cw then table.insert(farm_world_list, cw) end
    end

    Log("ROTASI 24/7 MULAI! Total Farm World: " .. #farm_world_list)

    runThread(function() reconnectMonitor(my_id) end)

    while isThreadActive(my_id) do
        checkWorkRestCycle(my_id)
        if not checkAntiPlayer(my_id) then break end

        local target_farm = getCurrentFarmWorld()
        local ok_farm = warpToWorld(target_farm, config.farm_door, my_id, true)

        if ok_farm then
            local finished_world = processCurrentWorld(my_id)
            if not isThreadActive(my_id) then break end

            if finished_world then
                nextFarmWorld()
            end
        else
            Log("Gagal warp ke Farm World: " .. target_farm .. ", mencoba ke world berikutnya...")
            nextFarmWorld()
        end

        Sleep(200)
    end
end

local ui = UserInterface.new("Auto Rotasi 24/7", "Ability")

ui:addLabelApp("AUTO ROTASI 24/7 BY LOLISTORE", "Ability")
ui:addDivider()

local dialog_main = ui:addDialog("Main Config", "Setting utama rotasi", {})
ui:addChildInputString(dialog_main.menu, "Search Item Name", config.search_name, "Nama", "Contoh: pepper / chand", "Search", "search_name")
ui:addChildButton(dialog_main.menu,      "🔍 Search Item in Inventory", "btn_search_item")
ui:addChildButton(dialog_main.menu,      "✋ Pick Item in Hand",        "btn_pick_hand")
ui:addChildInputInt(dialog_main.menu,    "Block ID (Auto)",  config.block_id,     "ID",    "ID block (terisi otomatis)",         "Verified", "block_id")
ui:addChildInputString(dialog_main.menu, "Farm World",       config.farm_world,   "World", "FARM1,FARM2 (pisahkan koma)",        "World",    "farm_world")
ui:addChildInputString(dialog_main.menu, "Farm Door",        config.farm_door,    "ID",    "ID door universal world farm",       "World",    "farm_door")
ui:addChildInputInt(dialog_main.menu,    "High Trigger",     config.high_trigger, "amt",   "item>=ini->Drop (def:180)",          "Verified", "high_trigger")
ui:addChildInputInt(dialog_main.menu,    "Low Trigger",      config.low_trigger,  "amt",   "block/seed<=ini->stop (def:10)",     "Verified", "low_trigger")

ui:addDivider()

local dialog_autofarm = ui:addDialog("Autofarm Setting", "Settings for autofarm (Break & Place)", {})
ui:addChildToggle(dialog_autofarm.menu,   "Verify before punch", config.enable_verify_punch, "enable_verify_punch")
ui:addChildToggle(dialog_autofarm.menu,   "Break",               config.enable_break,        "enable_break")
ui:addChildToggle(dialog_autofarm.menu,   "Place",               config.enable_place,        "enable_place")
ui:addChildInputInt(dialog_autofarm.menu, "Hit Count",           config.hit_count,           "cnt", "Pukulan per siklus (def:1)", "Verified", "hit_count")

ui:addDivider()

local dialog_pnb = ui:addDialog("PnB Position & Mode", "Pengaturan lokasi & ubin pecah PnB", {})
ui:addChildInputInt(dialog_pnb.menu, "PnB X", config.pnb_x, "X", "koordinat X", "Verified", "pnb_x")
ui:addChildInputInt(dialog_pnb.menu, "PnB Y", config.pnb_y, "Y", "koordinat Y", "Verified", "pnb_y")
ui:addChildButton(dialog_pnb.menu, "Set dari posisi sekarang", "btn_pnb_set")
ui:addChildInputInt(dialog_pnb.menu, "Break Pattern Mode", config.pnb_mode, "Mode", "1: 5-Tile Top | 2: 3-Tile Top | 3: 2-Tile Bottom", "Verified", "pnb_mode")

ui:addDivider()

local dialog_delay = ui:addDialog("Delay & Speed Settings", "Pengaturan kecepatan aksi (ms)", {})
ui:addChildInputInt(dialog_delay.menu, "Delay Break (ms)",   config.delay_punch,        "ms", "Delay memukul block (def: 180)", "Verified", "delay_punch")
ui:addChildInputInt(dialog_delay.menu, "Delay Place (ms)",   config.delay_place,        "ms", "Delay menaruh block (def: 80)",   "Verified", "delay_place")
ui:addChildInputInt(dialog_delay.menu, "Harvest Delay (ms)", config.delay_harvest,      "ms", "Delay memanen pohon (def: 180)", "Verified", "delay_harvest")
ui:addChildInputInt(dialog_delay.menu, "Plant Delay (ms)",   config.delay_plant,        "ms", "Delay menanam seed (def: 120)",  "Verified", "delay_plant")
ui:addChildToggle(dialog_delay.menu,   "Faster Break (Turbo)", config.faster_break,      "faster_break")
ui:addChildToggle(dialog_delay.menu,   "Safe Delay Guard",   config.enable_safe_delay,  "enable_safe_delay")
ui:addChildToggle(dialog_delay.menu,   "Smart Delay",        config.enable_smart_delay, "enable_smart_delay")
ui:addChildToggle(dialog_delay.menu,   "Anti Miss (Wait)",   config.enable_anti_miss,   "enable_anti_miss")

ui:addDivider()

local dialog_drop = ui:addDialog("Seed / Block Drop Config", "Posisi & World drop seed/block utama", {})
ui:addChildInputString(dialog_drop.menu, "Drop World",      config.drop_world,   "World", "World tempat drop (kosongkan jika sama)", "World",    "drop_world")
ui:addChildInputString(dialog_drop.menu, "Drop Door",       config.drop_door,    "ID",     "ID door world drop",                      "World",    "drop_door")
ui:addChildInputInt(dialog_drop.menu,    "Drop Item ID",    config.drop_item_id, "ID",     "ID item yang di-drop (0 = otomatis seed)", "Verified", "drop_item_id")
ui:addChildInputInt(dialog_drop.menu,    "Minimal Drop Amt", config.min_drop_amt,  "amt",    "Min item di-drop biar ga sia-sia (def:20)", "Verified", "min_drop_amt")
ui:addChildInputInt(dialog_drop.menu,    "Drop X",          config.drop_x,       "X",      "koordinat X drop",                        "Verified", "drop_x")
ui:addChildInputInt(dialog_drop.menu,    "Drop Y",          config.drop_y,       "Y",      "koordinat Y drop",                        "Verified", "drop_y")
ui:addChildButton(dialog_drop.menu, "Set dari posisi sekarang", "btn_drop_set")

ui:addDivider()

local dialog_trash = ui:addDialog("Trash / Extra Items Drop", "Drop item sampah (Chi, Essence, Daily Drops)", {})
ui:addChildToggle(dialog_trash.menu,      "Enable Auto Trash Drop", config.enable_trash_drop, "enable_trash_drop")
ui:addChildInputString(dialog_trash.menu, "Trash Item IDs",        config.trash_item_ids,    "IDs", "1120,1122,1124 (pisahkan koma)",  "Verified", "trash_item_ids")
ui:addChildInputString(dialog_trash.menu, "Trash Drop World",      config.trash_drop_world,  "World", "World khusus drop trash (kosong = world skrg)", "World", "trash_drop_world")
ui:addChildInputString(dialog_trash.menu, "Trash Drop Door",       config.trash_drop_door,   "ID", "Door ID trash world", "World", "trash_drop_door")
ui:addChildInputInt(dialog_trash.menu,    "Trash Drop X",           config.trash_drop_x,      "X", "Koordinat X drop trash", "Verified", "trash_drop_x")
ui:addChildInputInt(dialog_trash.menu,    "Trash Drop Y",           config.trash_drop_y,      "Y", "Koordinat Y drop trash", "Verified", "trash_drop_y")
ui:addChildButton(dialog_trash.menu, "Set Trash Posisi Sekarang", "btn_trash_set")

ui:addDivider()

local dialog_sec = ui:addDialog("Security & Anti-Ban", "Proteksi akun 24/7", {})
ui:addChildToggle(dialog_sec.menu,      "Anti Player/Mod",      config.enable_anti_player, "enable_anti_player")
ui:addChildInputInt(dialog_sec.menu,    "Anti Player CD (detik)", config.anti_player_cd,   "sec", "Cooldown nunggu player pergi",        "Verified", "anti_player_cd")
ui:addChildToggle(dialog_sec.menu,      "Mod Fly",              config.enable_fly,         "enable_fly")
ui:addChildToggle(dialog_sec.menu,      "Show Punch (Visual)",  config.show_punch,         "show_punch")
ui:addChildInputInt(dialog_sec.menu,    "Jam Kerja (Menit)",    config.work_min,           "min", "Durasi kerja sebelum istirahat",        "Verified", "work_min")
ui:addChildInputInt(dialog_sec.menu,    "Jam Istirahat (Menit)", config.rest_min,          "min", "Durasi istirahat/AFK",                "Verified", "rest_min")
ui:addChildToggle(dialog_sec.menu,      "Human Micro-Jitter",   config.enable_jitter,      "enable_jitter")

ui:addDivider()
ui:addButton("Apply Config", "btn_apply")
ui:addDivider()
ui:addToggleButton("Start / Stop", false, "btn_start")

local temp = {
    block_id            = tostring(config.block_id),
    search_name         = config.search_name,
    high_trigger        = tostring(config.high_trigger),
    low_trigger         = tostring(config.low_trigger),
    farm_world          = config.farm_world,
    farm_door           = config.farm_door,
    drop_world          = config.drop_world,
    drop_door           = config.drop_door,
    drop_item_id        = tostring(config.drop_item_id),
    min_drop_amt        = tostring(config.min_drop_amt),
    pnb_x               = tostring(config.pnb_x),
    pnb_y               = tostring(config.pnb_y),
    pnb_mode            = tostring(config.pnb_mode),
    enable_verify_punch = config.enable_verify_punch,
    enable_break        = config.enable_break,
    enable_place        = config.enable_place,
    hit_count           = tostring(config.hit_count),
    faster_break        = config.faster_break,
    drop_x              = tostring(config.drop_x),
    drop_y              = tostring(config.drop_y),
    
    enable_trash_drop   = config.enable_trash_drop,
    trash_item_ids      = config.trash_item_ids,
    trash_drop_world    = config.trash_drop_world,
    trash_drop_door     = config.trash_drop_door,
    trash_drop_x        = tostring(config.trash_drop_x),
    trash_drop_y        = tostring(config.trash_drop_y),

    enable_anti_player  = config.enable_anti_player,
    anti_player_cd      = tostring(config.anti_player_cd),
    enable_fly          = config.enable_fly,
    show_punch          = config.show_punch,
    work_min            = tostring(config.work_min),
    rest_min            = tostring(config.rest_min),
    enable_jitter       = config.enable_jitter,
    delay_place         = tostring(config.delay_place),
    delay_punch         = tostring(config.delay_punch),
    delay_harvest       = tostring(config.delay_harvest),
    delay_plant         = tostring(config.delay_plant),
    enable_safe_delay   = config.enable_safe_delay,
    enable_smart_delay  = config.enable_smart_delay,
    enable_anti_miss    = config.enable_anti_miss,
}

function OnDraw(d)
    removeHook("onDraw")
    runCoroutine(function()
        Sleep(2000)
        addIntoModule(ui:generateJSON(), "Farm")
    end)
end

function OnValue(type, name, value)
    if     name == "block_id"            then temp.block_id            = tostring(value)
    elseif name == "search_name"         then temp.search_name         = value
    elseif name == "high_trigger"        then temp.high_trigger        = tostring(value)
    elseif name == "low_trigger"         then temp.low_trigger         = tostring(value)
    elseif name == "farm_world"          then temp.farm_world          = value
    elseif name == "farm_door"           then temp.farm_door           = value
    elseif name == "drop_world"          then temp.drop_world          = value
    elseif name == "drop_door"           then temp.drop_door           = value
    elseif name == "drop_item_id"        then temp.drop_item_id        = tostring(value)
    elseif name == "min_drop_amt"        then temp.min_drop_amt        = tostring(value)
    elseif name == "pnb_x"               then temp.pnb_x               = tostring(value)
    elseif name == "pnb_y"               then temp.pnb_y               = tostring(value)
    elseif name == "pnb_mode"            then temp.pnb_mode            = tostring(value)
    elseif name == "enable_verify_punch" then temp.enable_verify_punch = value
    elseif name == "enable_break"        then temp.enable_break        = value
    elseif name == "enable_place"        then temp.enable_place        = value
    elseif name == "hit_count"           then temp.hit_count           = tostring(value)
    elseif name == "faster_break"        then temp.faster_break        = value
    elseif name == "drop_x"              then temp.drop_x              = tostring(value)
    elseif name == "drop_y"              then temp.drop_y              = tostring(value)
    
    elseif name == "enable_trash_drop"   then temp.enable_trash_drop   = value
    elseif name == "trash_item_ids"      then temp.trash_item_ids      = value
    elseif name == "trash_drop_world"    then temp.trash_drop_world    = value
    elseif name == "trash_drop_door"     then temp.trash_drop_door     = value
    elseif name == "trash_drop_x"        then temp.trash_drop_x        = tostring(value)
    elseif name == "trash_drop_y"        then temp.trash_drop_y        = tostring(value)

    elseif name == "enable_anti_player"  then temp.enable_anti_player  = value
    elseif name == "anti_player_cd"      then temp.anti_player_cd      = tostring(value)
    elseif name == "enable_fly"          then temp.enable_fly          = value
    elseif name == "show_punch"          then temp.show_punch          = value
    elseif name == "work_min"            then temp.work_min            = tostring(value)
    elseif name == "rest_min"            then temp.rest_min            = tostring(value)
    elseif name == "enable_jitter"       then temp.enable_jitter       = value
    elseif name == "delay_place"         then temp.delay_place         = tostring(value)
    elseif name == "delay_punch"         then temp.delay_punch         = tostring(value)
    elseif name == "delay_harvest"       then temp.delay_harvest       = tostring(value)
    elseif name == "delay_plant"         then temp.delay_plant         = tostring(value)
    elseif name == "enable_safe_delay"   then temp.enable_safe_delay   = value
    elseif name == "enable_smart_delay"  then temp.enable_smart_delay  = value
    elseif name == "enable_anti_miss"    then temp.enable_anti_miss    = value

    elseif name == "btn_search_item" then
        local query = string.lower(temp.search_name or "")
        if query == "" then
            growtopia.notify("Ketik nama item dulu di kolom Search!")
            return
        end

        local ok, inv = pcall(getInventory)
        if ok and type(inv) == "table" then
            for _, item in pairs(inv) do
                local info = (getItemInfo and pcall(getItemInfo, item.id)) and getItemInfo(item.id) or nil
                local item_name = info and string.lower(info.name or "") or ""
                
                if string.find(item_name, query) then
                    config.block_id = item.id
                    seed_id         = item.id + 1
                    temp.block_id   = tostring(item.id)
                    
                    pref:set("block_id", config.block_id)
                    pref:save()
                    editValue("block_id", config.block_id)
                    
                    growtopia.notify("Ketemu! " .. (info.name or "Item") .. " (ID: " .. item.id .. ")")
                    Log("Search berhasil! Block ID set ke: " .. item.id .. ", Seed ID: " .. seed_id)
                    return
                end
            end
        end
        growtopia.notify("Item '" .. query .. "' tidak ditemukan di Inventory!")

    elseif name == "btn_pick_hand" then
        local ok, inv = pcall(getInventory)
        if ok and type(inv) == "table" then
            for _, item in pairs(inv) do
                if item and (item.active or item.is_selected) then
                    config.block_id = item.id
                    seed_id         = item.id + 1
                    temp.block_id   = tostring(item.id)
                    
                    pref:set("block_id", config.block_id)
                    pref:save()
                    editValue("block_id", config.block_id)
                    
                    growtopia.notify("Block ID di-set dari tangan: " .. item.id)
                    Log("Pick Hand Berhasil! Block ID: " .. item.id .. ", Seed ID: " .. seed_id)
                    return
                end
            end
        end
        growtopia.notify("Pegang / pilih block di inventory dulu!")

    elseif name == "btn_pnb_set" then
        local p = getPlayer()
        if p then
            local cx = math.floor(p.posX / 32)
            local cy = math.floor(p.posY / 32)
            temp.pnb_x   = tostring(cx)
            temp.pnb_y   = tostring(cy)
            config.pnb_x = cx
            config.pnb_y = cy
            editValue("pnb_x", cx)
            editValue("pnb_y", cy)
            growtopia.notify("PnB set: X=" .. cx .. " Y=" .. cy)
        end

    elseif name == "btn_drop_set" then
        local p = getPlayer()
        if p then
            local cx = math.floor(p.posX / 32)
            local cy = math.floor(p.posY / 32)
            temp.drop_x   = tostring(cx)
            temp.drop_y   = tostring(cy)
            config.drop_x = cx
            config.drop_y = cy
            editValue("drop_x", cx)
            editValue("drop_y", cy)
            growtopia.notify("Drop set: X=" .. cx .. " Y=" .. cy)
        end

    elseif name == "btn_trash_set" then
        local p = getPlayer()
        if p then
            local cx = math.floor(p.posX / 32)
            local cy = math.floor(p.posY / 32)
            temp.trash_drop_x   = tostring(cx)
            temp.trash_drop_y   = tostring(cy)
            config.trash_drop_x = cx
            config.trash_drop_y = cy
            editValue("trash_drop_x", cx)
            editValue("trash_drop_y", cy)
            growtopia.notify("Trash Drop set: X=" .. cx .. " Y=" .. cy)
        end

    elseif name == "btn_apply" then
        config.block_id           = tonumber(temp.block_id)            or config.block_id
        config.search_name        = temp.search_name
        config.high_trigger       = tonumber(temp.high_trigger)        or config.high_trigger
        config.low_trigger        = tonumber(temp.low_trigger)         or config.low_trigger
        config.farm_world         = temp.farm_world
        config.farm_door          = temp.farm_door
        config.drop_world         = temp.drop_world
        config.drop_door          = temp.drop_door
        config.drop_item_id       = tonumber(temp.drop_item_id)        or config.drop_item_id
        config.min_drop_amt       = tonumber(temp.min_drop_amt)        or config.min_drop_amt
        config.pnb_x              = tonumber(temp.pnb_x)               or config.pnb_x
        config.pnb_y              = tonumber(temp.pnb_y)               or config.pnb_y
        config.pnb_mode           = tonumber(temp.pnb_mode)            or config.pnb_mode
        config.enable_verify_punch= temp.enable_verify_punch
        config.enable_break       = temp.enable_break
        config.enable_place       = temp.enable_place
        config.hit_count          = tonumber(temp.hit_count)           or config.hit_count
        config.faster_break       = temp.faster_break
        config.drop_x             = tonumber(temp.drop_x)              or config.drop_x
        config.drop_y             = tonumber(temp.drop_y)              or config.drop_y
        
        config.enable_trash_drop  = temp.enable_trash_drop
        config.trash_item_ids     = temp.trash_item_ids
        config.trash_drop_world   = temp.trash_drop_world
        config.trash_drop_door    = temp.trash_drop_door
        config.trash_drop_x       = tonumber(temp.trash_drop_x)        or config.trash_drop_x
        config.trash_drop_y       = tonumber(temp.trash_drop_y)        or config.trash_drop_y

        config.enable_anti_player = temp.enable_anti_player
        config.anti_player_cd     = tonumber(temp.anti_player_cd)        or config.anti_player_cd
        config.enable_fly         = temp.enable_fly
        config.show_punch         = temp.show_punch
        config.work_min           = tonumber(temp.work_min)            or config.work_min
        config.rest_min           = tonumber(temp.rest_min)            or config.rest_min
        config.enable_jitter      = temp.enable_jitter
        config.delay_place        = tonumber(temp.delay_place)         or config.delay_place
        config.delay_punch        = tonumber(temp.delay_punch)         or config.delay_punch
        config.delay_harvest      = tonumber(temp.delay_harvest)       or config.delay_harvest
        config.delay_plant        = tonumber(temp.delay_plant)         or config.delay_plant
        config.enable_safe_delay  = temp.enable_safe_delay
        config.enable_smart_delay = temp.enable_smart_delay
        config.enable_anti_miss   = temp.enable_anti_miss

        seed_id = config.block_id + 1

        pref:set("block_id",            config.block_id)
        pref:set("search_name",         config.search_name)
        pref:set("high_trigger",        config.high_trigger)
        pref:set("low_trigger",         config.low_trigger)
        pref:set("farm_world",          config.farm_world)
        pref:set("farm_door",           config.farm_door)
        pref:set("drop_world",          config.drop_world)
        pref:set("drop_door",           config.drop_door)
        pref:set("drop_item_id",        config.drop_item_id)
        pref:set("min_drop_amt",        config.min_drop_amt)
        pref:set("pnb_x",               config.pnb_x)
        pref:set("pnb_y",               config.pnb_y)
        pref:set("pnb_mode",            config.pnb_mode)
        pref:set("enable_verify_punch", config.enable_verify_punch)
        pref:set("enable_break",        config.enable_break)
        pref:set("enable_place",        config.enable_place)
        pref:set("hit_count",           config.hit_count)
        pref:set("faster_break",        config.faster_break)
        pref:set("drop_x",              config.drop_x)
        pref:set("drop_y",              config.drop_y)
        
        pref:set("enable_trash_drop",   config.enable_trash_drop)
        pref:set("trash_item_ids",      config.trash_item_ids)
        pref:set("trash_drop_world",    config.trash_drop_world)
        pref:set("trash_drop_door",     config.trash_drop_door)
        pref:set("trash_drop_x",        config.trash_drop_x)
        pref:set("trash_drop_y",        config.trash_drop_y)

        pref:set("enable_anti_player",  config.enable_anti_player)
        pref:set("anti_player_cd",      config.anti_player_cd)
        pref:set("enable_fly",          config.enable_fly)
        pref:set("show_punch",          config.show_punch)
        pref:set("work_min",            config.work_min)
        pref:set("rest_min",            config.rest_min)
        pref:set("enable_jitter",       config.enable_jitter)
        pref:set("delay_place",         config.delay_place)
        pref:set("delay_punch",         config.delay_punch)
        pref:set("delay_harvest",       config.delay_harvest)
        pref:set("delay_plant",         config.delay_plant)
        pref:set("enable_safe_delay",   config.enable_safe_delay)
        pref:set("enable_smart_delay",  config.enable_smart_delay)
        pref:set("enable_anti_miss",    config.enable_anti_miss)
        pref:save()

        growtopia.notify("Trash Drop & All Config Tersimpan!")

    elseif name == "btn_start" then
        if value == true then
            if config.block_id == 0 then
                growtopia.notify("Isi Block ID dulu!")
                editValue("btn_start", false)
                return
            end
            if config.pnb_x == 0 and config.pnb_y == 0 then
                growtopia.notify("Set posisi PnB dulu!")
                editValue("btn_start", false)
                return
            end

            thread_instance = thread_instance + 1
            local current_id = thread_instance

            running          = false
            Sleep(300)
            running          = true
            reconnecting     = false
            action_count     = 0
            gc_counter       = 0

            sendVariant({v1 = "OnTextOverlay", v2 = "AUTO ROTASI 24/7 BY LOLISTORE"})
            Log("AUTO ROTASI 24/7 BY LOLISTORE — Started!")

            runThread(function()
                mainLoop(current_id)
            end)
        else
            thread_instance = thread_instance + 1
            running = false
            Log("Rotasi dihentikan.")
        end
    end
end

addHook(onConsoleMessage, "onConsoleMessage")
addHook(onVariant, "onVariant")
addHook(OnDraw, "onDraw")
addHook(OnValue, "onValue")
applyHook()

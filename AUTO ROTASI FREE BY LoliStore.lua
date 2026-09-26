local Preferences = require("preferences")[cite: 8]
local pref = Preferences:new("rotasi_lolistore_config.json")[cite: 8]

-- DAFTAR 12 ITEM SAMPAH BAWAAN
local trash_defaults = {
    { name = "Wind Essence",       id = 1120 },
    { name = "Earth Essence",      id = 1122 },
    { name = "Fire Essence",       id = 1124 },
    { name = "Water Essence",      id = 1126 },
    { name = "Aurora",             id = 1362 },
    { name = "Obsidian",           id = 1210 },
    { name = "Lava Lamp",          id = 1422 },
    { name = "Fissure",            id = 1294 },
    { name = "Waterfall",          id = 818  },
    { name = "Hidden Door",        id = 356  },
    { name = "Anemone",            id = 1364 },
    { name = "Red House Entrance", id = 226  },
}

local config = {
    block_id             = pref:get("block_id",             0),[cite: 8]
    seed_id              = pref:get("seed_id",              0),[cite: 8]
    enable_verify_punch  = pref:get("enable_verify_punch",  true),[cite: 8]
    enable_break         = pref:get("enable_break",         true),[cite: 8]
    enable_place         = pref:get("enable_place",         true),[cite: 8]
    hit_count            = pref:get("hit_count",            1),[cite: 8]
    faster_break         = pref:get("faster_break",         false),[cite: 8]
    pnb_x                = pref:get("pnb_x",                0),[cite: 8]
    pnb_y                = pref:get("pnb_y",                0),[cite: 8]
    pnb_mode             = pref:get("pnb_mode",             1),[cite: 8]
    high_trigger         = pref:get("high_trigger",          180),[cite: 8]
    low_trigger          = pref:get("low_trigger",           10),[cite: 8]
    farm_world           = pref:get("farm_world",           ""),[cite: 8]
    farm_door            = pref:get("farm_door",            ""),[cite: 8]
    drop_world           = pref:get("drop_world",           ""),[cite: 8]
    drop_door            = pref:get("drop_door",            ""),[cite: 8]
    drop_item_id         = pref:get("drop_item_id",         0),[cite: 8]
    min_drop_amt         = pref:get("min_drop_amt",         20),[cite: 8]
    drop_x               = pref:get("drop_x",               0),[cite: 8]
    drop_y               = pref:get("drop_y",               0),[cite: 8]
    enable_trash_drop    = pref:get("enable_trash_drop",    true),[cite: 8]
    trash_drop_world     = pref:get("trash_drop_world",     ""),[cite: 8]
    trash_drop_door      = pref:get("trash_drop_door",      ""),[cite: 8]
    enable_anti_player   = pref:get("enable_anti_player",   true),[cite: 8]
    anti_player_cd       = pref:get("anti_player_cd",       120),[cite: 8]
    enable_fly           = pref:get("enable_fly",           true),[cite: 8]
    work_min             = pref:get("work_min",             45),[cite: 8]
    rest_min             = pref:get("rest_min",             10),[cite: 8]
    enable_jitter        = pref:get("enable_jitter",        false),[cite: 8]
    show_punch           = pref:get("show_punch",           true),[cite: 8]
    delay_place          = pref:get("delay_place",          80),[cite: 8]
    delay_punch          = pref:get("delay_punch",          150),[cite: 8]
    delay_harvest        = pref:get("delay_harvest",        150),[cite: 8]
    delay_plant          = pref:get("delay_plant",          100),[cite: 8]
    enable_safe_delay    = pref:get("enable_safe_delay",    true),[cite: 8]
    enable_smart_delay   = pref:get("enable_smart_delay",   true),[cite: 8]
    enable_anti_miss     = pref:get("enable_anti_miss",     true),[cite: 8]
    pnb_retry            = 3,
}

for i, item in ipairs(trash_defaults) do
    config["trash_"..i.."_enable"] = pref:get("trash_"..i.."_enable", true)[cite: 8]
    config["trash_"..i.."_id"]     = pref:get("trash_"..i.."_id",     item.id)[cite: 8]
    config["trash_"..i.."_count"]  = pref:get("trash_"..i.."_count",  1)[cite: 8]
    config["trash_"..i.."_x"]      = pref:get("trash_"..i.."_x",      0)[cite: 8]
    config["trash_"..i.."_y"]      = pref:get("trash_"..i.."_y",      0)[cite: 8]
end

local active_trash_list = {}
local function updateActiveTrashList()
    active_trash_list = {}
    if not config.enable_trash_drop then return end
    for i=1, 12 do
        if config["trash_"..i.."_enable"] and config["trash_"..i.."_id"] > 0 then
            table.insert(active_trash_list, {
                name  = trash_defaults[i].name, id = config["trash_"..i.."_id"],
                count = config["trash_"..i.."_count"], x = config["trash_"..i.."_x"], y = config["trash_"..i.."_y"]
            })
        end
    end
end

local seed_id, running, reconnecting, action_count, gc_counter, thread_instance, session_start_time = 0, false, false, 0, 0, 0, 0
local last_action_time, last_priority_check, last_collect_time, current_work_sec, current_rest_sec = 0, 0, 0, 0, 0
local farm_world_list, current_farm_index = {}, 1
local doDrop, doTrashDrop

local function Log(msg) LogToConsole("`5[LoliStore 24/7] `0" .. tostring(msg)) end

local function updateActionTime()
    last_action_time = os.time()
    gc_counter = gc_counter + 1
    if gc_counter >= 50 then collectgarbage("collect"); gc_counter = 0 end
end

local function getInventoryMap()
    local ok, inv = pcall(getInventory)
    if not ok or type(inv) ~= "table" then return nil end
    local map = {}
    for _, item in pairs(inv) do
        if item and item.id then
            local id, amt = tonumber(item.id), tonumber(item.amount or item.count or item.cnt or 0) or 0
            if id then map[id] = (map[id] or 0) + amt end
        end
    end
    return map
end

local function invCount(item_id, invMap)
    if not item_id or tonumber(item_id) == 0 then return 0 end
    if invMap then return invMap[tonumber(item_id)] or 0 end
    local map = getInventoryMap()
    return map and (map[tonumber(item_id)] or 0) or 0
end

local function isThreadActive(my_id) return running and not reconnecting and (thread_instance == my_id) end

local function checkPriorityDrop(my_id, force)
    if not isThreadActive(my_id) then return false end
    local now = os.time()
    if not force and (now - last_priority_check < 2) then return false end

    local invMap = getInventoryMap()
    if not invMap then return false end

    if config.enable_trash_drop then
        for _, t in ipairs(active_trash_list) do
            local current_amt = invMap[t.id] or 0
            if current_amt >= t.count then
                last_priority_check = now
                Log("`3[TRASH DROP] " .. t.name .. " penuh. Warp Drop!`0")
                return doTrashDrop(my_id, t.id, t.x, t.y)
            end
        end
    end

    local target_item = (config.drop_item_id > 0) and config.drop_item_id or seed_id
    if target_item == 0 then target_item = config.block_id end
    if target_item > 0 then
        local current_amt = invMap[target_item] or 0
        if current_amt >= config.high_trigger then
            last_priority_check = now
            Log("`3[DROP SEED/BLOCK] Tas penuh. Warp Drop!`0")
            return doDrop(my_id)
        end
    end
    return false
end

local function randomizeTimers()
    current_work_sec = math.max(10, config.work_min + math.random(-3, 5)) * 60
    current_rest_sec = math.max(2, config.rest_min + math.random(-2, 3)) * 60
end

local function applyModFly()
    if config.enable_fly then pcall(function() if setFly then setFly(true) elseif growtopia and growtopia.setFly then growtopia.setFly(true) end end) end
end

local function parseWorldList(raw_str)
    local result = {}
    if not raw_str or raw_str == "" then return result end
    for w in string.gmatch(raw_str, "([^,%s]+)") do table.insert(result, w) end
    return result
end

local function getCurrentFarmWorld()
    if #farm_world_list == 0 then return "" end
    if current_farm_index > #farm_world_list then current_farm_index = 1 end
    return farm_world_list[current_farm_index] or ""
end

local function nextFarmWorld()
    if #farm_world_list <= 1 then return end
    current_farm_index = (current_farm_index % #farm_world_list) + 1
    Log("Pindah ke World Farm: " .. getCurrentFarmWorld())
end

-- TURBO ACTION SLEEP (Pengurangan beban Smart Delay)
local function ActionSleep(base_ms)
    local ms = base_ms
    if config.enable_safe_delay and ms < 80 then ms = 80 end
    if config.enable_smart_delay then
        ms = ms + math.random(5, 20)
        action_count = action_count + 1
        if action_count % 30 == 0 then ms = ms + math.random(50, 150) end
    elseif config.enable_jitter then
        ms = ms + math.random(5, 10)
    end
    Sleep(ms)
end

local function getPlayer() local ok, p = pcall(getLocal); if ok and p then return p end; return nil end
local function getPlayerTile() local p = getPlayer(); if not p then return nil, nil end; return math.floor(p.posX / 32), math.floor(p.posY / 32) end
local function safeGetPlayerList() local ok, list = pcall(getPlayerList); if ok and type(list) == "table" then return list end; return nil end
local function safeGetWorldName() local ok, w = pcall(GetWorldName); if ok and w and w ~= "" and string.upper(w) ~= "EXIT" then return w end; return nil end

local function warpToWorld(target_world, door_id, my_id, force)
    if not target_world or target_world == "" then return false end
    local current_w = safeGetWorldName()
    if not force and current_w and string.upper(current_w) == string.upper(target_world) then return true end

    local warp_str = door_id and door_id ~= "" and (target_world .. "|" .. door_id) or target_world
    Log("Warp: " .. warp_str)
    growtopia.warpTo(warp_str)

    local elapsed = 0
    while elapsed < 15000 do
        if not isThreadActive(my_id) then return false end
        local w = safeGetWorldName()
        if w and string.upper(w) == string.upper(target_world) then
            Sleep(1000)
            applyModFly()
            updateActionTime()
            return true
        end
        Sleep(1000); elapsed = elapsed + 1000
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
            Log("`4[ANTI-PLAYER] Orang terdeteksi! Lari ke EXIT. CD: " .. config.anti_player_cd .. " dtk")
            growtopia.warpTo("EXIT")
            local cd = 0
            while cd < config.anti_player_cd do
                if not isThreadActive(my_id) then return false end
                Sleep(1000); cd = cd + 1
            end
            warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
            return false
        end
    end
    return true
end

local function checkWorkRestCycle(my_id)
    if config.work_min <= 0 or config.rest_min <= 0 then return end
    if (os.time() - session_start_time) >= current_work_sec then
        Log("Waktunya istirahat AFK...")
        growtopia.warpTo("EXIT")
        local rest = 0
        while rest < current_rest_sec do
            if not isThreadActive(my_id) then return end
            Sleep(2000); if not reconnecting then rest = rest + 2 end
        end
        session_start_time = os.time()
        randomizeTimers()
        warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
    end
end

local function safeGetTile(tx, ty) if tx < 0 or tx >= 100 or ty < 0 or ty >= 60 then return nil end; local ok, t = pcall(getTile, tx, ty); return ok and t or nil end
local function safeGetTiles() local ok, t = pcall(getTiles); return ok and type(t) == "table" and t or nil end
local function safeGetObjects() local ok, o = pcall(getObjectList); return ok and type(o) == "table" and o or nil end

local function punchTile(tx, ty, target_id)
    if not config.enable_break then return end
    local p = getPlayer()
    if not p then return end
    if config.enable_verify_punch then
        local t = safeGetTile(tx, ty)
        if not t or ((target_id or config.block_id) > 0 and t.fg ~= (target_id or config.block_id)) then return end
    end
    for h = 1, math.max(1, config.hit_count) do
        sendPacketRaw(not config.show_punch, { type = 3, value = 18, x = p.posX, y = p.posY, px = tx, py = ty })
        updateActionTime()
        ActionSleep(config.faster_break and math.max(60, config.delay_punch - 40) or config.delay_punch)
    end
end

local function placeBlock(tx, ty, item_id, is_plant)
    if not config.enable_place then return end
    local p = getPlayer()
    if not p then return end
    sendPacketRaw(not config.show_punch, { type = 3, value = item_id, x = p.posX, y = p.posY, px = tx, py = ty })
    updateActionTime()
    ActionSleep(is_plant and config.delay_plant or config.delay_place)
end

-- TURBO WALKTO DINAMIS (Delay Jalan mengikuti Input "Delay Plant" User)
local function walkTo(tx, ty)
    FindPath(tx, ty)
    
    -- Jeda ambil dari config.delay_plant, minimal 80ms biar ga nabrak server
    local walk_delay = math.max(80, config.delay_plant)
    Sleep(walk_delay) 
    
    local cx, cy = getPlayerTile()
    if cx and cy and (math.abs(cx - tx) <= 2 and math.abs(cy - ty) <= 2) then 
        updateActionTime()
        return true 
    end
    return false
end

-- TURBO COLLECT (Pungut kilat tanpa antre panjang)
local function collectNearby(radius_px)
    local now = os.time()
    if (now - last_collect_time) < 1 then return end
    last_collect_time = now
    local p, objs = getPlayer(), safeGetObjects()
    if not p or not objs then return end
    local collected = false
    for _, obj in pairs(objs) do
        if obj and obj.posX and obj.id and math.abs(p.posX - obj.posX) < (radius_px or 96) and math.abs(p.posY - obj.posY) < (radius_px or 96) then
            sendPacketRaw(false, { type = 11, value = obj.id, x = obj.posX + 6, y = 0 })
            collected = true
        end
    end
    if collected then Sleep(30) end 
end

local function getReadyHarvestTiles()
    local r, t = {}, safeGetTiles()
    if t then for _, tile in pairs(t) do
        if tile and tile.fg == seed_id and (tile.readyharvest == true or tile.ready == true or tile.readyharvest == nil) then table.insert(r, {x = tile.x, y = tile.y}) end
    end end
    table.sort(r, function(a, b) return a.y ~= b.y and a.y < b.y or a.x < b.x end)
    return r
end

local function getPlantableTiles()
    local r, t = {}, safeGetTiles()
    if t then for _, tile in pairs(t) do
        if tile and tile.fg == 0 then
            local b = safeGetTile(tile.x, tile.y + 1)
            if b and b.fg ~= 0 and b.fg ~= seed_id then table.insert(r, {x = tile.x, y = tile.y}) end
        end
    end end
    table.sort(r, function(a, b) return a.y ~= b.y and a.y < b.y or a.x < b.x end)
    return r
end

local function doPlant(my_id)
    if not config.enable_place or invCount(seed_id) < config.low_trigger then return end
    local plant_tiles = getPlantableTiles()
    for _, t in ipairs(plant_tiles) do
        if not isThreadActive(my_id) or not checkAntiPlayer(my_id) or checkPriorityDrop(my_id) or invCount(seed_id) <= config.low_trigger then return end
        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == 0 and walkTo(t.x, t.y) then
            for retry = 1, config.pnb_retry do
                placeBlock(t.x, t.y, seed_id, true)
                if config.enable_anti_miss then
                    local ck = safeGetTile(t.x, t.y)
                    if ck and ck.fg == seed_id then break else ActionSleep(80) end
                else break end
            end
        end
    end
end

local function doHarvestLoop(my_id)
    local ready_tiles = getReadyHarvestTiles()
    for _, t in ipairs(ready_tiles) do
        if not isThreadActive(my_id) or not checkAntiPlayer(my_id) or checkPriorityDrop(my_id) or invCount(config.block_id) >= config.high_trigger then return end
        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == seed_id and walkTo(t.x, t.y) then
            for retry = 1, config.pnb_retry do
                punchTile(t.x, t.y, seed_id)
                if config.enable_anti_miss then
                    local ck = safeGetTile(t.x, t.y)
                    if ck and ck.fg == 0 then break else ActionSleep(80) end
                else break end
            end
            collectNearby()
        end
    end
end

-- TURBO DROP (Cepat tapi masuk server)
doTrashDrop = function(my_id, item_id, drop_x, drop_y)
    local count = invCount(item_id)
    if count <= 0 then return false end
    if not warpToWorld((config.trash_drop_world ~= "") and config.trash_drop_world or getCurrentFarmWorld(), config.trash_drop_door, my_id, true) then return false end

    local try_x = drop_x
    for i = 1, 10 do
        if not isThreadActive(my_id) or try_x < 0 then break end
        walkTo(try_x, drop_y)
        Sleep(250) 
        local before = invCount(item_id)
        sendPacket(2, "action|drop\nitemID|" .. item_id .. "\n")
        Sleep(250) 
        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. item_id .. "|\ncount|" .. count .. "\n")
        Sleep(300) 

        if invCount(item_id) < before then
            updateActionTime(); Log("TRASH DROP Berhasil: ID " .. item_id .. " (" .. count .. " pcs)")
            break
        else try_x = try_x - 1 end
    end
    warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
    return true
end

doDrop = function(my_id)
    local target = (config.drop_item_id > 0) and config.drop_item_id or (config.block_id > 0 and config.block_id or seed_id)
    local total = invCount(target)
    local amount = total - (target == seed_id and math.max(0, config.low_trigger) or 0)
    if amount <= 0 or (amount < config.min_drop_amt and total < config.high_trigger) then return false end

    if not warpToWorld((config.drop_world ~= "") and config.drop_world or getCurrentFarmWorld(), config.drop_door, my_id, true) then return false end

    local try_x = config.drop_x
    for i = 1, 10 do
        if not isThreadActive(my_id) or try_x < 0 then break end
        walkTo(try_x, config.drop_y)
        Sleep(250) 
        local before = invCount(target)
        sendPacket(2, "action|drop\nitemID|" .. target .. "\n")
        Sleep(250) 
        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. target .. "|\ncount|" .. math.min(200, amount) .. "\n")
        Sleep(300) 

        if invCount(target) < before then
            updateActionTime(); Log("DROP UTAMA Berhasil: ID " .. target .. " (" .. math.min(200, amount) .. " pcs)")
            if try_x ~= config.drop_x then config.drop_x = try_x; pref:set("drop_x", try_x); pref:save(); pcall(editValue, "drop_x", try_x) end
            break
        else try_x = try_x - 1 end
    end
    warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true)
    return true
end

local function getPnbTargets(cx, cy)
    if config.pnb_mode == 2 then return {{x=cx-1, y=cy-1}, {x=cx, y=cy-1}, {x=cx+1, y=cy-1}}
    elseif config.pnb_mode == 3 then return {{x=cx, y=cy+1}, {x=cx, y=cy+2}}
    else return {{x=cx-2, y=cy-1}, {x=cx-1, y=cy-1}, {x=cx, y=cy-1}, {x=cx+1, y=cy-1}, {x=cx+2, y=cy-1}} end
end

-- TURBO PNB (Nggak ada evaluasi bengong)
local function doPnb(my_id)
    Log("START PNB Kilat")
    walkTo(config.pnb_x, config.pnb_y)

    while isThreadActive(my_id) do
        if not checkAntiPlayer(my_id) or checkPriorityDrop(my_id) or invCount(config.block_id) <= config.low_trigger then return end

        local cx, cy = getPlayerTile()
        if not cx or cx ~= config.pnb_x or cy ~= config.pnb_y then
            walkTo(config.pnb_x, config.pnb_y)
            cx, cy = getPlayerTile()
            if not cx then return end
        end

        local targets = getPnbTargets(cx, cy)

        if config.enable_place then
            for _, t in ipairs(targets) do
                if invCount(config.block_id) <= 0 then break end
                local tile = safeGetTile(t.x, t.y)
                if tile and tile.fg == 0 then placeBlock(t.x, t.y, config.block_id, false) end
            end
        end

        if config.enable_break then
            while isThreadActive(my_id) do
                local broken_all = true
                for _, t in ipairs(targets) do
                    local cur = safeGetTile(t.x, t.y)
                    if cur and cur.fg ~= 0 then broken_all = false; punchTile(t.x, t.y, config.block_id) end
                end
                if broken_all then break end
            end
        end
        collectNearby()
    end
end

local function processCurrentWorld(my_id)
    while isThreadActive(my_id) do
        if not checkAntiPlayer(my_id) then return false end
        applyModFly()

        if checkPriorityDrop(my_id) then
            Sleep(200)
        else
            local r_tiles, p_tiles, c_blocks, c_seeds = getReadyHarvestTiles(), getPlantableTiles(), invCount(config.block_id), invCount(seed_id)
            if #r_tiles == 0 and (#p_tiles == 0 or c_seeds < config.low_trigger) and c_blocks <= config.low_trigger then return true end

            if #r_tiles > 0 and c_blocks < config.high_trigger then doHarvestLoop(my_id) end
            if invCount(config.block_id) >= config.high_trigger then doPnb(my_id) end
            if #getPlantableTiles() > 0 and invCount(seed_id) >= config.low_trigger then doPlant(my_id) end
            if invCount(config.block_id) > config.low_trigger then doPnb(my_id) end
            Sleep(100)
        end
    end
    return false
end

local function mainLoop(my_id)
    math.randomseed(os.time())
    seed_id = (config.seed_id and config.seed_id > 0) and config.seed_id or (config.block_id + 1)
    session_start_time, last_action_time = os.time(), os.time()
    updateActiveTrashList(); randomizeTimers()
    farm_world_list, current_farm_index = parseWorldList(config.farm_world), 1
    if #farm_world_list == 0 then local cw = safeGetWorldName(); if cw then table.insert(farm_world_list, cw) end end

    Log("ROTASI TURBO MULAI!")

    while isThreadActive(my_id) do
        checkWorkRestCycle(my_id)
        if not checkAntiPlayer(my_id) then break end
        local t_farm = getCurrentFarmWorld()
        if warpToWorld(t_farm, config.farm_door, my_id, true) then
            if processCurrentWorld(my_id) then nextFarmWorld() end
        else nextFarmWorld() end
        Sleep(200)
    end
end

-- =========================================================
-- UI "FAMILY USER" MENGGUNAKAN ADDINTOMODULE
-- =========================================================
local ui = UserInterface.new("Auto Rotasi", "Verified")[cite: 5]

ui:addLabelApp("AUTO ROTASI 24/7 (TURBO)", "Verified")[cite: 5]
ui:addDivider()[cite: 5]

local menu_utama = ui:addDialog("1. Pengaturan Utama", "Set Block, Seed, & World", {})[cite: 5]
ui:addChildInputInt(menu_utama.menu, "Block ID", config.block_id, "ID", "Contoh: 340", "Verified", "block_id")[cite: 5]
ui:addChildInputInt(menu_utama.menu, "Seed ID", config.seed_id, "ID", "0 = Otomatis", "Verified", "seed_id")[cite: 5]
ui:addChildInputString(menu_utama.menu, "World Farm", config.farm_world, "World", "FARM1,FARM2", "World", "farm_world")[cite: 5]
ui:addChildInputString(menu_utama.menu, "Door Farm", config.farm_door, "ID", "Pintu Masuk", "World", "farm_door")[cite: 5]

local menu_storage = ui:addDialog("2. Target & Storage", "Kapan bot drop item?", {})[cite: 5]
ui:addChildInputInt(menu_storage.menu, "Batas Penuh (High)", config.high_trigger, "Pcs", "Drop tas > ini", "Verified", "high_trigger")[cite: 5]
ui:addChildInputInt(menu_storage.menu, "Batas Habis (Low)", config.low_trigger, "Pcs", "Stop tas < ini", "Verified", "low_trigger")[cite: 5]
ui:addChildInputString(menu_storage.menu, "World Storage", config.drop_world, "World", "Kumpul hasil", "World", "drop_world")[cite: 5]
ui:addChildInputString(menu_storage.menu, "Door Storage", config.drop_door, "ID", "Pintu drop", "World", "drop_door")[cite: 5]
ui:addChildButton(menu_storage.menu, "Set Posisi Drop Saat Ini", "btn_drop_set")[cite: 5]

local menu_pnb = ui:addDialog("3. Pengaturan PnB & Speed", "Titik & Waktu Delay", {})[cite: 5]
ui:addChildInputInt(menu_pnb.menu, "PnB Pos X", config.pnb_x, "X", "Koordinat X", "Verified", "pnb_x")[cite: 5]
ui:addChildInputInt(menu_pnb.menu, "PnB Pos Y", config.pnb_y, "Y", "Koordinat Y", "Verified", "pnb_y")[cite: 5]
ui:addChildButton(menu_pnb.menu, "Set Posisi PnB Saat Ini", "btn_pnb_set")[cite: 5]
ui:addChildInputInt(menu_pnb.menu, "Delay Break (ms)", config.delay_punch, "ms", "Default: 150", "Verified", "delay_punch")[cite: 5]
ui:addChildInputInt(menu_pnb.menu, "Delay Place (ms)", config.delay_place, "ms", "Default: 80", "Verified", "delay_place")[cite: 5]
ui:addChildInputInt(menu_pnb.menu, "Delay Plant/Jalan (ms)", config.delay_plant, "ms", "Default: 100", "Verified", "delay_plant")[cite: 5]

local menu_aman = ui:addDialog("4. Keamanan & Jeda", "Fitur Anti-Ban", {})[cite: 5]
ui:addChildToggle(menu_aman.menu, "Smart Delay (Aman)", config.enable_smart_delay, "enable_smart_delay")[cite: 5]
ui:addChildToggle(menu_aman.menu, "Anti Player / Mod", config.enable_anti_player, "enable_anti_player")[cite: 5]
ui:addChildToggle(menu_aman.menu, "Aktifkan Mod Fly", config.enable_fly, "enable_fly")[cite: 5]

local menu_trash = ui:addDialog("5. Buang Sampah", "Setting buang sampah", {})[cite: 5]
ui:addChildToggle(menu_trash.menu, "Aktifkan Buang Sampah", config.enable_trash_drop, "enable_trash_drop")[cite: 5]
ui:addChildInputString(menu_trash.menu, "World Sampah", config.trash_drop_world, "World", "World buang", "World", "trash_drop_world")[cite: 5]

ui:addDivider()[cite: 5]
ui:addButton("SIMPAN PENGATURAN", "btn_apply")[cite: 5]
ui:addDivider()[cite: 5]
ui:addToggleButton("▶ MULAI / BERHENTI ⏹", false, "btn_start")[cite: 5]

local temp = {
    block_id = tostring(config.block_id), seed_id = tostring(config.seed_id),
    high_trigger = tostring(config.high_trigger), low_trigger = tostring(config.low_trigger),
    farm_world = config.farm_world, farm_door = config.farm_door,
    drop_world = config.drop_world, drop_door = config.drop_door,
    pnb_x = tostring(config.pnb_x), pnb_y = tostring(config.pnb_y),
    enable_trash_drop = config.enable_trash_drop, trash_drop_world = config.trash_drop_world,
    enable_smart_delay = config.enable_smart_delay, enable_anti_player = config.enable_anti_player,
    enable_fly = config.enable_fly, delay_punch = tostring(config.delay_punch), delay_place = tostring(config.delay_place),
    delay_plant = tostring(config.delay_plant)
}

function OnDraw(d)
    removeHook("onDraw")
    runCoroutine(function()
        Sleep(2000)
        addIntoModule(ui:generateJSON(), "Farm")[cite: 4, 5]
    end)
end

function OnValue(type, name, value)
    if name == "block_id" then temp.block_id = tostring(value)
    elseif name == "seed_id" then temp.seed_id = tostring(value)
    elseif name == "farm_world" then temp.farm_world = value
    elseif name == "farm_door" then temp.farm_door = value
    elseif name == "high_trigger" then temp.high_trigger = tostring(value)
    elseif name == "low_trigger" then temp.low_trigger = tostring(value)
    elseif name == "drop_world" then temp.drop_world = value
    elseif name == "drop_door" then temp.drop_door = value
    elseif name == "pnb_x" then temp.pnb_x = tostring(value)
    elseif name == "pnb_y" then temp.pnb_y = tostring(value)
    elseif name == "enable_trash_drop" then temp.enable_trash_drop = value
    elseif name == "trash_drop_world" then temp.trash_drop_world = value
    elseif name == "enable_smart_delay" then temp.enable_smart_delay = value
    elseif name == "enable_anti_player" then temp.enable_anti_player = value
    elseif name == "enable_fly" then temp.enable_fly = value
    elseif name == "delay_punch" then temp.delay_punch = tostring(value)
    elseif name == "delay_place" then temp.delay_place = tostring(value)
    elseif name == "delay_plant" then temp.delay_plant = tostring(value)

    elseif name == "btn_pnb_set" then
        local p = getPlayer()
        if p then local cx, cy = math.floor(p.posX / 32), math.floor(p.posY / 32); temp.pnb_x, temp.pnb_y = tostring(cx), tostring(cy); config.pnb_x, config.pnb_y = cx, cy; editValue("pnb_x", cx); editValue("pnb_y", cy); growtopia.notify("PnB set: X="..cx.." Y="..cy) end
    elseif name == "btn_drop_set" then
        local p = getPlayer()
        if p then local cx, cy = math.floor(p.posX / 32), math.floor(p.posY / 32); temp.drop_x, temp.drop_y = tostring(cx), tostring(cy); config.drop_x, config.drop_y = cx, cy; editValue("drop_x", cx); editValue("drop_y", cy); pref:set("drop_x", cx); pref:set("drop_y", cy); growtopia.notify("Drop set: X="..cx.." Y="..cy) end

    elseif name == "btn_apply" then
        config.block_id, config.seed_id = tonumber(temp.block_id) or 0, tonumber(temp.seed_id) or 0
        config.high_trigger, config.low_trigger = tonumber(temp.high_trigger) or 180, tonumber(temp.low_trigger) or 10
        config.farm_world, config.farm_door = temp.farm_world, temp.farm_door
        config.drop_world, config.drop_door = temp.drop_world, temp.drop_door
        config.pnb_x, config.pnb_y = tonumber(temp.pnb_x) or 0, tonumber(temp.pnb_y) or 0
        config.enable_trash_drop, config.trash_drop_world = temp.enable_trash_drop, temp.trash_drop_world
        config.enable_smart_delay, config.enable_anti_player, config.enable_fly = temp.enable_smart_delay, temp.enable_anti_player, temp.enable_fly
        config.delay_punch, config.delay_place = tonumber(temp.delay_punch) or 150, tonumber(temp.delay_place) or 80
        config.delay_plant = tonumber(temp.delay_plant) or 100

        for k, v in pairs(config) do if type(v) ~= "table" then pref:set(k, v) end end
        pref:save(); updateActiveTrashList(); growtopia.notify("Config Saved!")[cite: 8]

    elseif name == "btn_start" then
        if value == true then
            if config.block_id == 0 or (config.pnb_x == 0 and config.pnb_y == 0) then
                growtopia.notify("Isi Block ID dan PnB X/Y dulu!")
                editValue("btn_start", false); return
            end
            thread_instance = thread_instance + 1
            running, reconnecting = true, false
            sendVariant({v1 = "OnTextOverlay", v2 = "AUTO ROTASI TURBO"})
            runThread(function() mainLoop(thread_instance) end)
        else
            thread_instance = thread_instance + 1
            running = false
            Log("Rotasi Stop.")
        end
    end
end

addHook(OnDraw, "onDraw"); addHook(OnValue, "onValue"); applyHook()

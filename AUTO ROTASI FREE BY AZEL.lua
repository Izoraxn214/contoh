local Preferences = require("preferences")
local pref = Preferences:new("rotasi_lolistore_config.json")

local config = {
    block_id           = pref:get("block_id",           0),
    pnb_x              = pref:get("pnb_x",              0),
    pnb_y              = pref:get("pnb_y",              0),
    high_trigger       = pref:get("high_trigger",        180),
    low_trigger        = pref:get("low_trigger",         10),
    farm_world         = pref:get("farm_world",         ""),
    farm_door          = pref:get("farm_door",          ""),
    drop_world         = pref:get("drop_world",         ""),
    drop_door          = pref:get("drop_door",          ""),
    drop_x             = pref:get("drop_x",             0),
    drop_y             = pref:get("drop_y",             0),
    marker_id          = pref:get("marker_id",           1422),
    webhook_url        = pref:get("webhook_url",        ""),
    enable_anti_player = pref:get("enable_anti_player", true),
    work_min           = pref:get("work_min",           45),
    rest_min           = pref:get("rest_min",           10),
    enable_jitter      = pref:get("enable_jitter",      true),
    show_punch         = pref:get("show_punch",         true),
    pnb_timeout        = 6000,
    pnb_retry          = 4,
}

local seed_id            = 0
local running            = false
local reconnecting       = false
local action_count       = 0
local thread_instance    = 0
local session_start_time = 0

local function Log(msg)
    LogToConsole("`5[LoliStore] `0" .. tostring(msg))
end

local function sendWebhook(msg)
    if not config.webhook_url or config.webhook_url == "" then return end
    pcall(function()
        local payload = '{"content": "' .. tostring(msg) .. '"}'
        fetch(config.webhook_url, {
            method  = "POST",
            headers = { ["Content-Type"] = "application/json" },
            body    = payload
        })
    end)
end

local function isThreadActive(my_id)
    return running and not reconnecting and (thread_instance == my_id)
end

local function rSleep(base_min, base_max)
    local base = math.random(base_min, base_max)
    action_count = action_count + 1
    if action_count % math.random(20, 35) == 0 then
        base = base + math.random(800, 2500)
    end
    Sleep(base)
end

local function HumanSleep(ms)
    local jitter = math.random(50, 400)
    if config.enable_jitter then
        jitter = jitter + math.random(100, 500)
    end
    action_count = action_count + 1
    if action_count % math.random(15, 25) == 0 then
        jitter = jitter + math.random(1000, 3000)
    end
    Sleep(ms + jitter)
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

local function checkAntiPlayer(my_id)
    if not config.enable_anti_player then return true end
    local players = safeGetPlayerList()
    local local_p = getPlayer()
    if not players or not local_p or not local_p.netID then return true end

    for _, p in pairs(players) do
        if p and p.netID and p.netID ~= local_p.netID then
            Log("`4[DANGER] Player lain terdeteksi! Auto exit...")
            sendWebhook("⚠️ **ALERT:** Player/Mod terdeteksi di world (**" .. tostring(p.name or "Unknown") .. "**)! Auto Exit ke main menu...")
            growtopia.warpTo("EXIT")
            running = false
            return false
        end
    end
    return true
end

local function checkWorkRestCycle(my_id)
    if config.work_min <= 0 or config.rest_min <= 0 then return end
    local elapsed_work = os.time() - session_start_time
    if elapsed_work >= (config.work_min * 60) then
        Log("Waktunya istirahat sejenak selama " .. config.rest_min .. " menit...")
        sendWebhook("☕ **REST SESSION:** Bot istirahat sejenak selama " .. config.rest_min .. " menit untuk menjaga pola main alami.")
        
        local rest_elapsed = 0
        local total_rest_sec = config.rest_min * 60
        while rest_elapsed < total_rest_sec do
            if not running or (thread_instance ~= my_id) then return end
            Sleep(2000)
            if not reconnecting then
                rest_elapsed = rest_elapsed + 2
            end
        end
        
        session_start_time = os.time()
        Log("Istirahat selesai, rotasi dilanjutkan!")
        sendWebhook("🔄 **RESUME:** Bot selesai istirahat dan kembali bekerja.")
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

local function safeGetWorldName()
    local ok, w = pcall(GetWorldName)
    if ok and w and w ~= "" and string.upper(w) ~= "EXIT" then return w end
    return nil
end

local function waitTileFg(tx, ty, expected_fg, timeout_ms, my_id)
    local elapsed = 0
    while elapsed < timeout_ms do
        if not isThreadActive(my_id) then return false end
        local tile = safeGetTile(tx, ty)
        if tile and tile.fg == expected_fg then return true end
        Sleep(150)
        elapsed = elapsed + 150
    end
    return false
end

local function punchTile(tx, ty)
    local p = getPlayer()
    if not p then return end
    sendPacketRaw(not config.show_punch, {
        type  = 3,
        value = 18,
        x     = p.posX,
        y     = p.posY,
        px    = tx,
        py    = ty
    })
    HumanSleep(math.random(150, 280))
end

local function placeBlock(tx, ty, item_id)
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
    HumanSleep(math.random(120, 220))
end

local function walkTo(tx, ty)
    FindPath(tx, ty)
    HumanSleep(math.random(400, 700))
    local cx, cy = getPlayerTile()
    if cx and cy then
        return (math.abs(cx - tx) <= 2 and math.abs(cy - ty) <= 2)
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
                Sleep(math.random(30, 60))
            end
        end
    end
end

local function hasDropOnTile(tx, ty)
    local objs = safeGetObjects()
    if not objs then return false end
    for _, obj in pairs(objs) do
        if obj and obj.posX and obj.posY then
            local ox = math.floor((obj.posX + 16) / 32)
            local oy = math.floor((obj.posY + 16) / 32)
            if math.abs(ox - tx) <= 1 and oy == ty then return true end
        end
    end
    return false
end

local function waitTileClear(tx, ty, timeout_ms, my_id)
    local elapsed = 0
    local step = math.random(200, 300)
    while elapsed < timeout_ms do
        if not isThreadActive(my_id) then return true end
        if not hasDropOnTile(tx, ty) then return true end
        collectNearby()
        Sleep(step)
        elapsed = elapsed + step
        step = math.random(200, 300)
    end
    return false
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
    if invCount(seed_id) < config.low_trigger then return end

    Log("START PLANT")
    local plant_tiles = getPlantableTiles()
    if #plant_tiles == 0 then return end

    for _, t in ipairs(plant_tiles) do
        if not isThreadActive(my_id) or not checkAntiPlayer(my_id) then return end
        if invCount(seed_id) <= config.low_trigger then break end

        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == 0 then
            if walkTo(t.x, t.y) then
                placeBlock(t.x, t.y, seed_id)
            end
        end
    end
end

local function doHarvestLoop(my_id)
    Log("START HARVEST")

    while isThreadActive(my_id) do
        if not checkAntiPlayer(my_id) then return end
        if invCount(config.block_id) >= config.high_trigger then break end

        local ready_tiles = getReadyHarvestTiles()
        if #ready_tiles == 0 then break end

        for _, t in ipairs(ready_tiles) do
            if not isThreadActive(my_id) or not checkAntiPlayer(my_id) then return end
            if invCount(config.block_id) >= config.high_trigger then break end

            local tile = safeGetTile(t.x, t.y)
            if tile and tile.fg == seed_id and tile.readyharvest == true then
                local reached = walkTo(t.x, t.y)
                if reached then
                    local retry = 0
                    while retry < config.pnb_retry do
                        if not isThreadActive(my_id) then return end
                        punchTile(t.x, t.y)
                        if waitTileFg(t.x, t.y, 0, config.pnb_timeout, my_id) then
                            local before_block = invCount(config.block_id)
                            local before_seed  = invCount(seed_id)
                            local wait_ms = 0
                            while wait_ms < 3000 do
                                if not isThreadActive(my_id) then return end
                                collectNearby()
                                if invCount(config.block_id) > before_block or invCount(seed_id) > before_seed then break end
                                Sleep(math.random(80, 150))
                                wait_ms = wait_ms + 100
                            end
                            break
                        else
                            retry = retry + 1
                            rSleep(100, 200)
                        end
                    end
                end
            end
        end

        Sleep(math.random(80, 150))
    end
end

local function doDrop(my_id)
    local amount = invCount(seed_id)
    if amount <= 0 then return end

    if amount > 200 then
        amount = 200
    end

    local current_w = safeGetWorldName()
    local target_drop_world = (config.drop_world and config.drop_world ~= "") and config.drop_world or current_w
    local is_different_world = (target_drop_world ~= "") and (string.upper(target_drop_world) ~= string.upper(current_w or ""))

    if is_different_world then
        Log("Warp ke world drop: " .. target_drop_world)
        local warp_target = target_drop_world
        if config.drop_door and config.drop_door ~= "" then
            warp_target = warp_target .. "|" .. config.drop_door
        end
        
        growtopia.warpTo(warp_target)
        
        local elapsed = 0
        while elapsed < 15000 do
            if not isThreadActive(my_id) then return end
            local w = safeGetWorldName()
            if w and string.upper(w) == string.upper(target_drop_world) then break end
            Sleep(1000)
            elapsed = elapsed + 1000
        end
        rSleep(1500, 2500)
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
        rSleep(400, 700)

        local before_count = invCount(seed_id)
        sendPacket(2, "action|drop\nitemID|" .. seed_id .. "\n")
        rSleep(300, 500)
        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. seed_id .. "|\ncount|" .. amount .. "\n")
        rSleep(400, 700)

        if invCount(seed_id) < before_count then
            dropped = true
            Log("DROP berhasil di X=" .. try_x .. ", Y=" .. try_y .. " (" .. amount .. " seed)")
            sendWebhook("📦 **DROP SUCCESS:** Berhasil melempar " .. amount .. " seed di world **" .. tostring(target_drop_world) .. "** (Posisi X=" .. try_x .. ", Y=" .. try_y .. ").")
            
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

    if is_different_world then
        Log("Warp balik ke world farm: " .. config.farm_world)
        local back_target = config.farm_world
        if config.farm_door and config.farm_door ~= "" then
            back_target = back_target .. "|" .. config.farm_door
        end

        growtopia.warpTo(back_target)

        local elapsed = 0
        while elapsed < 15000 do
            if not isThreadActive(my_id) then return end
            local w = safeGetWorldName()
            if w and string.upper(w) == string.upper(config.farm_world) then break end
            Sleep(1000)
            elapsed = elapsed + 1000
        end
        rSleep(1500, 2500)
    end
end

local function doPTHT(my_id)
    doPlant(my_id)
    if not isThreadActive(my_id) then return end

    if invCount(seed_id) >= config.high_trigger then
        doDrop(my_id)
        if not isThreadActive(my_id) then return end
    end

    if invCount(config.block_id) <= config.low_trigger or invCount(seed_id) <= config.low_trigger then
        doHarvestLoop(my_id)
    end
end

local function getPnbTargets(cx, cy)
    local target_y = cy - 1
    return {
        {x = cx - 2, y = target_y},
        {x = cx - 1, y = target_y},
        {x = cx,     y = target_y},
        {x = cx + 1, y = target_y},
        {x = cx + 2, y = target_y},
    }
end

local function doPnb(my_id)
    Log("START PNB (5-Tile Horizontal)")
    walkTo(config.pnb_x, config.pnb_y)
    rSleep(500, 800)

    while isThreadActive(my_id) do
        if not checkAntiPlayer(my_id) then return end
        if invCount(config.block_id) <= config.low_trigger then
            return "low_block"
        end

        local cx, cy = getPlayerTile()
        if not cx or cx ~= config.pnb_x or cy ~= config.pnb_y then
            walkTo(config.pnb_x, config.pnb_y)
            rSleep(500, 800)
            cx, cy = getPlayerTile()
            if not cx then return end
        end

        local targets = getPnbTargets(cx, cy)

        for _, t in ipairs(targets) do
            if not isThreadActive(my_id) then return end
            if invCount(config.block_id) <= 0 then break end
            local tile = safeGetTile(t.x, t.y)
            if tile and tile.fg == 0 then
                placeBlock(t.x, t.y, config.block_id)
            end
        end

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

        collectNearby()
    end
end

local function reconnectMonitor(my_id)
    while running and (thread_instance == my_id) do
        Sleep(3000)
        local p = getPlayer()
        local w = safeGetWorldName()
        if not p or not w then
            reconnecting = true
            sendWebhook("⚠️ **RECONNECTING:** Bot terputus dari server. Mencoba kembali ke world...")
            local back_target = config.farm_world
            if config.farm_door and config.farm_door ~= "" then
                back_target = config.farm_world .. "|" .. config.farm_door
            end
            while running and (thread_instance == my_id) do
                Sleep(math.random(1800, 2500))
                if back_target and back_target ~= "" then
                    growtopia.warpTo(back_target)
                end
                
                local elapsed = 0
                local ok = false
                while elapsed < 15000 do
                    local current_w = safeGetWorldName()
                    if current_w and config.farm_world ~= "" and string.upper(current_w) == string.upper(config.farm_world) then
                        ok = true
                        break
                    end
                    Sleep(1000)
                    elapsed = elapsed + 1000
                end

                if ok then
                    Sleep(math.random(1800, 2500))
                    sendWebhook("✅ **RECONNECTED:** Berhasil masuk kembali ke world **" .. tostring(config.farm_world) .. "**.")
                    break
                end
            end
            reconnecting = false
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
    session_start_time = os.time()

    -- PERBAIKAN: Auto-warp ke Farm World di awal Start jika player berada di world lain
    local current_w = safeGetWorldName()
    if config.farm_world and config.farm_world ~= "" then
        if not current_w or string.upper(current_w) ~= string.upper(config.farm_world) then
            Log("Mencoba warp awal ke Farm World: " .. config.farm_world)
            local warp_target = config.farm_world
            if config.farm_door and config.farm_door ~= "" then
                warp_target = warp_target .. "|" .. config.farm_door
            end
            
            growtopia.warpTo(warp_target)
            
            local elapsed = 0
            while elapsed < 15000 do
                if not isThreadActive(my_id) then return end
                local w = safeGetWorldName()
                if w and string.upper(w) == string.upper(config.farm_world) then break end
                Sleep(1000)
                elapsed = elapsed + 1000
            end
            rSleep(1500, 2500)
        end
    else
        config.farm_world = current_w or ""
    end

    Log("ROTASI MULAI!")
    sendWebhook("🚀 **BOT STARTED:** Auto Rotasi diaktifkan di world **" .. tostring(config.farm_world) .. "**")

    runThread(function() reconnectMonitor(my_id) end)

    if invCount(config.block_id) >= config.high_trigger then
        local pnb_result = doPnb(my_id)
        if not isThreadActive(my_id) then return end
        if pnb_result == "low_block" then
            doPTHT(my_id)
            if not isThreadActive(my_id) then return end
        end
    end

    while isThreadActive(my_id) do
        checkWorkRestCycle(my_id)
        if not checkAntiPlayer(my_id) then break end

        local block_count = invCount(config.block_id)

        if block_count >= config.high_trigger then
            local pnb_result = doPnb(my_id)
            if not isThreadActive(my_id) then break end

            if pnb_result == "low_block" then
                doPTHT(my_id)
                if not isThreadActive(my_id) then break end
            else
                if invCount(seed_id) >= config.high_trigger then
                    doDrop(my_id)
                    if not isThreadActive(my_id) then break end
                end
            end
        else
            doPTHT(my_id)
            if not isThreadActive(my_id) then break end
        end

        rSleep(200, 400)
    end
end

local ui = UserInterface.new("Auto Rotasi", "Ability")

ui:addLabelApp("AUTO ROTASI BY LOLISTORE", "Ability")
ui:addDivider()

local dialog_main = ui:addDialog("Main Config", "Setting utama rotasi", {})
ui:addChildInputString(dialog_main.menu, "Farm World",    config.farm_world,   "World", "Nama world farm utama",             "World",    "farm_world")
ui:addChildInputString(dialog_main.menu, "Farm Door",     config.farm_door,    "ID",    "ID door world farm",               "World",    "farm_door")
ui:addChildInputInt(dialog_main.menu,    "Block ID",      config.block_id,     "ID",    "ID block (bukan seed)",             "Verified", "block_id")
ui:addChildInputInt(dialog_main.menu,    "High Trigger",  config.high_trigger, "amt",   "seed>=ini->Drop (def:180)",         "Verified", "high_trigger")
ui:addChildInputInt(dialog_main.menu,    "Low Trigger",   config.low_trigger,  "amt",   "block/seed<=ini->stop (def:10)",    "Verified", "low_trigger")

ui:addDivider()

local dialog_pnb = ui:addDialog("PnB Position", "Berdiri di posisi PnB dulu sebelum set", {})
ui:addChildInputInt(dialog_pnb.menu, "PnB X", config.pnb_x, "X", "koordinat X", "Verified", "pnb_x")
ui:addChildInputInt(dialog_pnb.menu, "PnB Y", config.pnb_y, "Y", "koordinat Y", "Verified", "pnb_y")
ui:addChildButton(dialog_pnb.menu, "Set dari posisi sekarang", "btn_pnb_set")

ui:addDivider()

local dialog_drop = ui:addDialog("Drop Config", "Posisi & World drop seed", {})
ui:addChildInputString(dialog_drop.menu, "Drop World", config.drop_world, "World", "World tempat drop (kosongkan jika sama)", "World", "drop_world")
ui:addChildInputString(dialog_drop.menu, "Drop Door",  config.drop_door,  "ID",    "ID door world drop",                      "World", "drop_door")
ui:addChildInputInt(dialog_drop.menu,    "Drop X",     config.drop_x,     "X",     "koordinat X drop",                        "Verified", "drop_x")
ui:addChildInputInt(dialog_drop.menu,    "Drop Y",     config.drop_y,     "Y",     "koordinat Y drop",                        "Verified", "drop_y")
ui:addChildButton(dialog_drop.menu, "Set dari posisi sekarang", "btn_drop_set")

ui:addDivider()

local dialog_sec = ui:addDialog("Security & Anti-Ban", "Proteksi akun & notifikasi", {})
ui:addChildInputString(dialog_sec.menu, "Webhook Discord",      config.webhook_url,        "URL", "https://discord.com/api/webhooks/...", "Verified", "webhook_url")
ui:addChildToggle(dialog_sec.menu,      "Anti Player/Mod",      config.enable_anti_player, "enable_anti_player")
ui:addChildToggle(dialog_sec.menu,      "Show Punch (Visual)",  config.show_punch,         "show_punch")
ui:addChildInputInt(dialog_sec.menu,    "Jam Kerja (Menit)",    config.work_min,           "min", "Durasi kerja sebelum istirahat",        "Verified", "work_min")
ui:addChildInputInt(dialog_sec.menu,    "Jam Istirahat (Menit)", config.rest_min,          "min", "Durasi istirahat/AFK",                "Verified", "rest_min")
ui:addChildToggle(dialog_sec.menu,      "Human Micro-Jitter",   config.enable_jitter,      "enable_jitter")

ui:addDivider()
ui:addButton("Apply Config", "btn_apply")
ui:addDivider()
ui:addToggleButton("Start / Stop", false, "btn_start")

local temp = {
    block_id           = tostring(config.block_id),
    high_trigger       = tostring(config.high_trigger),
    low_trigger        = tostring(config.low_trigger),
    farm_world         = config.farm_world,
    farm_door          = config.farm_door,
    drop_world         = config.drop_world,
    drop_door          = config.drop_door,
    pnb_x              = tostring(config.pnb_x),
    pnb_y              = tostring(config.pnb_y),
    drop_x             = tostring(config.drop_x),
    drop_y             = tostring(config.drop_y),
    webhook_url        = config.webhook_url,
    enable_anti_player = config.enable_anti_player,
    show_punch         = config.show_punch,
    work_min           = tostring(config.work_min),
    rest_min           = tostring(config.rest_min),
    enable_jitter      = config.enable_jitter,
}

function OnDraw(d)
    removeHook("onDraw")
    runCoroutine(function()
        Sleep(2000)
        addIntoModule(ui:generateJSON(), "Farm")
    end)
end

function OnValue(type, name, value)
    if     name == "block_id"           then temp.block_id           = tostring(value)
    elseif name == "high_trigger"       then temp.high_trigger       = tostring(value)
    elseif name == "low_trigger"        then temp.low_trigger        = tostring(value)
    elseif name == "farm_world"         then temp.farm_world         = value
    elseif name == "farm_door"          then temp.farm_door          = value
    elseif name == "drop_world"         then temp.drop_world         = value
    elseif name == "drop_door"          then temp.drop_door          = value
    elseif name == "pnb_x"              then temp.pnb_x              = tostring(value)
    elseif name == "pnb_y"              then temp.pnb_y              = tostring(value)
    elseif name == "drop_x"             then temp.drop_x             = tostring(value)
    elseif name == "drop_y"             then temp.drop_y             = tostring(value)
    elseif name == "webhook_url"        then temp.webhook_url        = value
    elseif name == "enable_anti_player" then temp.enable_anti_player = value
    elseif name == "show_punch"         then temp.show_punch         = value
    elseif name == "work_min"           then temp.work_min           = tostring(value)
    elseif name == "rest_min"           then temp.rest_min           = tostring(value)
    elseif name == "enable_jitter"      then temp.enable_jitter      = value

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

    elseif name == "btn_apply" then
        config.block_id           = tonumber(temp.block_id)     or config.block_id
        config.high_trigger       = tonumber(temp.high_trigger) or config.high_trigger
        config.low_trigger        = tonumber(temp.low_trigger)  or config.low_trigger
        config.farm_world         = temp.farm_world
        config.farm_door          = temp.farm_door
        config.drop_world         = temp.drop_world
        config.drop_door          = temp.drop_door
        config.pnb_x              = tonumber(temp.pnb_x)        or config.pnb_x
        config.pnb_y              = tonumber(temp.pnb_y)        or config.pnb_y
        config.drop_x             = tonumber(temp.drop_x)       or config.drop_x
        config.drop_y             = tonumber(temp.drop_y)       or config.drop_y
        config.webhook_url        = temp.webhook_url
        config.enable_anti_player = temp.enable_anti_player
        config.show_punch         = temp.show_punch
        config.work_min           = tonumber(temp.work_min)     or config.work_min
        config.rest_min           = tonumber(temp.rest_min)     or config.rest_min
        config.enable_jitter      = temp.enable_jitter

        seed_id = config.block_id + 1

        pref:set("block_id",           config.block_id)
        pref:set("high_trigger",       config.high_trigger)
        pref:set("low_trigger",        config.low_trigger)
        pref:set("farm_world",         config.farm_world)
        pref:set("farm_door",          config.farm_door)
        pref:set("drop_world",         config.drop_world)
        pref:set("drop_door",          config.drop_door)
        pref:set("pnb_x",              config.pnb_x)
        pref:set("pnb_y",              config.pnb_y)
        pref:set("drop_x",             config.drop_x)
        pref:set("drop_y",             config.drop_y)
        pref:set("webhook_url",        config.webhook_url)
        pref:set("enable_anti_player", config.enable_anti_player)
        pref:set("show_punch",         config.show_punch)
        pref:set("work_min",           config.work_min)
        pref:set("rest_min",           config.rest_min)
        pref:set("enable_jitter",      config.enable_jitter)
        pref:save()

        growtopia.notify("Config & Security tersimpan!")

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
            if config.drop_x == 0 and config.drop_y == 0 then
                growtopia.notify("Set posisi Drop dulu!")
                editValue("btn_start", false)
                return
            end

            thread_instance = thread_instance + 1
            local current_id = thread_instance

            running      = false
            Sleep(300)
            running      = true
            reconnecting = false
            action_count = 0

            sendVariant({v1 = "OnTextOverlay", v2 = "AUTO ROTASI BY LOLISTORE"})
            Log("AUTO ROTASI BY LOLISTORE — Started!")

            runThread(function()
                mainLoop(current_id)
            end)
        else
            thread_instance = thread_instance + 1
            running = false
            Log("Rotasi dihentikan.")
            sendWebhook("🛑 **BOT STOPPED:** Auto Rotasi dihentikan secara manual.")
        end
    end
end

addHook(onVariant, "onVariant")
addHook(OnDraw, "onDraw")
addHook(OnValue, "onValue")
applyHook()

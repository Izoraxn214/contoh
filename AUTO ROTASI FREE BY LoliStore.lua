-- AUTO ROTASI - TANPA SECURITY
-- Anti player/mod, siklus kerja-istirahat, dan alert console sudah dihapus.
-- Delay dari GUI dipakai apa adanya & langsung live tanpa Apply.
-- Trash: 12 item dengan ID tetap (nggak perlu diketik), tiap item punya toggle + jumlah,
-- semua dalam 1 dialog, 1 posisi drop untuk semuanya.
-- Auto Collect: thread terpisah ambil drop di sekitar karakter tiap 250ms (radius bisa diatur),
-- otomatis pause saat drop / warp / di luar world farm.
-- ID trash dicari otomatis dari NAMA item lewat API game saat Start (ID bawaan cuma cadangan).
-- PnB guard per tile: tile dianggap nyangkut kalau 30x dipukul nggak pecah (bukan 8 putaran tanpa pecah).
-- Drop sekali jalan: semua trash yang penuh (+ seed kalau world-nya sama) di-drop dalam 1 kunjungan.
-- Drop: coba beberapa cara berurutan (dicek dari jumlah item), cara yang berhasil diingat.
-- Trigger dipisah: Seed Drop Trigger (drop seed) vs High Trigger (block -> PnB). Minimal Drop Amt dihapus.
-- Warp ngecek WORLD + DOOR: world sama tapi door beda tetap warp lewat door yang benar.
-- PnB: penghitung pukulan di-reset tiap tile kosong/di-place (update server bisa telat),
-- tile nyangkut dicoba lagi tiap 5 siklus.
-- Tahan penyakit (malady): batas pukulan PnB menyesuaikan pukulan rata-rata (Torn Punching Muscle),
-- walkTo menunggu selama karakter masih bergerak (Chicken Feet), dan penyakit terdeteksi dicatat di log.
-- Webhook Discord (lewat relay Google Apps Script): laporan rutin + event penting, dikirim dari
-- thread terpisah pakai antrean, jadi nggak pernah nahan farming.
-- Reconnect sabar: selama game lagi login ulang sendiri, bot NGGAK warp. Jeda naik bertahap (maks 5 mnt),
-- webhook ngabarin kalau nggak bisa nyambung > 5 menit.
-- v24: auto-restart kalau error, nunggu kalau semua world kosong (nggak warp terus), Auto Collect maks 2 tile,
-- Log Ringkas, scan lebih jarang saat nganggur, statistik sesi, Anti Miss nunggu update server.
-- v25: Auto Collect nggak spam: tiap item maks 2x dicoba, item yang nggak bisa diambil (tas penuh / ditolak)
-- dilewati 60 dtk, total maks 6 paket ambil per detik.
-- v26: aksi yang gagal terus nggak diulang tanpa batas: place PnB gagal -> PnB dijeda 2 mnt,
-- tile panen/tanam yang gagal berulang dilewati 10 mnt.
-- v27 (lebih ringan di HP): GC bertahap (bukan bersih-bersih penuh yang bikin patah-patah),
-- nama world di-cache saat scan, Auto Collect melambat kalau sepi, PnB nggak baca tile dobel.
-- v28: cek hasil place di PnB cuma NUNGGU kalau Anti Miss nyala. Anti Miss mati = nol jeda tambahan.
-- Anti-freeze: tiap putaran loop yang tidak menghasilkan aksi nyata WAJIB jeda (makin lama makin panjang).
-- Drop prioritas: kerjaan yang terpotong drop/trash disimpan (resume) lalu dilanjutkan setelah drop.
-- Optimasi: priority check di-throttle (1 dtk), 1x scan world per iterasi,
-- panen + tanam ulang di tile yang sama, urutan tile pola ular (snake).
-- ===== KOMPATIBILITAS GROWLAUNCHER v7 (sesuai dokumentasi resmi) =====
-- Docs: sleep() huruf kecil, CSleep() untuk coroutine, getCurrentWorldName().
-- Nama lama tetap didukung kalau versi lu masih punya.
local Sleep        = sleep or Sleep
local CSleepFn     = CSleep or Sleep
local GetWorldName = getCurrentWorldName or GetWorldName
setMinimum = setMinimum or function() end

local Preferences = require("preferences")
local pref = Preferences:new("rotasi_lolistore_config.json")

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
    block_id             = pref:get("block_id",             0),
    seed_id              = pref:get("seed_id",              0),

    enable_verify_punch  = pref:get("enable_verify_punch",  true),
    enable_break         = pref:get("enable_break",         true),
    enable_place         = pref:get("enable_place",         true),
    hit_count            = pref:get("hit_count",            1),
    pnb_x                = pref:get("pnb_x",                0),
    pnb_y                = pref:get("pnb_y",                0),
    pnb_mode             = pref:get("pnb_mode",             1),

    high_trigger         = pref:get("high_trigger",         180),
    low_trigger          = pref:get("low_trigger",          10),
    farm_world           = pref:get("farm_world",           ""),
    farm_door            = pref:get("farm_door",            ""),
    drop_world           = pref:get("drop_world",           ""),
    drop_door            = pref:get("drop_door",            ""),
    drop_item_id         = pref:get("drop_item_id",         0),
    -- default ikut High Trigger lama, biar setting lu nggak berubah pas pertama update
    seed_drop_trigger    = pref:get("seed_drop_trigger",    pref:get("high_trigger", 180)),
    drop_x               = pref:get("drop_x",               0),
    drop_y               = pref:get("drop_y",               0),

    enable_trash_drop    = pref:get("enable_trash_drop",    true),
    trash_drop_world     = pref:get("trash_drop_world",     ""),
    trash_drop_door      = pref:get("trash_drop_door",      ""),
    trash_x              = pref:get("trash_x",              pref:get("trash_1_x", 0)),
    trash_y              = pref:get("trash_y",              pref:get("trash_1_y", 0)),

    show_punch           = pref:get("show_punch",           true),
    webhook_enable       = pref:get("webhook_enable",       false),
    webhook_url          = pref:get("webhook_url",          ""),   -- URL relay Apps Script (.../exec)
    webhook_key          = pref:get("webhook_key",          ""),   -- harus sama dengan SECRET di relay.gs
    webhook_interval     = pref:get("webhook_interval",     30),   -- laporan rutin tiap N menit (0 = mati)
    enable_auto_collect  = pref:get("enable_auto_collect",  true),
    collect_radius       = math.min(2, tonumber(pref:get("collect_radius", 1)) or 1),
    log_compact          = pref:get("log_compact",          true),

    delay_place          = pref:get("delay_place",          80),
    delay_punch          = pref:get("delay_punch",          180),
    delay_harvest        = pref:get("delay_harvest",        180),
    delay_plant          = pref:get("delay_plant",          120),
    enable_anti_miss     = pref:get("enable_anti_miss",     true),

    pnb_retry            = 2,   -- Anti Miss udah nunggu update server, 2x cukup
    pnb_max_cycles       = 60,
}


-- Per item: toggle + jumlah. ID diambil dari trash_defaults (tetap, nggak bisa diubah).
for i, _ in ipairs(trash_defaults) do
    config["trash_"..i.."_enable"] = pref:get("trash_"..i.."_enable", true)
    config["trash_"..i.."_count"]  = pref:get("trash_"..i.."_count",  1)
end

-- Log Ringkas: pesan rutin yang sering muncul disembunyikan biar console nggak bengkak.
-- Error, drop, penyakit, reconnect, webhook, dan statistik tetap tampil.
local LOG_NOISY = { "[FINISH WORLD]", "Panen & Tanam Ulang", "Tanam Seed (", "PnB Block...", "PnB Sisa Block", "START PNB",
                    "Warp ke World", "[CEK DROP]", "[RESUME]", "Trash aktif:", "[TRASH DI TAS]" }
local function Log(msg)
    msg = tostring(msg)
    if config.log_compact then
        for _, k in ipairs(LOG_NOISY) do
            if string.find(msg, k, 1, true) then return end
        end
    end
    LogToConsole("`5[LoliStore 24/7] `0" .. msg)
end

-- ===== WEBHOOK: antrean + statistik sesi =====
local wh_queue = {}
local function newStats()
    return { started = os.time(), trash_trips = 0, trash_pcs = 0, seed_trips = 0, seed_pcs = 0,
             reconnects = 0, worlds_done = 0, errors = 0, restarts = 0,
             harvested = 0, planted = 0, pnb_broken = 0, idle_waits = 0 }
end
local wh_stats = newStats()
wh_stats.started = 0
local function whClean(s) return (tostring(s or ""):gsub("`.", "")) end
-- Masukin pesan ke antrean. Dikirim thread webhook, nggak nahan bot.
local function webhookPush(text)
    if not config.webhook_enable then return end
    if #wh_queue >= 30 then table.remove(wh_queue, 1) end   -- jaga memori kalau relay mati lama
    wh_queue[#wh_queue + 1] = os.date("[%H:%M] ") .. whClean(text)
end

-- CACHE TRASH AKTIF
local active_trash_list = {}
-- Cari ID item dari nama lewat API resmi Growlauncher. Return nil kalau nggak ketemu.
local function lookupItemID(name)
    local tries = {
        function() return growtopia and growtopia.getItemID and growtopia.getItemID(name) end,
        function() return findItemID and findItemID(name) end,
        function()
            local info = getItemInfoByName and getItemInfoByName(name)
            if type(info) == "table" or type(info) == "userdata" then
                return info.id or info.itemID or info.ID
            end
        end,
    }
    for _, f in ipairs(tries) do
        local ok, id = pcall(f)
        id = ok and tonumber(id) or nil
        if id and id > 0 then return id end
    end
    return nil
end

-- Sekali per Start: cocokkan ID bawaan dengan ID asli di game (dari nama item)
local trash_ids_resolved = false
local function resolveTrashIds()
    if trash_ids_resolved then return end
    trash_ids_resolved = true
    local changed, missing = {}, {}
    for _, item in ipairs(trash_defaults) do
        local real = lookupItemID(item.name)
        if real and real ~= item.id then
            changed[#changed + 1] = item.name .. " " .. item.id .. "->" .. real
            item.id = real
        elseif not real then
            missing[#missing + 1] = item.name
        end
    end
    if #changed > 0 then
        Log("`3[TRASH ID] Dikoreksi dari nama item: " .. table.concat(changed, ", ") .. "`0")
    end
    if #missing > 0 then
        Log("`4[TRASH ID] Nama nggak ketemu di game (pakai ID bawaan): " .. table.concat(missing, ", ") .. "`0")
    end
end

local function updateActiveTrashList()
    active_trash_list = {}
    if not config.enable_trash_drop then return end
    if config.trash_x == 0 and config.trash_y == 0 then
        Log("`4Trash drop dilewati: koordinat Trash X/Y belum diset.")
        return
    end
    for i, item in ipairs(trash_defaults) do
        if config["trash_"..i.."_enable"] then
            table.insert(active_trash_list, {
                name  = item.name,
                id    = item.id,
                count = math.max(1, tonumber(config["trash_"..i.."_count"]) or 1),
                x     = config.trash_x,
                y     = config.trash_y,
            })
        end
    end
    Log("Trash aktif: " .. #active_trash_list .. " item")

    -- Tampilkan ID + jumlah di tas, biar kelihatan kalau ada ID yang salah
    local parts = {}
    for _, t in ipairs(active_trash_list) do
        local n = 0
        if growtopia and growtopia.checkInventoryCount then
            local ok, c = pcall(growtopia.checkInventoryCount, t.id)
            n = (ok and tonumber(c)) or 0
        end
        parts[#parts + 1] = t.name .. "(" .. t.id .. ")=" .. n
    end
    if #parts > 0 then
        Log("[TRASH DI TAS] " .. table.concat(parts, ", "))
    end
end

local seed_id                  = 0
local running                  = false
local reconnecting             = false
local warping                  = false
local gc_counter               = 0
local thread_instance          = 0

local last_action_time         = 0
local last_priority_check      = 0
local last_collect_time        = 0
local priority_busy            = false
local bot_state                = "IDLE"
local drop_block_until         = 0
local resume                   = nil -- kerjaan yang terpotong drop: {ready, plant, phase, idx}

local farm_world_list          = {}
local current_farm_index       = 1

local doDrop
local doTrashDrop
local trashWorld, seedDropWorld, returnToFarm

local action_seq = 0   -- naik tiap ada aksi nyata (pukul, place, jalan, warp, drop)
local function updateActionTime()
    action_seq = action_seq + 1
    last_action_time = os.time()
    gc_counter = gc_counter + 1
    if gc_counter >= 50 then
        -- langkah kecil (incremental), bukan "collect" penuh yang bikin game berhenti sejenak
        collectgarbage("step", 64)
        gc_counter = 0
    end
end

-- INVENTORY
local function getInventoryMap()
    local ok, inv = pcall(getInventory)
    if not ok or type(inv) ~= "table" then return nil end
    local map = {}
    for _, item in pairs(inv) do
        if item and item.id then
            local id  = tonumber(item.id)
            local amt = tonumber(item.amount or item.count or item.cnt or 0) or 0
            if id then
                map[id] = (map[id] or 0) + amt
            end
        end
    end
    return map
end

local function invCount(item_id, invMap)
    item_id = tonumber(item_id)
    if not item_id or item_id == 0 then return 0 end

    if invMap then
        return tonumber(invMap[item_id]) or 0
    end

    if growtopia and growtopia.checkInventoryCount then
        local ok, count = pcall(growtopia.checkInventoryCount, item_id)
        if ok and tonumber(count) then
            return tonumber(count)
        end
    end

    local map = getInventoryMap()
    return map and (map[item_id] or 0) or 0
end

local function isThreadOwned(my_id)
    return running and (thread_instance == my_id)
end

local function isThreadActive(my_id)
    return isThreadOwned(my_id) and not reconnecting
end

local function isRecoveryActive(my_id)
    return isThreadOwned(my_id)
end

-- PRIORITY DROP (throttle berbasis waktu, bukan tiap aksi)
local PRIORITY_INTERVAL_MS = 1000

local function nowMs()
    local ok, t = pcall(getTime)
    if ok and tonumber(t) then return tonumber(t) end
    return os.time() * 1000
end

local last_drop_diag = -1000  -- log pertama langsung muncul saat start
local last_cooldown_log = 0
local function checkPriorityDrop(my_id, force)
    if not isThreadOwned(my_id) then return false end
    if priority_busy then return false end
    if os.time() < drop_block_until then
        if os.time() - last_cooldown_log >= 30 then
            last_cooldown_log = os.time()
            Log("`4[CEK DROP] Drop sebelumnya gagal, coba lagi dalam " .. (drop_block_until - os.time()) .. " detik.`0")
        end
        return false
    end

    local now = nowMs()
    if not force and (now - last_priority_check) < PRIORITY_INTERVAL_MS then
        return false
    end
    last_priority_check = now

    -- Pakai checkInventoryCount (sama dengan yang dipakai farming & sudah terbukti jalan).
    -- getInventory() di sebagian versi formatnya beda -> drop diam-diam nggak pernah kepicu.
    local invMap = setmetatable({}, { __index = function(t, id)
        local c = invCount(id)
        rawset(t, id, c)
        return c
    end })

    local target_diag = (config.drop_item_id > 0) and config.drop_item_id or seed_id
    if target_diag == 0 then target_diag = config.block_id end
    if os.time() - last_drop_diag >= 30 then
        last_drop_diag = os.time()
        local top_name, top_amt, top_need = "-", 0, 0
        for _, t in ipairs(active_trash_list) do
            local a = invMap[t.id]
            if a > top_amt then top_name, top_amt, top_need = t.name, a, t.count end
        end
        Log("[CEK DROP] Item " .. target_diag .. ": " .. invMap[target_diag] .. "/" .. config.seed_drop_trigger
            .. " | Trash terbanyak: " .. top_name .. " " .. top_amt .. "/" .. top_need
            .. " | trash aktif: " .. #active_trash_list)
    end

    local function runPriorityDrop(drop_fn, label)
        priority_busy = true
        bot_state = "PRIORITY_DROP"
        Log(label)
        local ok, result = pcall(drop_fn)
        priority_busy = false
        bot_state = "FARM"
        if not ok then
            Log("`4[PRIORITY ERROR] " .. tostring(result))
            wh_stats.errors = wh_stats.errors + 1
            webhookPush("⚠️ Error saat drop: " .. tostring(result))
            drop_block_until = os.time() + 60
            return false
        end
        if result == true then
            last_priority_check = 0 -- cek lagi segera setelah drop berhasil
            return true
        end
        -- Drop gagal: jangan warp bolak-balik, tunggu 60 detik
        drop_block_until = os.time() + 60
        webhookPush("⚠️ Drop gagal, coba lagi dalam 60 detik.")
        return false
    end

    local trash_due = {}
    local trash_desc = {}
    if config.enable_trash_drop then
        for _, t in ipairs(active_trash_list) do
            local current_amt = invMap[t.id] or 0
            if current_amt >= t.count then
                trash_due[#trash_due + 1] = t
                trash_desc[#trash_desc + 1] = t.name .. " " .. current_amt .. "/" .. t.count
            end
        end
    end

    local target_item = (config.drop_item_id > 0) and config.drop_item_id or seed_id
    if target_item == 0 then target_item = config.block_id end
    local seed_amt = (target_item > 0) and (invMap[target_item] or 0) or 0
    local seed_due = target_item > 0 and seed_amt >= config.seed_drop_trigger

    if #trash_due == 0 and not seed_due then return false end


    local label = "`3[PRIORITY DROP]"
    if #trash_due > 0 then label = label .. " Trash: " .. table.concat(trash_desc, ", ") .. "." end
    if seed_due then label = label .. " Item " .. target_item .. ": " .. seed_amt .. "/" .. config.seed_drop_trigger .. "." end
    label = label .. " Stop aksi -> Warp Drop!`0"

    return runPriorityDrop(function()
        local any = false
        -- Satu perjalanan: world trash -> (world seed kalau perlu, tanpa mampir farm) -> balik farm.
        -- Kalau world trash = world seed, nggak ada warp tambahan (warpToWorld skip world yang sama).
        if #trash_due > 0 then
            if doTrashDrop(my_id, trash_due, seed_due) then any = true end
        end
        if seed_due then
            if doDrop(my_id, true) then any = true end
            returnToFarm(my_id)
        end
        return any
    end, label)
end

local function applyModFly()
    pcall(function()
        editToggle("ModFly", true)
    end)
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

-- Delay dipakai APA ADANYA sesuai angka di GUI.
local function ActionSleep(ms)
    ms = tonumber(ms) or 0
    if ms > 0 then Sleep(ms) end
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

-- return nil kalau tidak ada world / di EXIT
local function safeGetWorldName()
    local ok, w = pcall(GetWorldName)
    if ok and w and w ~= "" and string.upper(w) ~= "EXIT" then return w end
    return nil
end

-- Versi cache 500ms: buat kunci tile & loop collect (deteksi reconnect tetap pakai yang asli)
local wn_cache, wn_cache_at = nil, -math.huge
local function worldNameCached()
    local now = nowMs()
    if now - wn_cache_at >= 500 then
        wn_cache, wn_cache_at = safeGetWorldName(), now
    end
    return wn_cache
end

local last_door = ""   -- door yang dipakai di warp terakhir ("" = tanpa door)
local function warpToWorldInner(target_world, door_id, my_id, force, recovery_mode)
    if not target_world or target_world == "" then return false end
    local current_w = safeGetWorldName()
    door_id = door_id or ""

    -- Skip warp HANYA kalau world sama DAN door sama (atau target tanpa door).
    -- World sama tapi door beda = area beda -> harus warp lewat door itu.
    if not force and current_w and string.upper(current_w) == string.upper(target_world)
        and (door_id == "" or string.upper(door_id) == string.upper(last_door)) then
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
        if recovery_mode then
            if not isRecoveryActive(my_id) then return false end
        else
            if not isThreadActive(my_id) then return false end
        end
        local w = safeGetWorldName()
        if w and string.upper(w) == string.upper(target_world) then
            last_door = door_id
            Sleep(1500)
            applyModFly()
            collectgarbage("step", 256)   -- habis warp: bersih-bersih sedikit lebih banyak, tetap bertahap
            updateActionTime()
            return true
        end
        Sleep(1000)
        elapsed = elapsed + 1000
    end
    return false
end

-- Flag `warping` supaya reconnectMonitor tidak salah kira world transisi = disconnect
local function warpToWorld(target_world, door_id, my_id, force, recovery_mode)
    warping = true
    wn_cache_at = -math.huge   -- cache nama world basi setelah warp
    local ok = warpToWorldInner(target_world, door_id, my_id, force, recovery_mode)
    wn_cache_at = -math.huge
    warping = false
    return ok
end

returnToFarm = function(my_id)
    -- force=false: kalau sudah di world farm, nggak warp ulang
    warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, false, true)
end

local function checkWatchdog(my_id)
    if last_action_time == 0 or not isThreadOwned(my_id) then return end
    if priority_busy or bot_state == "RECONNECT" then return end

    local idle_time = os.time() - last_action_time
    if idle_time >= 180 then
        Log("`4[WATCHDOG] Tidak ada aksi selama " .. idle_time .. " detik. Cek posisi/world sebelum re-warp...")
        local w = safeGetWorldName()
        local p = getPlayer()
        last_action_time = os.time()
        if not w or not p then
            bot_state = "RECONNECT"
            warpToWorld(getCurrentFarmWorld(), config.farm_door, my_id, true, true)
            bot_state = "FARM"
        else
            Log("`2[WATCHDOG] World dan player masih valid; tidak melakukan re-warp paksa.`0")
        end
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

local work_seq = 0   -- naik cuma kalau ada pukul / place (bukan jalan / warp)
local function punchTile(tx, ty, target_id, already_checked)
    if not config.enable_break then return end
    local p = getPlayer()
    if not p then return end

    if config.enable_verify_punch and not already_checked then
        local tile = safeGetTile(tx, ty)
        local expected = target_id or config.block_id
        if not tile or (expected > 0 and tile.fg ~= expected) then
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
        work_seq = work_seq + 1

        if target_id == seed_id then
            ActionSleep(config.delay_harvest)
        else
            ActionSleep(config.delay_punch)
        end
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
    work_seq = work_seq + 1
    ActionSleep(is_plant and config.delay_plant or config.delay_place)
end

-- exact = true -> harus tepat di tile (dipakai untuk titik PnB)
-- Nilai balik FindPath TIDAK dipercaya (beda-beda antar versi). Berhasil/gagal
-- ditentukan dari posisi karakter: sampai = berhasil, lewat batas waktu = gagal.
local walk_fail_streak = 0
local last_walk_diag = 0
local function walkTo(tx, ty, exact)
    local function arrived()
        local cx, cy = getPlayerTile()
        if not cx or not cy then return false end
        if exact then
            if cx == tx and cy == ty then return true end
            if growtopia and growtopia.isOnPos then
                local ok, on = pcall(growtopia.isOnPos, tx, ty)
                if ok and on == true then return true end
            end
            return false
        end
        return math.abs(cx - tx) <= 1 and math.abs(cy - ty) <= 1
    end

    if arrived() then walk_fail_streak = 0; return true end

    local sx, sy = getPlayerTile()
    local ok_path, path_ret = pcall(FindPath, tx, ty)

    -- Tunggu SELAMA karakter masih makin dekat ke tujuan. Gagal kalau 2.5 dtk nggak ada kemajuan
    -- (atau total 40 dtk). Jadi jalan lambat (mis. kena Chicken Feet) nggak dianggap gagal.
    local function distNow()
        local cx, cy = getPlayerTile()
        if not cx then return nil end
        return math.abs(cx - tx) + math.abs(cy - ty)
    end
    local best = distNow() or 999
    local stall, waited = 0, 0
    while stall < 2500 and waited < 40000 do
        if not running or reconnecting then return false end
        if arrived() then
            walk_fail_streak = 0
            updateActionTime()
            return true
        end
        Sleep(100)
        waited = waited + 100
        local d = distNow()
        if d and d < best then
            best = d
            stall = 0
        else
            stall = stall + 100
        end
    end

    walk_fail_streak = walk_fail_streak + 1
    if os.time() - last_walk_diag >= 20 then
        last_walk_diag = os.time()
        local cx, cy = getPlayerTile()
        Log("`4[WALK] Gagal ke X=" .. tx .. " Y=" .. ty .. " | posisi X=" .. tostring(cx) .. " Y=" .. tostring(cy)
            .. " | FindPath ok=" .. tostring(ok_path) .. " ret=" .. tostring(path_ret) .. "`0")
    end
    return false
end

local COLLECT_INTERVAL_MS = 250
local COLLECT_MAX_TRIES   = 2      -- tiap item maks dicoba 2x
local COLLECT_RETRY_MS    = 1500   -- jeda sebelum coba ke-2
local COLLECT_SKIP_MS     = 60000  -- item yang gagal 2x dilewati 60 dtk
local COLLECT_MAX_PER_SEC = 6      -- total paket ambil per detik (semua item)
local collect_info = {}            -- obj.id -> { tries, last, skip_until }
local collect_window, collect_window_n = 0, 0
local collect_skip_log = 0

-- from_thread = true kalau dipanggil dari thread Auto Collect.
-- Kalau Auto Collect nyala, panggilan dari PnB/panen dilewati (thread yang ngurus).
local function collectNearby(from_thread)
    if config.enable_auto_collect and not from_thread then return end

    local now = nowMs()
    if not from_thread and (now - last_collect_time) < COLLECT_INTERVAL_MS then return end
    last_collect_time = now

    -- Maks 2 tile: ambil item dari jauh itu paket yang ditandai "bannable" oleh Growlauncher
    local radius_tiles = math.max(1, math.min(2, tonumber(config.collect_radius) or 1))
    local radius_px = radius_tiles * 32 + 16

    local p = getPlayer()
    if not p then return end
    local objs = safeGetObjects()
    if not objs then return end

    if now - collect_window >= 1000 then collect_window, collect_window_n = now, 0 end

    local present, skipped, near = {}, 0, 0
    for _, obj in pairs(objs) do
        local ox = obj and (obj.posX or (obj.pos and obj.pos.x))
        local oy = obj and (obj.posY or (obj.pos and obj.pos.y))
        if ox and oy and obj.id then
            present[obj.id] = true
            if math.abs(p.posX - ox) <= radius_px and math.abs(p.posY - oy) <= radius_px then
                near = near + 1
                local info = collect_info[obj.id]
                local itemid = tonumber(obj.itemid or obj.itemID)
                if info and info.skip_until and now < info.skip_until then
                    skipped = skipped + 1
                elseif itemid and itemid > 0 and invCount(itemid) >= 200 then
                    -- tas udah penuh buat item ini: percuma ngirim paket ambil
                    skipped = skipped + 1
                elseif collect_window_n < COLLECT_MAX_PER_SEC
                    and (not info or now - info.last >= COLLECT_RETRY_MS) then
                    info = info or { tries = 0, last = 0 }
                    if info.tries >= COLLECT_MAX_TRIES then
                        -- udah 2x dicoba masih ada di tanah -> nggak bisa diambil, lewati dulu
                        info.skip_until, info.tries = now + COLLECT_SKIP_MS, 0
                        skipped = skipped + 1
                    else
                        sendPacketRaw(false, { type = 11, value = obj.id, x = ox, y = oy })
                        info.tries, info.last = info.tries + 1, now
                        collect_window_n = collect_window_n + 1
                    end
                    collect_info[obj.id] = info
                end
            end
        end
    end

    -- buang catatan item yang udah nggak ada di world (kepungut / hilang)
    for id in pairs(collect_info) do
        if not present[id] then collect_info[id] = nil end
    end

    if skipped > 0 and now - collect_skip_log >= 60000 then
        collect_skip_log = now
        Log("`4[COLLECT] " .. skipped .. " item di dekat nggak bisa diambil (tas penuh / ditolak server), dilewati.`0")
    end
    return near
end

-- Thread Auto Collect: jalan terus selama bot nyala, pause saat drop / warp / reconnect
-- dan saat nggak di world farm (biar item yang baru di-drop di storage nggak kepungut lagi).
local function autoCollectLoop(my_id)
    local interval = COLLECT_INTERVAL_MS
    local last_work = work_seq
    while running and thread_instance == my_id do
        local found = false
        if config.enable_auto_collect and not warping and not reconnecting and not priority_busy then
            local w = safeGetWorldName()   -- sengaja NGGAK pakai cache: habis pindah world harus langsung ketahuan
            local farm = getCurrentFarmWorld()
            if w and farm ~= "" and string.upper(w) == string.upper(farm) then
                local ok, n = pcall(collectNearby, true)
                found = ok and (n or 0) > 0
            end
        end
        -- Ada item / bot baru mukul-nanam -> cepat lagi. Sepi -> melambat sampai 1 detik.
        if found or work_seq ~= last_work then
            interval = COLLECT_INTERVAL_MS
        else
            interval = math.min(1000, interval + 250)
        end
        last_work = work_seq
        Sleep(interval)
    end
end

local function tkey(x, y)
    return y * 256 + x
end

-- Urutan pola ular: baris dari atas ke bawah, arah tiap baris dipilih dari ujung
-- yang paling dekat dengan posisi terakhir (lebih sedikit bolak-balik).
-- Memori tile yang gagal berulang. Kalau tile yang sama dikerjain lagi dalam 3 menit
-- (artinya percobaan sebelumnya gagal: pohon nggak pecah / seed nggak ketanam), dihitung gagal.
-- 2x gagal -> tile dilewati 10 menit. Pohon asli butuh jauh lebih lama dari 3 menit buat tumbuh lagi.
local TILE_RETRY_WINDOW = 180
local TILE_SKIP_SEC     = 600
local tile_mem = {}
local tile_skip_count, tile_skip_log = 0, 0
local function tileKey(kind, x, y)
    return kind .. ":" .. tostring(worldNameCached() or "?") .. ":" .. x .. ":" .. y
end
local function tileSkipped(kind, x, y)
    local m = tile_mem[tileKey(kind, x, y)]
    return m ~= nil and m.skip_until ~= nil and os.time() < m.skip_until
end
-- Skip tile. Tiap kali tile yang sama ke-skip lagi, durasinya dobel (10 -> 20 -> 40 -> maks 60 menit).
local function applySkip(m, kind, x, y)
    m.skips = (m.skips or 0) + 1
    local dur = math.min(3600, TILE_SKIP_SEC * 2 ^ (m.skips - 1))
    m.skip_until, m.fails = os.time() + dur, 0
    tile_skip_count = tile_skip_count + 1
    if os.time() - tile_skip_log >= 60 then
        tile_skip_log = os.time()
        Log("`4[SKIP] Tile " .. (kind == "h" and "panen" or "tanam") .. " X=" .. x .. " Y=" .. y
            .. " gagal berulang, dilewati " .. math.floor(dur / 60) .. " menit (total " .. tile_skip_count .. " kali).`0")
    end
end

-- Dipanggil tepat sebelum ngerjain tile. Return true kalau tile harus dilewati.
local function tileTouch(kind, x, y)
    local k = tileKey(kind, x, y)
    local now = os.time()
    local m = tile_mem[k] or { fails = 0 }
    if m.skip_until and now < m.skip_until then return true end
    if not config.enable_anti_miss then
        if m.last and now - m.last < TILE_RETRY_WINDOW then m.fails = m.fails + 1 else m.fails = 0 end
    elseif m.last and now - m.last >= TILE_RETRY_WINDOW then
        m.fails = 0
    end
    m.last = now
    tile_mem[k] = m
    if m.fails >= 2 then
        applySkip(m, kind, x, y)
        return true
    end
    return false
end
-- Anti Miss ON: gagal yang udah dikonfirmasi langsung dicatat
local function tileFail(kind, x, y)
    local k = tileKey(kind, x, y)
    local m = tile_mem[k]
    if not m then m = { fails = 0, last = os.time() }; tile_mem[k] = m end
    m.fails = m.fails + 1
    if m.fails >= 2 then applySkip(m, kind, x, y) end
end

-- bersihin memori lama biar nggak numpuk
local tile_mem_clean = 0
local function tileMemClean()
    local now = os.time()
    if now - tile_mem_clean < 600 then return end
    tile_mem_clean = now
    for k, m in pairs(tile_mem) do
        if (not m.skip_until or now > m.skip_until) and (not m.last or now - m.last > 7200) then tile_mem[k] = nil end
    end
end

local function snakeSort(list, start_x)
    if #list <= 1 then return list end
    local rows, ys = {}, {}
    for _, t in ipairs(list) do
        local r = rows[t.y]
        if not r then
            r = {}
            rows[t.y] = r
            ys[#ys + 1] = t.y
        end
        r[#r + 1] = t
    end
    table.sort(ys)

    local out = {}
    local cur_x = start_x or 0
    for _, y in ipairs(ys) do
        local r = rows[y]
        table.sort(r, function(a, b) return a.x < b.x end)
        if math.abs(r[1].x - cur_x) <= math.abs(r[#r].x - cur_x) then
            for i = 1, #r do out[#out + 1] = r[i] end
            cur_x = r[#r].x
        else
            for i = #r, 1, -1 do out[#out + 1] = r[i] end
            cur_x = r[1].x
        end
    end
    return out
end

local function buildWorldTargets(tiles, start_x)
    local ready = {}
    local plant = {}
    if not tiles then return ready, plant end

    local tile_map = {}
    for _, tile in pairs(tiles) do
        if tile and tile.x ~= nil and tile.y ~= nil then
            tile_map[tkey(tile.x, tile.y)] = tile
            if tile.fg == seed_id and tile.readyharvest == true and not tileSkipped("h", tile.x, tile.y) then
                ready[#ready + 1] = {x = tile.x, y = tile.y}
            end
        end
    end

    for _, tile in pairs(tiles) do
        if tile and tile.x ~= nil and tile.y ~= nil and tile.fg == 0 then
            local below = tile_map[tkey(tile.x, tile.y + 1)]
            if below and below.fg ~= 0 and below.fg ~= seed_id and not tileSkipped("p", tile.x, tile.y) then
                plant[#plant + 1] = {x = tile.x, y = tile.y}
            end
        end
    end

    return snakeSort(ready, start_x), snakeSort(plant, start_x)
end

-- SATU scan world -> daftar panen + daftar tanam sekaligus
local function getWorldTargets()
    tileMemClean()
    local tiles = safeGetTiles()
    if not tiles then return {}, {} end
    local px = getPlayerTile()
    return buildWorldTargets(tiles, px)
end

-- Tanam satu tile dengan retry.
-- Return: nil = normal, "drop" = terpotong drop priority, "stop" = thread berhenti/reconnect.
-- Tunggu tile berubah sesuai harapan (update dari server bisa telat). Maks ANTI_MISS_WAIT_MS.
local ANTI_MISS_WAIT_MS = 600
local function waitTile(x, y, want_fg)
    local waited = 0
    while true do
        local c = safeGetTile(x, y)
        if c and c.fg == want_fg then return true end
        if waited >= ANTI_MISS_WAIT_MS then return false end
        Sleep(100)
        waited = waited + 100
    end
end

local function plantTile(my_id, x, y)
    local retry = 0
    local ok_plant = false
    while retry < config.pnb_retry do
        if not isThreadActive(my_id) then return "stop" end
        placeBlock(x, y, seed_id, true)
        if checkPriorityDrop(my_id) then return "drop" end

        if config.enable_anti_miss then
            if waitTile(x, y, seed_id) then
                wh_stats.planted = wh_stats.planted + 1; ok_plant = true
                tile_mem[tileKey("p", x, y)] = nil
                break
            end
            retry = retry + 1
        else
            wh_stats.planted = wh_stats.planted + 1
            break
        end
    end
    if config.enable_anti_miss and not ok_plant then tileFail("p", x, y) end
    return nil
end

-- Ambil sisa daftar mulai dari indeks tertentu
local function remainingFrom(list, idx)
    local out = {}
    for i = idx or 1, #list do out[#out + 1] = list[i] end
    return out
end

-- Return: interrupted (true kalau terpotong drop -> perlu dilanjutkan), next_idx
local function doPlant(my_id, plant_tiles, start_idx)
    if not config.enable_place then return false end
    if not plant_tiles or #plant_tiles == 0 then return false end

    for idx = start_idx or 1, #plant_tiles do
        local t = plant_tiles[idx]
        if not isThreadActive(my_id) then return false end
        if invCount(seed_id) <= config.low_trigger then break end
        if checkPriorityDrop(my_id) then return true, idx end

        if walk_fail_streak >= 5 then
            Log("`4Tanam dihentikan: 5x gagal jalan berturut-turut.`0")
            return false
        end
        local tile = safeGetTile(t.x, t.y)
        local go = tile and tile.fg == 0 and not tileTouch("p", t.x, t.y)
        if go and not walkTo(t.x, t.y) then tileFail("p", t.x, t.y); go = false end
        if go then
            local r = plantTile(my_id, t.x, t.y)
            if r == "drop" then return true, idx + 1 end
            if r == "stop" then return false end
        end
    end
    return false
end

-- Panen lalu langsung tanam ulang di tile yang sama (tile bekas pohon pasti valid).
-- Return: interrupted (true kalau terpotong drop -> perlu dilanjutkan), next_idx
local function doHarvestReplant(my_id, ready_tiles, start_idx)
    if not ready_tiles or #ready_tiles == 0 then return false end

    for idx = start_idx or 1, #ready_tiles do
        local t = ready_tiles[idx]
        if not isThreadActive(my_id) then return false end
        if invCount(config.block_id) >= config.high_trigger then break end
        if checkPriorityDrop(my_id) then return true, idx end

        if walk_fail_streak >= 5 then
            Log("`4Panen dihentikan: 5x gagal jalan berturut-turut.`0")
            return false
        end
        local tile = safeGetTile(t.x, t.y)
        local go = tile and tile.fg == seed_id and not tileTouch("h", t.x, t.y)
        if go and not walkTo(t.x, t.y) then tileFail("h", t.x, t.y); go = false end  -- nggak kecapai = gagal juga
        if go then
            local retry = 0
            local broken = false
            while retry < config.pnb_retry do
                if not isThreadActive(my_id) then return false end
                punchTile(t.x, t.y, seed_id)
                -- tile ini masih dicek ulang saat dilanjutkan (fg==seed -> pukul lagi, fg==0 -> lewati)
                if checkPriorityDrop(my_id) then return true, idx end

                if config.enable_anti_miss then
                    if waitTile(t.x, t.y, 0) then broken = true; break end
                    retry = retry + 1
                else
                    broken = true
                    break
                end
            end
            if broken then
                wh_stats.harvested = wh_stats.harvested + 1
                tile_mem[tileKey("h", t.x, t.y)] = nil
            elseif config.enable_anti_miss then tileFail("h", t.x, t.y) end

            collectNearby()

            if broken and config.enable_place and invCount(seed_id) > config.low_trigger
                and not tileTouch("p", t.x, t.y) then
                local r = plantTile(my_id, t.x, t.y)
                if r == "drop" then return true, idx + 1 end
                if r == "stop" then return false end
            end
        end
    end
    return false
end

-- Drop pakai API resmi kalau ada; fallback ke packet dialog manual
-- Tunggu sampai jumlah item turun dari 'before' (maks 3 detik)
local function waitCountDrop(item_id, before, timeout)
    local waited = 0
    timeout = timeout or 3000
    while waited < timeout do
        if invCount(item_id) < before then return true end
        Sleep(200)
        waited = waited + 200
    end
    return false
end

-- ===== DROP ITEM =====
-- Tiap cara dicoba lalu DICEK dari jumlah item di tas. Cara yang berhasil diingat
-- dan dipakai duluan di drop berikutnya. Pesan dari game selama drop ditangkap
-- supaya kelihatan kenapa drop ditolak.
local drop_capture = nil      -- tabel pesan game saat drop berlangsung
local drop_method_ok = nil    -- nomor cara yang terakhir berhasil

local DROP_METHODS = {
    { name = "confirmDropItem", run = function(id, amt)
        if not (growtopia and growtopia.confirmDropItem) then return false end
        return (pcall(growtopia.confirmDropItem, id, amt))
    end },
    { name = "dropItem + confirmDropItem", run = function(id, amt)
        if not (growtopia and growtopia.dropItem and growtopia.confirmDropItem) then return false end
        pcall(growtopia.dropItem, id)
        Sleep(600)
        return (pcall(growtopia.confirmDropItem, id, amt))
    end },
    { name = "paket drop (|itemID|)", run = function(id, amt)
        sendPacket(2, "action|drop\n|itemID|" .. id)
        Sleep(600)
        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "|\ncount|" .. amt .. "\n")
        return true
    end },
    { name = "paket drop (itemID|)", run = function(id, amt)
        sendPacket(2, "action|drop\nitemID|" .. id .. "\n")
        Sleep(600)
        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "|\ncount|" .. amt .. "\n")
        return true
    end },
}

-- Return true kalau jumlah item di tas benar-benar berkurang
local function dropItemAmount(item_id, amount)
    local order = {}
    if drop_method_ok then order[#order + 1] = drop_method_ok end
    for i = 1, #DROP_METHODS do
        if i ~= drop_method_ok then order[#order + 1] = i end
    end

    drop_capture = {}
    for _, i in ipairs(order) do
        local m = DROP_METHODS[i]
        local before = invCount(item_id)
        if before <= 0 then drop_capture = nil; return true end
        if m.run(item_id, math.min(amount, before)) and waitCountDrop(item_id, before, 1500) then
            if drop_method_ok ~= i then
                Log("[DROP] Cara drop yang jalan: " .. m.name)
            end
            drop_method_ok = i
            drop_capture = nil
            return true
        end
    end

    if #drop_capture > 0 then
        Log("`4[DROP] Pesan game: " .. table.concat(drop_capture, " | ") .. "`0")
    else
        Log("`4[DROP] Semua cara drop gagal & game nggak kirim pesan apa pun.`0")
    end
    drop_capture = nil
    return false
end

-- Hook: tangkap pesan game hanya saat drop berlangsung
local MALADIES = { "Torn Punching Muscle", "Chicken Feet", "Gem Cuts", "Broken Heart", "Grumbleteeth" }
local malady_logged = {}
local function watchMalady(msg)
    if type(msg) ~= "string" then return end
    local plain = msg:gsub("`.", "")
    local low = string.lower(plain)
    for _, m in ipairs(MALADIES) do
        if string.find(low, string.lower(m), 1, true) and (os.time() - (malady_logged[m] or -999)) >= 60 then
            malady_logged[m] = os.time()
            local hint = ""
            if m == "Torn Punching Muscle" then hint = " -> block butuh lebih banyak pukulan (batas PnB menyesuaikan)."
            elseif m == "Chicken Feet" then hint = " -> jalan lebih lambat (bot nunggu selama masih bergerak)." end
            Log("`4[MALADY] Terdeteksi: " .. m .. hint .. " Obat: surgery.`0")
            webhookPush("🤒 Kena penyakit: " .. m .. hint)
        end
    end
end

-- Status koneksi ditebak dari pesan game sendiri
local net_state, net_changed_at = "unknown", 0
local NET_CONNECTING = { "error connecting", "getting server address", "located server", "check your internet",
                         "connecting...", "server might be down", "trying again in" }
local NET_ONLINE     = { "entered. there are", "where would you like to go", "welcome back" }
local function watchNet(msg)
    if type(msg) ~= "string" then return end
    local low = string.lower((msg:gsub("`.", "")))
    for _, k in ipairs(NET_CONNECTING) do
        if string.find(low, k, 1, true) then net_state, net_changed_at = "connecting", os.time(); return end
    end
    for _, k in ipairs(NET_ONLINE) do
        if string.find(low, k, 1, true) then net_state, net_changed_at = "online", os.time(); return end
    end
end

local function onVariantDrop(var, pkt)
    if type(var) ~= "table" then return end
    if var.v1 == "OnConsoleMessage" or var.v1 == "OnTextOverlay" then watchMalady(var.v2); watchNet(var.v2)
    elseif var.v1 == "OnTalkBubble" then watchMalady(var.v3) end
    if not drop_capture then return end
    local fn = var.v1
    local msg = nil
    if fn == "OnConsoleMessage" or fn == "OnTextOverlay" then msg = var.v2
    elseif fn == "OnTalkBubble" then msg = var.v3
    elseif fn == "OnDialogRequest" then msg = "(dialog) " .. tostring(var.v2):sub(1, 80)
    end
    if type(msg) == "string" and #drop_capture < 5 then
        drop_capture[#drop_capture + 1] = msg:gsub("`.", "")
    end
end

-- Jalan ke titik drop lalu drop. Kalau titik penuh/nggak kecapai, geser X-1 (maks 10x).
-- Return: berhasil?, X terakhir yang dipakai
local function dropAtSpot(my_id, item_id, amount, start_x, start_y, tag)
    local try_x, try_y = start_x, start_y
    -- Selama belum ada cara drop yang terbukti jalan, gagal = masalah cara drop (bukan titik penuh),
    -- jadi cukup coba 3 titik. Kalau sudah pernah berhasil, geser sampai 10 titik.
    local max_shift = drop_method_ok and 10 or 3
    for i = 1, max_shift do
        if not isThreadActive(my_id) then break end
        if try_x < 0 then break end

        if not walkTo(try_x, try_y, true) then
            Log("Gagal mencapai titik " .. tag .. " X=" .. try_x .. ". Geser ke X=" .. (try_x - 1))
            try_x = try_x - 1
        else
            Sleep(500)
            if dropItemAmount(item_id, amount) then
                updateActionTime()
                return true, try_x
            end
            Log("Titik " .. tag .. " X=" .. try_x .. " penuh/gagal drop. Geser ke X=" .. (try_x - 1))
            try_x = try_x - 1
        end
    end
    return false, try_x
end

trashWorld = function()
    return (config.trash_drop_world and config.trash_drop_world ~= "") and config.trash_drop_world or getCurrentFarmWorld()
end
seedDropWorld = function()
    return (config.drop_world and config.drop_world ~= "") and config.drop_world or getCurrentFarmWorld()
end

-- TRASH DROP: semua item di 'items' dibuang dalam SATU kunjungan (tanpa sisa).
-- no_return = true -> nggak balik ke farm dulu (dipakai kalau habis ini drop seed juga)
doTrashDrop = function(my_id, items, no_return)
    bot_state = "TRASH_DROP"
    if not warpToWorld(trashWorld(), config.trash_drop_door, my_id, false, true) then
        Log("Gagal warp ke Trash Storage World!")
        bot_state = "FARM"
        return false
    end

    local any = false
    local cur_x = config.trash_x
    for _, t in ipairs(items) do
        if not isThreadActive(my_id) then break end
        local count = invCount(t.id)
        if count > 0 then
            local ok, used_x = dropAtSpot(my_id, t.id, count, cur_x, config.trash_y, "Trash")
            if ok then
                any = true
                cur_x = used_x -- item berikutnya mulai dari titik yang terakhir berhasil
                Log("TRASH DROP Berhasil! " .. t.name .. " (" .. count .. " pcs) di X=" .. used_x .. ", Y=" .. config.trash_y)
                wh_stats.trash_pcs = wh_stats.trash_pcs + count
                webhookPush("🗑️ Trash drop: " .. t.name .. " x" .. count)
            else
                Log("`4TRASH DROP gagal: " .. t.name .. "`0")
            end
        end
    end

    if any then wh_stats.trash_trips = wh_stats.trash_trips + 1 end
    if not no_return then returnToFarm(my_id) end
    bot_state = "FARM"
    return any
end

-- DROP UTAMA (seed / item pilihan). Seed disisakan sebanyak Low Trigger.
doDrop = function(my_id, no_return)
    bot_state = "ITEM_DROP"

    if config.drop_x == 0 and config.drop_y == 0 then
        Log("`4Koordinat Drop belum diset (0,0). Drop dibatalkan.")
        bot_state = "FARM"
        return false
    end

    local target_item = (config.drop_item_id > 0) and config.drop_item_id or seed_id
    if target_item == 0 then target_item = config.block_id end

    local total_item = invCount(target_item)
    local keep_amount = 0
    if target_item == seed_id then
        keep_amount = math.max(0, config.low_trigger or 10)
    end
    local amount_to_drop = math.min(200, total_item - keep_amount)
    if amount_to_drop <= 0 then
        bot_state = "FARM"
        return false
    end

    if not warpToWorld(seedDropWorld(), config.drop_door, my_id, false, true) then
        Log("Gagal warp ke Storage World! Batal drop item.")
        bot_state = "FARM"
        return false
    end

    local ok, used_x = dropAtSpot(my_id, target_item, amount_to_drop, config.drop_x, config.drop_y, "Drop")
    if ok then
        Log("DROP berhasil di X=" .. used_x .. ", Y=" .. config.drop_y .. " (" .. amount_to_drop .. " item, sisa " .. invCount(target_item) .. ")")
        wh_stats.seed_trips = wh_stats.seed_trips + 1
        wh_stats.seed_pcs = wh_stats.seed_pcs + amount_to_drop
        webhookPush("📦 Drop item " .. target_item .. " x" .. amount_to_drop .. " di " .. seedDropWorld())
        if used_x ~= config.drop_x then
            config.drop_x = used_x
            pref:set("drop_x", config.drop_x)
            pref:save()
            pcall(function() editValue("drop_x", config.drop_x) end)
        end
    end

    if not no_return then returnToFarm(my_id) end
    bot_state = "FARM"
    return ok
end

local function getPnbTargets(cx, cy)
    local mode = config.pnb_mode or 1
    if mode == 2 then
        return {
            {x = cx - 1, y = cy - 1}, {x = cx, y = cy - 1}, {x = cx + 1, y = cy - 1},
        }
    elseif mode == 3 then
        return {
            {x = cx, y = cy + 1}, {x = cx, y = cy + 2},
        }
    else
        return {
            {x = cx - 2, y = cy - 1}, {x = cx - 1, y = cy - 1},
            {x = cx,     y = cy - 1}, {x = cx + 1, y = cy - 1}, {x = cx + 2, y = cy - 1},
        }
    end
end

local last_pnb_fail_log = 0
local pnb_pause_until = 0
local pnb_pause_count = 0   -- jeda makin panjang kalau gagal lagi (2,4,8.. maks 30 mnt)
-- Riwayat jumlah pukulan sampai block pecah (20 terakhir). Kalau kena Torn Punching Muscle,
-- semua block butuh lebih banyak pukulan -> batas "nyangkut" ikut naik.
local pnb_break_hist = {}
local function recordBreakHits(h)
    if not h or h <= 0 then return end
    pnb_break_hist[#pnb_break_hist + 1] = h
    if #pnb_break_hist > 20 then table.remove(pnb_break_hist, 1) end
end
local function pnbStuckLimit()
    if #pnb_break_hist < 3 then return 100 end   -- belum ada data: longgar
    local t = {}
    for i, v in ipairs(pnb_break_hist) do t[i] = v end
    table.sort(t)
    local median = t[math.floor((#t + 1) / 2)]
    return math.max(30, median * 3)
end
local function doPnb(my_id)
    Log("START PNB (Mode: " .. config.pnb_mode .. ")")
    bot_state = "PNB"
    local interrupted = false
    local function pri()
        if checkPriorityDrop(my_id) then
            interrupted = true
            return true
        end
        return false
    end
    if checkPriorityDrop(my_id, true) then bot_state = "FARM"; return nil, true end

    if not walkTo(config.pnb_x, config.pnb_y, true) then
        if os.time() - last_pnb_fail_log >= 30 then
            last_pnb_fail_log = os.time()
            Log("`4Gagal jalan ke titik PnB X=" .. config.pnb_x .. " Y=" .. config.pnb_y .. " (path nggak ketemu / posisi nggak pas).`0")
        end
        bot_state = "FARM"
        return
    end

    if os.time() < pnb_pause_until then bot_state = "FARM"; return end

    local cycles = 0
    local place_tries, place_ok = 0, 0
    local placed_at = {}   -- "x:y" -> true kalau barusan di-place
    local pnb_hits  = {}   -- "x:y" -> jumlah pukulan sejak terakhir pecah
    local pnb_stuck = {}   -- "x:y" -> nomor siklus sampai kapan tile dilewati

    while isThreadActive(my_id) do
        cycles = cycles + 1
        if cycles > (config.pnb_max_cycles or 60) then
            Log("`4[PNB GUARD] Batas siklus tercapai, keluar agar tidak infinite loop.`0")
            break
        end

        if pri() then break end

        if invCount(config.block_id) <= config.low_trigger then
            bot_state = "FARM"
            return "low_block", false
        end

        local cx, cy = getPlayerTile()
        if not cx or cx ~= config.pnb_x or cy ~= config.pnb_y then
            if not walkTo(config.pnb_x, config.pnb_y, true) then break end
            cx, cy = getPlayerTile()
            if not cx then break end
        end

        local targets = getPnbTargets(cx, cy)

        if config.enable_place then
            placed_at = {}
            for _, t in ipairs(targets) do
                if not isThreadActive(my_id) then break end
                if invCount(config.block_id) <= 0 then break end
                local tile = safeGetTile(t.x, t.y)
                if tile and tile.fg == 0 then
                    pnb_hits[t.x .. ":" .. t.y] = 0 -- block baru -> hitung dari nol
                    placeBlock(t.x, t.y, config.block_id, false)
                    place_tries = place_tries + 1
                    placed_at[t.x .. ":" .. t.y] = true
                    if pri() then break end
                end
            end

            -- Cek hasil place (kasih waktu update server). Kalau 10x place nggak ada satu pun yang
            -- jadi block (nggak punya akses / tile ketutup), jangan diulang terus: jeda PnB 2 menit.
            local any_placed = false
            for _, t in ipairs(targets) do
                if placed_at[t.x .. ":" .. t.y] then any_placed = true end
            end
            -- Anti Miss mati: nggak nunggu. Hasil place dihitung nanti pas tile dibaca di loop pukul.
            if any_placed and config.enable_anti_miss then
                local waited = 0
                repeat
                    local n = 0
                    for _, t in ipairs(targets) do
                        local k = t.x .. ":" .. t.y
                        if placed_at[k] then
                            local c = safeGetTile(t.x, t.y)
                            if c and c.fg == config.block_id then place_ok = place_ok + 1; placed_at[k] = nil
                            else n = n + 1 end
                        end
                    end
                    if n == 0 or waited >= ANTI_MISS_WAIT_MS then break end
                    Sleep(100)
                    waited = waited + 100
                until false
                placed_at = {}
            end
            -- Anti Miss mati: tile yang udah kelihatan jadi block sekarang langsung dihitung
            if not config.enable_anti_miss then
                for _, t in ipairs(targets) do
                    local k = t.x .. ":" .. t.y
                    if placed_at[k] then
                        local c = safeGetTile(t.x, t.y)
                        if c and c.fg == config.block_id then place_ok = place_ok + 1; placed_at[k] = nil end
                    end
                end
            end
            if place_ok > 0 then pnb_pause_count = 0 end
            if place_tries >= 10 and place_ok == 0 then
                pnb_pause_count = pnb_pause_count + 1
                local menit = math.min(30, 2 ^ pnb_pause_count)
                pnb_pause_until = os.time() + menit * 60
                Log("`4[PNB] Place block gagal terus (" .. place_tries .. "x, nggak ada yang jadi). "
                    .. "Cek akses/lock di titik PnB. PnB dijeda " .. menit .. " menit.`0")
                webhookPush("⚠️ PnB: place block gagal terus di X=" .. config.pnb_x .. " Y=" .. config.pnb_y .. ", dijeda " .. menit .. " menit.")
                break
            end
        end

        if not isThreadActive(my_id) then break end
        if pri() then break end

        if config.enable_break then
            -- Hitung pukulan per tile. Block keras butuh banyak pukulan: itu BUKAN nyangkut.
            -- Tile baru dianggap nyangkut kalau sudah PNB_MAX_HITS pukulan tapi nggak pecah
            -- (biasanya: di luar jangkauan pukul / ada yang ngalangin).
            local break_cycles = 0
            while isThreadActive(my_id) do
                break_cycles = break_cycles + 1
                if break_cycles > pnbStuckLimit() + 10 then break end

                if pri() then break end
                local remaining = 0

                for _, t in ipairs(targets) do
                    if not isThreadActive(my_id) then break end
                    local key = t.x .. ":" .. t.y

                    local cur = safeGetTile(t.x, t.y)
                    if placed_at[key] and cur and cur.fg == config.block_id then
                        place_ok = place_ok + 1; placed_at[key] = nil
                    end
                    local is_stuck = pnb_stuck[key] and cycles < pnb_stuck[key]
                    if cur and cur.fg ~= config.block_id then
                        -- Pecahnya baru kelihatan sekarang (update server telat) -> catat & reset
                        if (pnb_hits[key] or 0) > 0 then wh_stats.pnb_broken = wh_stats.pnb_broken + 1 end
                        recordBreakHits(pnb_hits[key])
                        pnb_hits[key] = 0
                    elseif cur and not is_stuck then
                        remaining = remaining + 1
                        punchTile(t.x, t.y, config.block_id, true)  -- baru aja dicek di atas
                        pnb_hits[key] = (pnb_hits[key] or 0) + math.max(1, config.hit_count or 1)
                        local after = safeGetTile(t.x, t.y)
                        if after and after.fg ~= config.block_id then
                            wh_stats.pnb_broken = wh_stats.pnb_broken + 1
                            recordBreakHits(pnb_hits[key])
                            pnb_hits[key] = 0
                            collectNearby() -- ambil drop langsung, nggak nunggu semua block pecah
                        elseif pnb_hits[key] >= pnbStuckLimit() then
                            pnb_stuck[key] = cycles + 5 -- lewati 5 siklus, lalu dicoba lagi
                            Log("`4[PNB] Block di X=" .. t.x .. " Y=" .. t.y .. " nggak pecah setelah " .. pnb_hits[key]
                                .. " pukulan (kemungkinan di luar jangkauan). Dilewati 5 siklus.`0")
                            pnb_hits[key] = 0
                        end
                    end
                end

                if remaining == 0 then break end
            end
        end

        -- Kalau semua target nyangkut, PnB di titik ini percuma -> keluar
        local stuck_n = 0
        for _, t in ipairs(targets) do
            local st = pnb_stuck[t.x .. ":" .. t.y]
            if st and cycles < st then stuck_n = stuck_n + 1 end
        end
        if stuck_n >= #targets then
            Log("`4[PNB] Semua target nyangkut. Cek titik PnB / coba PnB Mode lain.`0")
            break
        end

        collectNearby()
        if pri() then break end
    end

    bot_state = "FARM"
    return nil, interrupted
end

local function processCurrentWorld(my_id)
    bot_state = "FARM"
    resume = nil
    local idle_streak = 0
    local last_idle_log = 0

    while isThreadOwned(my_id) do
        if reconnecting then
            Sleep(500)
        else
            checkWatchdog(my_id)

            local seq_before = action_seq
            walk_fail_streak = 0
            if not checkPriorityDrop(my_id, true) then
                local ctx = resume
                resume = nil

                if not ctx and invCount(config.block_id) >= config.high_trigger then
                    Log("PnB Block...")
                    local _, intr = doPnb(my_id)
                    if intr then resume = {phase = 3} end
                else
                    local ready, plant, phase, idx
                    if ctx then
                        -- Lanjutkan kerjaan yang tadi terpotong drop/trash
                        ready, plant = ctx.ready or {}, ctx.plant or {}
                        phase, idx = ctx.phase, ctx.idx or 1
                        Log("`3[RESUME] Drop selesai, lanjut kerjaan yang tadi (fase " .. phase .. ")...`0")
                    else
                        -- SATU scan world per iterasi
                        ready, plant = getWorldTargets()
                        local can_plant = config.enable_place and invCount(seed_id) > config.low_trigger
                        if not can_plant then plant = {} end

                        if #ready == 0 and #plant == 0 and invCount(config.block_id) <= config.low_trigger then
                            Log("`2[FINISH WORLD] Tidak ada pekerjaan tersisa. Pindah ke World Farm berikutnya...`0")
                            return true
                        end
                        phase, idx = 1, 1
                    end

                    local interrupted = false
                    local function save(ph, ix)
                        resume = {ready = ready, plant = plant, phase = ph, idx = ix}
                        interrupted = true
                    end

                    -- FASE 1: panen + tanam ulang
                    if phase <= 1 and #ready > 0 then
                        if phase == 1 and idx > 1 then
                            ready = snakeSort(remainingFrom(ready, idx), (getPlayerTile()))
                            idx = 1
                        end
                        if not ctx then Log("Panen & Tanam Ulang (" .. #ready .. " pohon)...") end
                        local intr, nxt = doHarvestReplant(my_id, ready, idx)
                        if intr then save(1, nxt) end
                    end

                    -- FASE 2: tanam tile kosong
                    if not interrupted and isThreadActive(my_id) and phase <= 2 and #plant > 0 then
                        if checkPriorityDrop(my_id, true) then
                            save(2, 1)
                        else
                            local start = (phase == 2) and idx or 1
                            plant = snakeSort(remainingFrom(plant, start), (getPlayerTile()))
                            if not ctx then Log("Tanam Seed (" .. #plant .. " tile)...") end
                            local intr, nxt = doPlant(my_id, plant, 1)
                            if intr then save(2, nxt) end
                        end
                    end

                    -- FASE 3: PnB sisa block
                    if not interrupted and isThreadActive(my_id) then
                        if checkPriorityDrop(my_id, true) then
                            save(3, 1)
                        elseif invCount(config.block_id) > config.low_trigger then
                            Log("PnB Sisa Block...")
                            local _, intr = doPnb(my_id)
                            if intr then save(3, 1) end
                        end
                    end
                end

            end

            -- ANTI-FREEZE: kalau putaran ini nggak ada satu pun aksi yang benar-benar terjadi
            -- (misal gagal jalan ke titik PnB / pohon), jangan langsung muter lagi.
            if action_seq == seq_before then
                idle_streak = idle_streak + 1
                if idle_streak >= 5 and os.time() - last_idle_log >= 30 then
                    last_idle_log = os.time()
                    Log("`4[IDLE] " .. idle_streak .. " putaran tanpa aksi. Cek titik PnB / jalur ke pohon bisa dicapai.`0")
                end
                Sleep(math.min(10000, 500 * idle_streak))
            else
                idle_streak = 0
            end
        end
    end

    return false
end

local function reconnectMonitor(my_id)
    while isThreadOwned(my_id) do
        Sleep(3000)
        if not isThreadOwned(my_id) then break end

        -- Sedang warp = bukan disconnect
        if not warping then
            local p = getPlayer()
            local w = safeGetWorldName()
            if not p or not w then
                reconnecting = true
                bot_state = "RECONNECT"
                local down_since = os.time()
                local retry_delay = 10000
                local warned, waiting_logged = false, false
                Log("`4[DISCONNECT] Koneksi/world hilang. Nunggu game nyambung lagi...`0")
                webhookPush("🔌 Disconnect terdeteksi, mencoba reconnect...")

                while isThreadOwned(my_id) do
                    -- Game bisa masuk world lagi sendiri
                    if getPlayer() and safeGetWorldName() then
                        local target = getCurrentFarmWorld()
                        local ok = warpToWorld(target, config.farm_door, my_id, false, true)
                        if ok then
                            local menit = math.floor((os.time() - down_since) / 60)
                            Log("`2Berhasil reconnect ke " .. tostring(target) .. " (putus " .. menit .. " menit)`0")
                            wh_stats.reconnects = wh_stats.reconnects + 1
                            webhookPush("✅ Reconnect berhasil ke " .. tostring(target) .. " setelah " .. menit .. " menit")
                            break
                        end
                    end

                    if not warned and os.time() - down_since >= 300 then
                        warned = true
                        webhookPush("🔌 Nggak bisa nyambung ke server sejak " .. os.date("%H:%M", down_since)
                            .. " (5+ menit). Cek internet / status server.")
                    end

                    if net_state == "connecting" and os.time() - net_changed_at < 90 then
                        -- Game lagi login ulang sendiri: jangan diganggu warp
                        if not waiting_logged then
                            waiting_logged = true
                            Log("Game lagi nyoba login ulang, bot nunggu (nggak warp)...")
                        end
                        Sleep(3000)
                    else
                        waiting_logged = false
                        local target_w = getCurrentFarmWorld()
                        local ok = warpToWorld(target_w, config.farm_door, my_id, true, true)
                        if ok then
                            local menit = math.floor((os.time() - down_since) / 60)
                            Log("`2Berhasil reconnect ke " .. tostring(target_w) .. " (putus " .. menit .. " menit)`0")
                            wh_stats.reconnects = wh_stats.reconnects + 1
                            webhookPush("✅ Reconnect berhasil ke " .. tostring(target_w) .. " setelah " .. menit .. " menit")
                            break
                        end
                        Log("Gagal reconnect, coba lagi dalam " .. math.floor(retry_delay / 1000) .. " detik...")
                        -- tunggu, tapi bangun lebih cepat kalau game kelihatan udah nyambung
                        local waited = 0
                        while waited < retry_delay and isThreadOwned(my_id) do
                            Sleep(2000)
                            waited = waited + 2000
                            if (net_state == "online" and os.time() - net_changed_at < 10) or net_state == "connecting" then break end
                        end
                        retry_delay = math.min(300000, retry_delay * 2)
                    end
                end

                reconnecting = false
                bot_state = "FARM"
                last_action_time = os.time()
            end
        end
    end
end

-- ===== WEBHOOK: pengirim, laporan, thread =====
local function urlencode(s)
    s = tostring(s or "")
    s = s:gsub("\n", "\r\n")
    s = s:gsub("([^%w%-%_%.%~])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return s
end

-- Return: berhasil?, keterangan
local function webhookSend(text, url, key)
    url, key = url or config.webhook_url, key or config.webhook_key
    if type(fetch) ~= "function" then return false, "fetch() nggak ada di Growlauncher versi ini" end
    if not url or url == "" then return false, "Relay URL kosong" end
    text = tostring(text):sub(1, 900)   -- batas aman panjang URL
    local full = url .. (url:find("?", 1, true) and "&" or "?") .. "key=" .. urlencode(key) .. "&msg=" .. urlencode(text)
    local ok, res, err = pcall(fetch, full)
    if not ok then return false, tostring(res) end
    if err and err ~= "" then return false, tostring(err) end
    local body = tostring(res or "")
    if body:find("forbidden", 1, true) then return false, "key salah (beda dengan SECRET di relay.gs)" end
    if body:find("no%-webhook") then return false, "URL webhook Discord belum diisi di relay.gs" end
    if body:find("discord%-") then return false, "Discord nolak: " .. body:sub(1, 40) end
    -- Apps Script kadang balas redirect; pesan tetap terkirim karena relay jalan sebelum redirect
    return true, (body:find("ok", 1, true) and "ok" or "terkirim (respon nggak dikonfirmasi)")
end

local function fmtDuration(sec)
    sec = math.max(0, sec or 0)
    return string.format("%dj %02dm", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end

local function statLine()
    local st = wh_stats
    return "[STAT] Jalan " .. fmtDuration(os.time() - st.started)
        .. " | Panen " .. st.harvested .. " | Tanam " .. st.planted .. " | PnB " .. st.pnb_broken .. " block"
        .. " | Drop seed " .. st.seed_trips .. "x (" .. st.seed_pcs .. ") | Trash " .. st.trash_trips .. "x (" .. st.trash_pcs .. ")"
        .. " | World selesai " .. st.worlds_done .. " | Nunggu " .. st.idle_waits .. "x"
        .. " | Reconnect " .. st.reconnects .. " | Error " .. st.errors .. " | Restart " .. st.restarts
end

local function buildReport(title)
    local p = getPlayer()
    local gems = "?"
    if type(getGems) == "function" then
        local okg, g = pcall(getGems)
        if okg and tonumber(g) then gems = string.format("%d", math.floor(tonumber(g))) end
    end
    local lines = {
        "**" .. title .. "**",
        "Player: " .. whClean(p and p.name or "?") .. " | World: " .. tostring(safeGetWorldName() or "EXIT"),
        "Status: " .. tostring(bot_state) .. " | Jalan: " .. fmtDuration(os.time() - wh_stats.started),
        "Gems: " .. tostring(gems) .. " | Seed: " .. invCount(seed_id) .. " | Block: " .. invCount(config.block_id),
        "Panen: " .. wh_stats.harvested .. " | Tanam: " .. wh_stats.planted .. " | PnB: " .. wh_stats.pnb_broken .. " block",
        "Drop seed: " .. wh_stats.seed_trips .. "x (" .. wh_stats.seed_pcs .. " pcs) | Trash: "
            .. wh_stats.trash_trips .. "x (" .. wh_stats.trash_pcs .. " pcs)",
        "World selesai: " .. wh_stats.worlds_done .. " | Reconnect: " .. wh_stats.reconnects
            .. " | Error: " .. wh_stats.errors .. " | Restart: " .. wh_stats.restarts,
    }
    return table.concat(lines, "\n")
end

-- Thread webhook: kirim antrean (digabung jadi 1 pesan, min jeda 3 dtk) + laporan rutin.
-- Setelah bot di-stop, thread masih ngirim sisa antrean (maks 30 dtk) lalu berhenti.
local function webhookLoop(my_id)
    local last_send, last_report = 0, os.time()
    local last_stat = os.time()
    local stop_at = nil
    while true do
        local alive = running and thread_instance == my_id
        if not alive then
            stop_at = stop_at or os.time()
            if #wh_queue == 0 or os.time() - stop_at > 30 then break end
        end

        if alive and os.time() - last_stat >= 3600 then
            last_stat = os.time()
            Log("`3" .. statLine() .. "`0")
        end

        if config.webhook_enable and alive then
            local iv = tonumber(config.webhook_interval) or 0
            if iv > 0 and os.time() - last_report >= iv * 60 then
                last_report = os.time()
                wh_queue[#wh_queue + 1] = os.date("[%H:%M] ") .. buildReport("📊 Laporan rutin")
            end
        end

        if config.webhook_enable and #wh_queue > 0 and nowMs() - last_send >= 3000 then
            local parts, len = {}, 0
            while #wh_queue > 0 and len + #wh_queue[1] < 880 do
                local m = table.remove(wh_queue, 1)
                parts[#parts + 1] = m
                len = len + #m + 1
            end
            if #parts == 0 then parts[1] = table.remove(wh_queue, 1) end
            local ok, info = webhookSend(table.concat(parts, "\n"))
            last_send = nowMs()
            if not ok then
                Log("`4[WEBHOOK] Gagal kirim: " .. info .. "`0")
                -- balikin ke depan antrean, coba lagi nanti (jeda lebih lama)
                for i = #parts, 1, -1 do table.insert(wh_queue, 1, parts[i]) end
                while #wh_queue > 30 do table.remove(wh_queue) end
                last_send = nowMs() + 27000
            end
        elseif not config.webhook_enable then
            wh_queue = {}
        end
        Sleep(1000)
    end
end

local function mainLoop(my_id, is_restart)
    math.randomseed(os.time())

    seed_id            = (config.seed_id and config.seed_id > 0) and config.seed_id or (config.block_id + 1)
    reconnecting       = false
    warping            = false
    gc_counter         = 0
    last_action_time   = os.time()
    drop_block_until   = 0
    resume             = nil

    resolveTrashIds()
    updateActiveTrashList()
    last_collect_time = 0
    last_priority_check = 0

    farm_world_list    = parseWorldList(config.farm_world)
    current_farm_index = 1

    if #farm_world_list == 0 then
        local cw = safeGetWorldName()
        if cw then table.insert(farm_world_list, cw) end
    end

    if is_restart then
        Log("`3[RESTART] Bot jalan lagi setelah error (restart ke-" .. wh_stats.restarts .. ")`0")
    else
        Log("ROTASI 24/7 MULAI! Total Farm World: " .. #farm_world_list .. " | Block ID: " .. config.block_id)
    end
    if not is_restart then
        wh_stats = newStats()
        wh_queue = {}
    end
    if not is_restart then
        if not config.webhook_enable then
            Log("[WEBHOOK] `4Mati`0 - nyalain 'Enable Webhook' di dialog Webhook Discord kalau mau laporan.")
        elseif (config.webhook_url or "") == "" then
            Log("[WEBHOOK] `4Relay URL kosong`0 - laporan nggak bisa dikirim.")
        else
            Log("[WEBHOOK] `2Nyala`0 - laporan rutin tiap " .. tostring(config.webhook_interval) .. " menit.")
        end
        webhookPush(buildReport("🟢 Bot mulai (" .. #farm_world_list .. " farm world)"))
    end
    local function guarded(name, fn)
        runThread(function()
            while isThreadOwned(my_id) do
                local ok, err = pcall(fn, my_id)
                if ok or not isThreadOwned(my_id) then break end
                wh_stats.errors = wh_stats.errors + 1
                Log("`4[ERROR] Thread " .. name .. ": " .. tostring(err) .. " (jalan lagi 5 dtk)`0")
                webhookPush("⚠️ Error di " .. name .. ": " .. tostring(err))
                Sleep(5000)
            end
        end)
    end
    guarded("webhook", webhookLoop)
    guarded("reconnect", reconnectMonitor)
    guarded("autocollect", autoCollectLoop)

    -- Kalau SEMUA farm world dicek berturut-turut tanpa ada yang bisa dikerjain (pohon lagi tumbuh),
    -- bot istirahat di world sekarang dulu, bukan warp muter terus.
    local IDLE_WAIT_SEC = 120
    local empty_worlds = 0

    while isThreadOwned(my_id) do
        if reconnecting or priority_busy then
            Sleep(1000)
        else
            local target_farm = getCurrentFarmWorld()
            -- force=false: kalau udah di world + door yang sama, nggak warp ulang
            local ok_farm = warpToWorld(target_farm, config.farm_door, my_id, false)

            if ok_farm then
                local work_before = work_seq
                local finished_world = processCurrentWorld(my_id)
                if not isThreadOwned(my_id) then break end
                if finished_world then
                    if work_seq > work_before then
                        empty_worlds = 0
                        wh_stats.worlds_done = wh_stats.worlds_done + 1
                    else
                        empty_worlds = empty_worlds + 1
                    end
                    if empty_worlds >= math.max(1, #farm_world_list) then
                        empty_worlds = 0
                        wh_stats.idle_waits = wh_stats.idle_waits + 1
                        Log("Semua farm world lagi nunggu pohon tumbuh. Istirahat " .. IDLE_WAIT_SEC .. " detik di sini (nggak warp).")
                        local waited = 0
                        while waited < IDLE_WAIT_SEC * 1000 and isThreadOwned(my_id) and not reconnecting do
                            Sleep(1000)
                            waited = waited + 1000
                        end
                    end
                    nextFarmWorld()
                end
            else
                Log("Gagal warp ke Farm World: " .. target_farm .. ", mencoba ke world berikutnya...")
                nextFarmWorld()
            end

            Sleep(200)
        end
    end
end

-- ===================== UI =====================
local ui = UserInterface.new("Auto Rotasi 24/7", "Ability")

ui:addLabelApp("AUTO ROTASI 24/7 BY LOLISTORE", "Ability")
ui:addDivider()

local dialog_main = ui:addDialog("Main Config", "Setting utama rotasi", {})
ui:addChildInputInt(dialog_main.menu,    "Block ID",         tostring(config.block_id),     "ID",    "ID block yang di-farm",               "Verified", "block_id")
ui:addChildInputInt(dialog_main.menu,    "Seed ID",          tostring(config.seed_id),      "ID",    "ID seed (0 = otomatis Block ID + 1)", "Verified", "seed_id")
ui:addChildInputString(dialog_main.menu, "Farm World",       config.farm_world,             "World", "FARM1,FARM2 (pisahkan koma)",         "World",    "farm_world")
ui:addChildInputString(dialog_main.menu, "Farm Door",        config.farm_door,              "ID",    "ID door universal world farm",        "World",    "farm_door")
ui:addChildInputInt(dialog_main.menu,    "High Trigger",     tostring(config.high_trigger), "amt",   "Block >= ini -> stop panen, langsung PnB (def:180)", "Verified", "high_trigger")
ui:addChildInputInt(dialog_main.menu,    "Low Trigger",      tostring(config.low_trigger),  "amt",   "block/seed<=ini->stop (def:10)",      "Verified", "low_trigger")

ui:addDivider()

local dialog_autofarm = ui:addDialog("Autofarm & PnB Settings", "Pengaturan aksi Break, Place & PnB", {})
ui:addChildToggle(dialog_autofarm.menu,   "Verify before punch", config.enable_verify_punch, "enable_verify_punch")
ui:addChildToggle(dialog_autofarm.menu,   "Break",               config.enable_break,        "enable_break")
ui:addChildToggle(dialog_autofarm.menu,   "Place",               config.enable_place,        "enable_place")
ui:addChildToggle(dialog_autofarm.menu,   "Show Punch (Visual)", config.show_punch,          "show_punch")
ui:addChildToggle(dialog_autofarm.menu,   "Auto Collect",        config.enable_auto_collect, "enable_auto_collect")
ui:addChildToggle(dialog_autofarm.menu,   "Log Ringkas",         config.log_compact,         "log_compact")
ui:addChildButton(dialog_autofarm.menu,   "Lihat Statistik Sesi", "btn_stats")
ui:addChildInputInt(dialog_autofarm.menu, "Radius Collect (tile)", tostring(math.min(2, tonumber(config.collect_radius) or 1)), "tile", "1-2 tile di sekitar karakter (def:1)", "Verified", "collect_radius")
ui:addChildInputInt(dialog_autofarm.menu, "Hit Count",           tostring(config.hit_count), "cnt",  "Pukulan per siklus (def:1)", "Verified", "hit_count")
ui:addChildInputInt(dialog_autofarm.menu, "PnB X",               tostring(config.pnb_x),     "X",    "Koordinat PnB X",            "Verified", "pnb_x")
ui:addChildInputInt(dialog_autofarm.menu, "PnB Y",               tostring(config.pnb_y),     "Y",    "Koordinat PnB Y",            "Verified", "pnb_y")
ui:addChildButton(dialog_autofarm.menu,   "Set PnB Posisi Sekarang", "btn_pnb_set")
ui:addChildInputInt(dialog_autofarm.menu, "PnB Pattern Mode",    tostring(config.pnb_mode),  "Mode", "1: 5-Tile Top | 2: 3-Tile Top | 3: 2-Tile Bottom", "Verified", "pnb_mode")

ui:addDivider()

local dialog_delay = ui:addDialog("Delay & Speed Settings", "Delay dipakai persis sesuai angka (ms)", {})
ui:addChildInputInt(dialog_delay.menu, "Delay Break (ms)",   tostring(config.delay_punch),   "ms", "Delay memukul block (def: 180)", "Verified", "delay_punch")
ui:addChildInputInt(dialog_delay.menu, "Delay Place (ms)",   tostring(config.delay_place),   "ms", "Delay menaruh block (def: 80)",  "Verified", "delay_place")
ui:addChildInputInt(dialog_delay.menu, "Harvest Delay (ms)", tostring(config.delay_harvest), "ms", "Delay memanen pohon (def: 180)", "Verified", "delay_harvest")
ui:addChildInputInt(dialog_delay.menu, "Plant Delay (ms)",   tostring(config.delay_plant),   "ms", "Delay menanam seed (def: 120)", "Verified", "delay_plant")
ui:addChildToggle(dialog_delay.menu,   "Anti Miss (Wait)",   config.enable_anti_miss,        "enable_anti_miss")

ui:addDivider()

local dialog_drop = ui:addDialog("Seed / Block Drop Config", "Posisi & World drop seed/block utama", {})
ui:addChildInputString(dialog_drop.menu, "Drop World",       config.drop_world,              "World", "World tempat drop (kosongkan jika sama)",  "World",    "drop_world")
ui:addChildInputString(dialog_drop.menu, "Drop Door",        config.drop_door,               "ID",    "ID door world drop",                       "World",    "drop_door")
ui:addChildInputInt(dialog_drop.menu,    "Drop Item ID",     tostring(config.drop_item_id),  "ID",    "ID item yang di-drop (0 = otomatis seed)", "Verified", "drop_item_id")
ui:addChildInputInt(dialog_drop.menu,    "Seed Drop Trigger", tostring(config.seed_drop_trigger), "amt", "Seed >= ini -> drop (sisa = Low Trigger)", "Verified", "seed_drop_trigger")
ui:addChildInputInt(dialog_drop.menu,    "Drop X",           tostring(config.drop_x),        "X",     "koordinat X drop",                         "Verified", "drop_x")
ui:addChildInputInt(dialog_drop.menu,    "Drop Y",           tostring(config.drop_y),        "Y",     "koordinat Y drop",                         "Verified", "drop_y")
ui:addChildButton(dialog_drop.menu, "Set dari posisi sekarang", "btn_drop_set")

ui:addDivider()

local dialog_trash_main = ui:addDialog("Trash Drop Settings", "Centang item sampah + jumlah minimal", {})
ui:addChildToggle(dialog_trash_main.menu,      "Enable Auto Trash Drop", config.enable_trash_drop, "enable_trash_drop")
ui:addChildInputString(dialog_trash_main.menu, "Trash Drop World",       config.trash_drop_world,  "World", "World khusus trash (kosong = world skrg)", "World", "trash_drop_world")
ui:addChildInputString(dialog_trash_main.menu, "Trash Drop Door",        config.trash_drop_door,   "ID",    "Door ID trash world",                      "World", "trash_drop_door")
ui:addChildInputInt(dialog_trash_main.menu,    "Trash Drop X",           tostring(config.trash_x), "X",     "Koordinat X drop sampah",                  "Verified", "trash_x")
ui:addChildInputInt(dialog_trash_main.menu,    "Trash Drop Y",           tostring(config.trash_y), "Y",     "Koordinat Y drop sampah",                  "Verified", "trash_y")
ui:addChildButton(dialog_trash_main.menu,      "Set Trash Posisi Sekarang", "btn_trash_set")
for i, item in ipairs(trash_defaults) do
    ui:addChildToggle(dialog_trash_main.menu,   i .. ". " .. item.name,  config["trash_"..i.."_enable"], "trash_"..i.."_enable")
    ui:addChildInputInt(dialog_trash_main.menu, "Jumlah " .. item.name,  tostring(config["trash_"..i.."_count"]), "amt", "Drop kalau jumlah >= ini", "Verified", "trash_"..i.."_count")
end

ui:addDivider()

local dialog_wh = ui:addDialog("Webhook Discord", "Laporan bot ke Discord lewat relay", {})
ui:addChildToggle(dialog_wh.menu,      "Enable Webhook",          config.webhook_enable,              "webhook_enable")
ui:addChildInputString(dialog_wh.menu, "Relay URL",               config.webhook_url,                 "URL", "https://script.google.com/macros/s/.../exec", "World", "webhook_url")
ui:addChildInputString(dialog_wh.menu, "Relay Key",               config.webhook_key,                 "Key", "Sama dengan SECRET di relay.gs",             "World", "webhook_key")
ui:addChildInputInt(dialog_wh.menu,    "Laporan Rutin (menit)",   tostring(config.webhook_interval),  "min", "0 = cuma event penting (def:30)",            "Verified", "webhook_interval")
ui:addChildButton(dialog_wh.menu,      "Tes Kirim Webhook", "btn_webhook_test")

ui:addDivider()
ui:addButton("Apply Config", "btn_apply")
ui:addDivider()
ui:addToggleButton("Start / Stop", false, "btn_start")

local temp = {
    block_id             = tostring(config.block_id),
    seed_id              = tostring(config.seed_id),
    high_trigger         = tostring(config.high_trigger),
    low_trigger          = tostring(config.low_trigger),
    farm_world           = config.farm_world,
    farm_door            = config.farm_door,
    drop_world           = config.drop_world,
    drop_door            = config.drop_door,
    drop_item_id         = tostring(config.drop_item_id),
    seed_drop_trigger    = tostring(config.seed_drop_trigger),
    pnb_x                = tostring(config.pnb_x),
    pnb_y                = tostring(config.pnb_y),
    pnb_mode             = tostring(config.pnb_mode),
    enable_verify_punch  = config.enable_verify_punch,
    enable_break         = config.enable_break,
    enable_place         = config.enable_place,
    hit_count            = tostring(config.hit_count),
    drop_x               = tostring(config.drop_x),
    drop_y               = tostring(config.drop_y),

    enable_trash_drop    = config.enable_trash_drop,
    trash_drop_world     = config.trash_drop_world,
    trash_drop_door      = config.trash_drop_door,
    trash_x              = tostring(config.trash_x),
    trash_y              = tostring(config.trash_y),

    show_punch           = config.show_punch,
    enable_auto_collect  = config.enable_auto_collect,
    log_compact          = config.log_compact,
    webhook_enable       = config.webhook_enable,
    webhook_url          = config.webhook_url,
    webhook_key          = config.webhook_key,
    webhook_interval     = tostring(config.webhook_interval),
    collect_radius       = tostring(config.collect_radius),
    delay_place          = tostring(config.delay_place),
    delay_punch          = tostring(config.delay_punch),
    delay_harvest        = tostring(config.delay_harvest),
    delay_plant          = tostring(config.delay_plant),
    enable_anti_miss     = config.enable_anti_miss,
}


for i, _ in ipairs(trash_defaults) do
    temp["trash_"..i.."_enable"] = config["trash_"..i.."_enable"]
    temp["trash_"..i.."_count"]  = tostring(config["trash_"..i.."_count"])
end

function OnDraw(d)
    removeHook("onDraw")
    runCoroutine(function()
        CSleepFn(2000)
        addIntoModule(ui:generateJSON(), "Farm")
    end)
end

-- Delay & hit count langsung berlaku begitu diubah di GUI (tanpa Apply)
-- Toggle bisa dikirim sebagai true/1/"1"/"true" tergantung versi -> samakan jadi boolean
local TOGGLE_KEYS = {
    enable_verify_punch = true, enable_break = true, enable_place = true, show_punch = true,
    enable_auto_collect = true, enable_trash_drop = true, enable_anti_miss = true, webhook_enable = true,
    log_compact = true,
}
local function asBool(v)
    if v == true or v == 1 or v == "1" or v == "true" then return true end
    return false
end

local live_keys = {
    delay_place   = true,
    delay_punch   = true,
    delay_harvest = true,
    delay_plant   = true,
    hit_count     = true,
    collect_radius = true,
}

function OnValue(vtype, name, value)
    if TOGGLE_KEYS[name] or (type(name) == "string" and name:match("^trash_%d+_enable$")) then
        value = asBool(value)
    end
    if name == "enable_auto_collect" then
        config.enable_auto_collect = value
    end
    if name == "log_compact" then
        config.log_compact = value; temp.log_compact = value
        LogToConsole("`5[LoliStore 24/7] `0Log Ringkas: " .. (value and "nyala" or "mati"))
    elseif name == "btn_stats" then
        if wh_stats.started > 0 then
            LogToConsole("`5[LoliStore 24/7] `0`3" .. statLine() .. "`0")
            pcall(growtopia.notify, "Statistik sesi ada di console")
        else
            pcall(growtopia.notify, "Bot belum pernah di-Start")
        end
    end
    if name == "webhook_enable" then
        config.webhook_enable = value; temp.webhook_enable = value
        Log("[WEBHOOK] " .. (value and "`2Nyala`0 - laporan otomatis aktif" or "`4Mati`0 - laporan otomatis nonaktif"))
    elseif name == "webhook_url" then
        config.webhook_url = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""); temp.webhook_url = config.webhook_url
    elseif name == "webhook_key" then
        config.webhook_key = tostring(value or ""); temp.webhook_key = config.webhook_key
    elseif name == "webhook_interval" then
        config.webhook_interval = tonumber(value) or config.webhook_interval; temp.webhook_interval = tostring(config.webhook_interval)
    elseif name == "btn_webhook_test" then
        -- fetch bisa lama: jalan di thread, jangan di hook UI
        runThread(function()
            local p = getPlayer()
            local ok, info = webhookSend("🧪 Tes webhook dari " .. whClean(p and p.name or "?")
                .. " | world " .. tostring(safeGetWorldName() or "EXIT"))
            local msg = ok and ("Webhook OK: " .. info) or ("Webhook gagal: " .. info)
            if ok and not config.webhook_enable then
                msg = msg .. " | TAPI 'Enable Webhook' masih MATI: laporan otomatis nggak dikirim"
            end
            Log((ok and "`2" or "`4") .. "[WEBHOOK] " .. msg .. "`0")
            pcall(growtopia.notify, msg)
        end)
    end
    if live_keys[name] then
        local n = tonumber(value)
        if n then config[name] = n end
    end

    if     name == "block_id"            then temp.block_id            = tostring(value)
    elseif name == "seed_id"             then temp.seed_id             = tostring(value)
    elseif name == "high_trigger"        then temp.high_trigger        = tostring(value)
    elseif name == "low_trigger"         then temp.low_trigger         = tostring(value)
    elseif name == "farm_world"          then temp.farm_world          = value
    elseif name == "farm_door"           then temp.farm_door           = value
    elseif name == "drop_world"          then temp.drop_world          = value
    elseif name == "drop_door"           then temp.drop_door           = value
    elseif name == "drop_item_id"        then temp.drop_item_id        = tostring(value)
    elseif name == "seed_drop_trigger"   then temp.seed_drop_trigger   = tostring(value)
    elseif name == "pnb_x"               then temp.pnb_x               = tostring(value)
    elseif name == "pnb_y"               then temp.pnb_y               = tostring(value)
    elseif name == "pnb_mode"            then temp.pnb_mode            = tostring(value)
    elseif name == "enable_verify_punch" then temp.enable_verify_punch = value
    elseif name == "enable_break"        then temp.enable_break        = value
    elseif name == "enable_place"        then temp.enable_place        = value
    elseif name == "hit_count"           then temp.hit_count           = tostring(value)
    elseif name == "drop_x"              then temp.drop_x              = tostring(value)
    elseif name == "drop_y"              then temp.drop_y              = tostring(value)

    elseif name == "enable_trash_drop"   then temp.enable_trash_drop   = value
    elseif name == "trash_drop_world"    then temp.trash_drop_world    = value
    elseif name == "trash_drop_door"     then temp.trash_drop_door     = value
    elseif name == "trash_x"             then temp.trash_x             = tostring(value)
    elseif name == "trash_y"             then temp.trash_y             = tostring(value)

    elseif name == "show_punch"          then temp.show_punch          = value
    elseif name == "enable_auto_collect" then temp.enable_auto_collect = value
    elseif name == "collect_radius"      then temp.collect_radius      = tostring(value)
    elseif name == "delay_place"         then temp.delay_place         = tostring(value)
    elseif name == "delay_punch"         then temp.delay_punch         = tostring(value)
    elseif name == "delay_harvest"       then temp.delay_harvest       = tostring(value)
    elseif name == "delay_plant"         then temp.delay_plant         = tostring(value)
    elseif name == "enable_anti_miss"    then temp.enable_anti_miss    = value
    end

    for i, _ in ipairs(trash_defaults) do
        if name == "trash_"..i.."_enable" then
            temp["trash_"..i.."_enable"] = value
        elseif name == "trash_"..i.."_count" then
            temp["trash_"..i.."_count"] = tostring(value)
        end
    end

    if name == "btn_pnb_set" then
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

    elseif name == "btn_trash_set" then
        local p = getPlayer()
        if p then
            local cx = math.floor(p.posX / 32)
            local cy = math.floor(p.posY / 32)
            temp.trash_x   = tostring(cx)
            temp.trash_y   = tostring(cy)
            config.trash_x = cx
            config.trash_y = cy
            editValue("trash_x", cx)
            editValue("trash_y", cy)
            updateActiveTrashList()
            growtopia.notify("Trash drop set: X=" .. cx .. " Y=" .. cy)
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
        config.block_id           = tonumber(temp.block_id)            or config.block_id
        config.seed_id            = tonumber(temp.seed_id)             or config.seed_id
        config.high_trigger       = tonumber(temp.high_trigger)        or config.high_trigger
        config.low_trigger        = tonumber(temp.low_trigger)         or config.low_trigger
        config.farm_world         = temp.farm_world
        config.farm_door          = temp.farm_door
        config.drop_world         = temp.drop_world
        config.drop_door          = temp.drop_door
        config.drop_item_id       = tonumber(temp.drop_item_id)        or config.drop_item_id
        config.seed_drop_trigger  = tonumber(temp.seed_drop_trigger)   or config.seed_drop_trigger
        config.pnb_x              = tonumber(temp.pnb_x)               or config.pnb_x
        config.pnb_y              = tonumber(temp.pnb_y)               or config.pnb_y
        config.pnb_mode           = tonumber(temp.pnb_mode)            or config.pnb_mode
        config.enable_verify_punch= temp.enable_verify_punch
        config.enable_break       = temp.enable_break
        config.enable_place       = temp.enable_place
        config.hit_count          = tonumber(temp.hit_count)           or config.hit_count
        config.drop_x             = tonumber(temp.drop_x)              or config.drop_x
        config.drop_y             = tonumber(temp.drop_y)              or config.drop_y

        config.enable_trash_drop  = temp.enable_trash_drop
        config.trash_drop_world   = temp.trash_drop_world
        config.trash_drop_door    = temp.trash_drop_door
        for i, _ in ipairs(trash_defaults) do
            config["trash_"..i.."_enable"] = temp["trash_"..i.."_enable"]
            config["trash_"..i.."_count"]  = tonumber(temp["trash_"..i.."_count"]) or config["trash_"..i.."_count"]
            pref:set("trash_"..i.."_enable", config["trash_"..i.."_enable"])
            pref:set("trash_"..i.."_count",  config["trash_"..i.."_count"])
        end
        config.trash_x            = tonumber(temp.trash_x)     or config.trash_x
        config.trash_y            = tonumber(temp.trash_y)     or config.trash_y


        config.show_punch         = temp.show_punch
        config.enable_auto_collect = temp.enable_auto_collect
        config.log_compact        = temp.log_compact
        config.webhook_enable     = temp.webhook_enable
        config.webhook_url        = temp.webhook_url or ""
        config.webhook_key        = temp.webhook_key or ""
        config.webhook_interval   = tonumber(temp.webhook_interval) or config.webhook_interval
        config.collect_radius     = tonumber(temp.collect_radius) or config.collect_radius
        config.delay_place        = tonumber(temp.delay_place)         or config.delay_place
        config.delay_punch        = tonumber(temp.delay_punch)         or config.delay_punch
        config.delay_harvest      = tonumber(temp.delay_harvest)       or config.delay_harvest
        config.delay_plant        = tonumber(temp.delay_plant)         or config.delay_plant
        config.enable_anti_miss   = temp.enable_anti_miss

        seed_id = (config.seed_id and config.seed_id > 0) and config.seed_id or (config.block_id + 1)

        pref:set("block_id",            config.block_id)
        pref:set("seed_id",             config.seed_id)
        pref:set("high_trigger",        config.high_trigger)
        pref:set("low_trigger",         config.low_trigger)
        pref:set("farm_world",          config.farm_world)
        pref:set("farm_door",           config.farm_door)
        pref:set("drop_world",          config.drop_world)
        pref:set("drop_door",           config.drop_door)
        pref:set("drop_item_id",        config.drop_item_id)
        pref:set("seed_drop_trigger",   config.seed_drop_trigger)
        pref:set("pnb_x",               config.pnb_x)
        pref:set("pnb_y",               config.pnb_y)
        pref:set("pnb_mode",            config.pnb_mode)
        pref:set("enable_verify_punch", config.enable_verify_punch)
        pref:set("enable_break",        config.enable_break)
        pref:set("enable_place",        config.enable_place)
        pref:set("hit_count",           config.hit_count)
        pref:set("drop_x",              config.drop_x)
        pref:set("drop_y",              config.drop_y)

        pref:set("enable_trash_drop",   config.enable_trash_drop)
        pref:set("trash_drop_world",    config.trash_drop_world)
        pref:set("trash_drop_door",     config.trash_drop_door)
        pref:set("trash_x",             config.trash_x)
        pref:set("trash_y",             config.trash_y)

        pref:set("show_punch",          config.show_punch)
        pref:set("enable_auto_collect", config.enable_auto_collect)
        pref:set("log_compact",         config.log_compact)
        pref:set("webhook_enable",      config.webhook_enable)
        pref:set("webhook_url",         config.webhook_url)
        pref:set("webhook_key",         config.webhook_key)
        pref:set("webhook_interval",    config.webhook_interval)
        pref:set("collect_radius",      config.collect_radius)
        pref:set("delay_place",         config.delay_place)
        pref:set("delay_punch",         config.delay_punch)
        pref:set("delay_harvest",       config.delay_harvest)
        pref:set("delay_plant",         config.delay_plant)
        pref:set("enable_anti_miss",    config.enable_anti_miss)
        pref:save()

        updateActiveTrashList()

        growtopia.notify("Config Tersimpan, Trash System Diperbarui!")

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

            -- thread_instance + 1 sudah cukup mematikan thread lama (tanpa Sleep di hook UI)
            thread_instance = thread_instance + 1
            local current_id = thread_instance

            running       = true
            reconnecting  = false
            warping       = false
            priority_busy = false
            bot_state     = "FARM"
            applyModFly()
            gc_counter    = 0

            sendVariant({v1 = "OnTextOverlay", v2 = "AUTO ROTASI 24/7 BY LOLISTORE"})
            Log("AUTO ROTASI 24/7 BY LOLISTORE - Started!")

            -- Supervisor: kalau mainLoop error, catat lalu jalan lagi (thread lama dimatiin via id baru)
            runThread(function()
                local my_id = current_id
                local is_restart = false
                local recent = {}
                while running and thread_instance == my_id do
                    local ok, err = pcall(mainLoop, my_id, is_restart)
                    if ok or not (running and thread_instance == my_id) then break end

                    wh_stats.errors = wh_stats.errors + 1
                    wh_stats.restarts = wh_stats.restarts + 1
                    Log("`4[ERROR] " .. tostring(err) .. "`0")
                    webhookPush("⚠️ Bot error: " .. tostring(err) .. " -> restart ke-" .. wh_stats.restarts)

                    -- 5 error dalam 10 menit = ada yang salah terus, jeda 5 menit biar nggak muter
                    recent[#recent + 1] = os.time()
                    while #recent > 0 and os.time() - recent[1] > 600 do table.remove(recent, 1) end
                    local pause = (#recent >= 5) and 300 or 10
                    if pause > 10 then
                        Log("`4[ERROR] Error berulang, jeda " .. pause .. " detik sebelum restart.`0")
                        webhookPush("⚠️ Error berulang (" .. #recent .. "x/10 menit), jeda 5 menit.")
                    end

                    thread_instance = thread_instance + 1   -- matiin thread pembantu lama
                    my_id = thread_instance
                    reconnecting, warping, priority_busy = false, false, false
                    local w = 0
                    while w < pause * 1000 and running and thread_instance == my_id do Sleep(1000); w = w + 1000 end
                    is_restart = true
                end
            end)
        else
            if running then
                webhookPush(buildReport("🔴 Bot dihentikan"))
            end
            thread_instance = thread_instance + 1
            running = false
            bot_state = "IDLE"
            Log("Rotasi dihentikan.")
        end
    end
end

addHook(OnDraw, "onDraw")
addHook(OnValue, "onValue")
addHook(onVariantDrop, "onVariant")
applyHook()

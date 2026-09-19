local pref = require("preferences")
pref:new("rotasi_free_azel_config")
pref:load()

local config = {
    block_id     = pref:get("block_id",     0),
    pnb_x        = pref:get("pnb_x",        0),
    pnb_y        = pref:get("pnb_y",        0),
    high_trigger = pref:get("high_trigger",  180),
    low_trigger  = pref:get("low_trigger",   10),
    farm_door    = pref:get("farm_door",     ""),
    drop_x       = pref:get("drop_x",        0),
    drop_y       = pref:get("drop_y",        0),
    marker_id    = pref:get("marker_id",     1422),
    farm_world   = "",
    pnb_timeout  = 6000,
    pnb_retry    = 4,
}

local seed_id      = 0
local running      = false
local reconnecting = false
local action_count = 0

local function Log(msg)
    LogToConsole("`5[AZEL] `0" .. tostring(msg))
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

local function invCount(item_id)
    local ok, inv = pcall(getInventory)
    if not ok or type(inv) ~= "table" then return 0 end
    for _, item in pairs(inv) do
        if item.id == item_id then return item.amount end
    end
    return 0
end

local function safeGetTile(tx, ty)
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

local function waitTileFg(tx, ty, expected_fg, timeout_ms)
    local elapsed = 0
    while elapsed < timeout_ms do
        if reconnecting then return false end
        local tile = safeGetTile(tx, ty)
        if tile and tile.fg == expected_fg then return true end
        Sleep(200)
        elapsed = elapsed + 200
    end
    return false
end

local function punchTile(tx, ty)
    local p = getPlayer()
    if not p then return end
    sendPacketRaw(false, {
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
    sendPacketRaw(false, {
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
    HumanSleep(math.random(500, 800))
end

local function collectNearby(radius_px)
    radius_px = radius_px or 96
    local p = getPlayer()
    if not p then return end
    local objs = safeGetObjects()
    if not objs then return end
    for _, obj in pairs(objs) do
        local dx = math.abs(p.posX - obj.posX)
        local dy = math.abs(p.posY - obj.posY)
        if dx < radius_px and dy < radius_px then
            sendPacketRaw(false, {
                type  = 11,
                value = obj.id,
                x     = obj.posX + 6,
                y     = 0
            })
            Sleep(math.random(40, 100))
        end
    end
end

local function hasDropOnTile(tx, ty)
    local objs = safeGetObjects()
    if not objs then return false end
    for _, obj in pairs(objs) do
        local ox = math.floor((obj.posX + 16) / 32)
        local oy = math.floor((obj.posY + 16) / 32)
        if math.abs(ox - tx) <= 1 and oy == ty then return true end
    end
    return false
end

local function waitTileClear(tx, ty, timeout_ms)
    local elapsed = 0
    local step = math.random(200, 300)
    while elapsed < timeout_ms do
        if reconnecting then return true end
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
        if tile.fg == seed_id and tile.readyharvest == true then
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
        if tile.fg == 0 then
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

local function doPlant()
    if invCount(seed_id) < config.low_trigger then return end

    Log("START PLANT")
    local plant_tiles = getPlantableTiles()
    if #plant_tiles == 0 then return end

    for _, t in ipairs(plant_tiles) do
        if not running or reconnecting then return end
        if invCount(seed_id) <= config.low_trigger then break end

        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == 0 then
            FindPath(t.x, t.y)
            local wait = 0
            while wait < 2000 do
                local cx, cy = getPlayerTile()
                if cx == t.x and cy == t.y then break end
                Sleep(math.random(40, 80))
                wait = wait + 60
            end
            placeBlock(t.x, t.y, seed_id)
        end
    end
end

local function doHarvestLoop()
    Log("START HARVEST")

    while running and not reconnecting do
        if invCount(config.block_id) >= config.high_trigger then break end

        local ready_tiles = getReadyHarvestTiles()
        if #ready_tiles == 0 then break end

        for _, t in ipairs(ready_tiles) do
            if not running or reconnecting then return end
            if invCount(config.block_id) >= config.high_trigger then break end

            local tile = safeGetTile(t.x, t.y)
            if tile and tile.fg == seed_id and tile.readyharvest == true then
                walkTo(t.x, t.y)

                local retry = 0
                while retry < config.pnb_retry do
                    if reconnecting then return end
                    punchTile(t.x, t.y)
                    if waitTileFg(t.x, t.y, 0, config.pnb_timeout) then
                        local before_block = invCount(config.block_id)
                        local before_seed  = invCount(seed_id)
                        local wait_ms = 0
                        while wait_ms < 3000 do
                            if reconnecting then return end
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

        Sleep(math.random(80, 150))
    end
end

local function doDrop()
    walkTo(config.drop_x, config.drop_y)
    rSleep(400, 700)

    local before = invCount(seed_id)
    sendPacket(2, "action|drop\nitemID|" .. seed_id)
    rSleep(250, 400)
    sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. seed_id .. "\ncount|200")
    rSleep(400, 700)

    if invCount(seed_id) < before then
        Log("DROP berhasil")
    else
        Log("DROP gagal")
    end
end

local function doPTHT()
    doPlant()
    if not running then return end
    while reconnecting and running do Sleep(500) end
    if not running then return end

    if invCount(seed_id) >= config.high_trigger then
        doDrop()
        if not running then return end
        while reconnecting and running do Sleep(500) end
        if not running then return end
    end

    if invCount(config.block_id) <= config.low_trigger or invCount(seed_id) <= config.low_trigger then
        doHarvestLoop()
        if not running then return end
        while reconnecting and running do Sleep(500) end
    end
end

local function getPnbTargets(cx, cy)
    return {
        {x = cx - 1, y = cy},
    }
end

local function doPnb()
    Log("START PNB")
    walkTo(config.pnb_x, config.pnb_y)
    rSleep(500, 800)

    while running and not reconnecting do
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

        local t = getPnbTargets(cx, cy)[1]

        -- jika ada drop di tile target, collect dulu sampai bersih
        if hasDropOnTile(t.x, t.y) then
            waitTileClear(t.x, t.y, 8000)
        end

        -- place block sampai tile target terdeteksi ada fg
        local tile = safeGetTile(t.x, t.y)
        if tile and tile.fg == 0 then
            while running and not reconnecting do
                local cur = safeGetTile(t.x, t.y)
                if cur and cur.fg ~= 0 then break end
                placeBlock(t.x, t.y, config.block_id)
            end
        end

        -- punch sampai fg == 0
        while running and not reconnecting do
            local cur = safeGetTile(t.x, t.y)
            if not cur or cur.fg == 0 then break end
            punchTile(t.x, t.y)
        end

        -- collect dan tunggu tile bersih dari drop sebelum lanjut round berikutnya
        collectNearby()
        while running and not reconnecting do
            if not hasDropOnTile(t.x, t.y) then break end
            collectNearby()
            Sleep(math.random(100, 200))
        end
    end
end

local function reconnectMonitor()
    while running do
        Sleep(3000)
        local p = getPlayer()
        local w = GetWorldName()
        if not p or not w or w == "" or string.upper(w) == "EXIT" then
            reconnecting = true
            local back_target = config.farm_world
            if config.farm_door and config.farm_door ~= "" then
                back_target = config.farm_world .. "|" .. config.farm_door
            end
            while running do
                Sleep(math.random(1800, 2500))
                growtopia.warpTo(back_target)
                local ok = await(function()
                    return GetWorldName() == string.upper(config.farm_world)
                end, 15000)
                if ok then
                    Sleep(math.random(1800, 2500))
                    break
                end
            end
            reconnecting = false
        end
    end
end

local function onVariant(var, pkt)
    if running and var and var.v1 == "OnDialogRequest" then
        return true
    end
end

local function mainLoop()
    math.randomseed(os.time())

    seed_id           = config.block_id + 1
    config.farm_world = safeGetWorldName() or config.farm_world
    reconnecting      = false
    action_count      = 0

    Log("ROTASI MULAI!")

    runThread(reconnectMonitor)

    if invCount(config.block_id) >= config.high_trigger then
        local pnb_result = doPnb()
        if not running then return end
        while reconnecting and running do Sleep(500) end
        if running and pnb_result == "low_block" then
            doPTHT()
            if not running then return end
            while reconnecting and running do Sleep(500) end
        end
    end

    while running do
        while reconnecting and running do Sleep(500) end
        if not running then break end

        local block_count = invCount(config.block_id)

        if block_count >= config.high_trigger then
            local pnb_result = doPnb()
            if not running then break end
            while reconnecting and running do Sleep(500) end
            if not running then break end

            if pnb_result == "low_block" then
                doPTHT()
                if not running then break end
                while reconnecting and running do Sleep(500) end
            else
                if invCount(seed_id) >= config.high_trigger then
                    doDrop()
                    if not running then break end
                    while reconnecting and running do Sleep(500) end
                end
            end
        else
            doPTHT()
            if not running then break end
            while reconnecting and running do Sleep(500) end
        end

        rSleep(200, 400)
    end
end

local ui = UserInterface.new("Auto Rotasi Free", "Ability")

ui:addLabelApp("AUTO ROTASI FREE BY AZEL", "Ability")
ui:addDivider()

local dialog_main = ui:addDialog("Main Config", "Setting utama rotasi", {})
ui:addChildInputInt(dialog_main.menu,    "Block ID",     config.block_id,     "ID",   "ID block (bukan seed)",             "Verified", "block_id")
ui:addChildInputInt(dialog_main.menu,    "High Trigger", config.high_trigger, "amt",  "seed>=ini->Drop (def:180)",         "Verified", "high_trigger")
ui:addChildInputInt(dialog_main.menu,    "Low Trigger",  config.low_trigger,  "amt",  "block/seed<=ini->stop (def:10)",    "Verified", "low_trigger")
ui:addChildInputString(dialog_main.menu, "Door Farm",    config.farm_door,    "ID",   "link/path world farm",              "World",    "farm_door")

ui:addDivider()

local dialog_pnb = ui:addDialog("PnB Position", "Berdiri di posisi PnB dulu sebelum set", {})
ui:addChildInputInt(dialog_pnb.menu, "PnB X", config.pnb_x, "X", "koordinat X", "Verified", "pnb_x")
ui:addChildInputInt(dialog_pnb.menu, "PnB Y", config.pnb_y, "Y", "koordinat Y", "Verified", "pnb_y")
ui:addChildButton(dialog_pnb.menu, "Set dari posisi sekarang", "btn_pnb_set")

ui:addDivider()

local dialog_drop = ui:addDialog("Drop Config", "Posisi drop seed di world farm", {})
ui:addChildInputInt(dialog_drop.menu, "Drop X", config.drop_x, "X", "koordinat X drop", "Verified", "drop_x")
ui:addChildInputInt(dialog_drop.menu, "Drop Y", config.drop_y, "Y", "koordinat Y drop", "Verified", "drop_y")
ui:addChildButton(dialog_drop.menu, "Set dari posisi sekarang", "btn_drop_set")

ui:addDivider()
ui:addButton("Apply Config", "btn_apply")
ui:addDivider()
ui:addToggleButton("Start / Stop", false, "btn_start")

local temp = {
    block_id     = tostring(config.block_id),
    high_trigger = tostring(config.high_trigger),
    low_trigger  = tostring(config.low_trigger),
    farm_door    = config.farm_door,
    pnb_x        = tostring(config.pnb_x),
    pnb_y        = tostring(config.pnb_y),
    drop_x       = tostring(config.drop_x),
    drop_y       = tostring(config.drop_y),
}

function OnDraw(d)
    removeHook("ondraw")
    runCoroutine(function()
        sleep(2000)
        addCategory("Farm", "Ability")
        addIntoModule(ui:generateJSON(), "Farm")
    end)
end

function OnValue(type, name, value)
    if     name == "block_id"     then temp.block_id     = tostring(value)
    elseif name == "high_trigger" then temp.high_trigger = tostring(value)
    elseif name == "low_trigger"  then temp.low_trigger  = tostring(value)
    elseif name == "farm_door"    then temp.farm_door    = value
    elseif name == "pnb_x"        then temp.pnb_x        = tostring(value)
    elseif name == "pnb_y"        then temp.pnb_y        = tostring(value)
    elseif name == "drop_x"       then temp.drop_x       = tostring(value)
    elseif name == "drop_y"       then temp.drop_y       = tostring(value)

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
        config.block_id     = tonumber(temp.block_id)     or config.block_id
        config.high_trigger = tonumber(temp.high_trigger) or config.high_trigger
        config.low_trigger  = tonumber(temp.low_trigger)  or config.low_trigger
        config.farm_door    = temp.farm_door
        config.pnb_x        = tonumber(temp.pnb_x)        or config.pnb_x
        config.pnb_y        = tonumber(temp.pnb_y)        or config.pnb_y
        config.drop_x       = tonumber(temp.drop_x)       or config.drop_x
        config.drop_y       = tonumber(temp.drop_y)       or config.drop_y

        pref:set("block_id",     config.block_id)
        pref:set("high_trigger", config.high_trigger)
        pref:set("low_trigger",  config.low_trigger)
        pref:set("farm_door",    config.farm_door)
        pref:set("pnb_x",        config.pnb_x)
        pref:set("pnb_y",        config.pnb_y)
        pref:set("drop_x",       config.drop_x)
        pref:set("drop_y",       config.drop_y)
        pref:save()

        growtopia.notify("Config tersimpan!")

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
            if running then
                running = false
                Sleep(500)
            end
            running      = true
            reconnecting = false
            action_count = 0
            sendVariant({v1 = "OnTextOverlay", v2 = "AUTO ROTASI FREE BY AZEL"})
            Log("AUTO ROTASI FREE BY AZEL — Started!")
            runThread(mainLoop)
        else
            running = false
            Log("Rotasi dihentikan.")
        end
    end
end

addHook(onVariant, "onVariant")
applyHook()

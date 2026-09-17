Config = {
    World = {
        nameworld = {"CONCG", "MLJEG", "JVHXP", "IIGNV", "YCRRU", "JSVMB", "BIPKC"},
        StoragePlatWorld = "PHINIS",
        StoragePlatDoor = "DoorID",
        worldsaveseed = "PHINIS|DoorID"
     },

    DelaySettings = {
        DELAY_PLACE = 120, -- Anti Soft-Ban
        DELAY_BREAK = 220  -- Anti Soft-Ban
    }
}

index_world = 1
nameworld = Config.World.nameworld[index_world]
StoragePlatWorld = Config.World.StoragePlatWorld
StoragePlatDoor = Config.World.StoragePlatDoor
worldsaveseed = Config.World.worldsaveseed

EditToggle("Antibounce", true)
EditToggle("ModFly", true)
EditToggle("Antilag", true)
EditToggle("Fast Trash", true)
EditToggle("Fast Drop", true)
EditToggle("Cant Pickup Item", true)

dpc = Config.DelaySettings.DELAY_PLACE
dbk = Config.DelaySettings.DELAY_BREAK

PlatformID = 102
WorldLockID = 242
EntranceID = 6

-- State Fitur Utama DF
autoDF_running = false

-- State Pengaturan Autofarm
EnableBreak = true
EnablePlace = true
HitCount = 1
VerifyPunch = false

-- State Non-Random World Door ID
DFWorldDoor = ""

-- State Auto Drop Setting (Format ID:X:Y)
AutoDropEnabled = false
MinToDrop = 190
DropWorld = "SDZRR"
DropDoor = ""
CustomDropCoords = "3:26:11, 15:28:11, 5:30:11, 11:32:11"

-- State Trash World Setting (Format ID:X:Y)
TrashWorldEnabled = true
MinTrashToDrop = 50
TrashWorld = "TRASHWORLD"
TrashDoor = ""
CustomTrashCoords = "4:35:11, 10:37:11, 14:39:11"

-- State Auto Pick Setting
AutoPickEnabled = false
AutoFind_Enabled = true

PickDoor_Enabled = false
PickDoor_World = ""
PickDoor_Door = ""
PickDoor_ID = 0

PickWL_Enabled = false
PickWL_World = ""
PickWL_Door = ""
PickWL_ID = 242

PickPlat_Enabled = false
PickPlat_World = StoragePlatWorld
PickPlat_Door = StoragePlatDoor
PickPlat_ID = PlatformID

-- State Random World DF
UseRandomDF = false
RandLength = 5
RandWithNumber = false

math.randomseed(os.time())

-- Parser Koordinat Presisi (Format: ID:X:Y)
local function parseCoordMap(str)
    local map = {}
    for entry in tostring(str):gmatch("[^,%s]+") do
        local id, x, y = entry:match("(%d+):(%d+):(%d+)")
        if id and x and y then
            map[tonumber(id)] = { x = tonumber(x), y = tonumber(y) }
        end
    end
    return map
end

local function generateRandomWorld(length, withNum)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if withNum then chars = chars .. "0123456789" end
    local res = ""
    for i = 1, (length or 5) do
        local rand = math.random(1, #chars)
        res = res .. chars:sub(rand, rand)
    end
    return res
end

local function safeTile(x, y)
    local ok, tile = pcall(getTile, x, y)
    if ok and tile then return tile end
    return { x = x, y = y, fg = 0, bg = 0, readyharvest = false, extra = nil }
end

local function safeGetWorldName()
    local ok, name = pcall(getWorldName)
    if ok and name and name ~= "" then return name end
    local ok2, name2 = pcall(GetWorldName)
    if ok2 and name2 and name2 ~= "" then return name2 end
    return ""
end

local function safeGetObjectList()
    local ok, list = pcall(getObjectList)
    if ok and type(list) == "table" then return list end
    return {}
end

local function safeGetInventory()
    local ok, invList = pcall(getInventory)
    if ok and type(invList) == "table" then return invList end
    return {}
end

local function safeGetTiles()
    local ok, tiles = pcall(getTiles)
    if ok and type(tiles) == "table" then return tiles end
    return {}
end

function warp(worldName, doorId)
    if not worldName or worldName == "" then return false end
    local target = worldName
    if doorId and doorId ~= "" then target = worldName .. "|" .. doorId end
    local ok, err = pcall(growtopia.warpTo, target)
    if not ok then
        LogToConsole("`4[`0Warp Error`4] " .. tostring(err))
        return false
    end
    return true
end

-- Wrapper Warp Cerdas (Mendukung WORLD|DOOR dan Input Door UI)
function warpDFWorld(worldEntry)
    if not worldEntry or worldEntry == "" then return false end
    local wName, dId = worldEntry:match("([^|]+)|?(.*)")
    if (dId == nil or dId == "") and DFWorldDoor ~= "" and not UseRandomDF then
        dId = DFWorldDoor
    end
    return warp(wName, dId)
end

-- Pembacaan Inventoris Universal
function inv(itemID)
    for _, item in pairs(safeGetInventory()) do
        if item then
            local id = item.id or item.itemid or item.item_id
            if id == itemID then 
                return item.amount or 0 
            end
        end
    end
    return 0
end

-- Fungsi Jalan Pintar (Menunggu Karakter Tiba Sebelum Aksi)
function walkTo(targetX, targetY, timeoutMs)
    timeoutMs = timeoutMs or 3000
    local p = getLocal()
    if not p or not p.posX or not p.posY then return false end

    local curX = p.posX // 32
    local curY = p.posY // 32

    -- Jika sudah berada di jarak aman (<= 3 tile), langsung anggap sukses
    if math.abs(curX - targetX) <= 3 and math.abs(curY - targetY) <= 3 then
        return true
    end

    FindPath(targetX, targetY)

    local elapsed = 0
    while autoDF_running and elapsed < timeoutMs do
        Sleep(100)
        elapsed = elapsed + 100
        local pl = getLocal()
        if pl and pl.posX and pl.posY then
            local px = pl.posX // 32
            local py = pl.posY // 32
            if math.abs(px - targetX) <= 3 and math.abs(py - targetY) <= 3 then
                return true
            end
        end
    end
    return false
end

-- Pukulan Aman dengan Validasi Jarak & Movement Synchronizer
function tnjk1_3(x, y)
    if not EnableBreak or not autoDF_running then return end
    
    if not walkTo(x, y, 3000) then return end

    local p = getLocal()
    if not p or not p.posX or not p.posY then return end

    local px, py = p.posX, p.posY
    for i = 1, (HitCount or 1) do
        sendPacketRaw(false, { type = 3, state = 2592, value = 18, x = x, y = y, px = px, py = py })
        Sleep(10)
    end
end

-- Pemasangan Aman dengan Validasi Jarak & Movement Synchronizer
function trh1_3(x, y, id)
    if not EnablePlace or not autoDF_running then return end
    
    if not walkTo(x, y, 3000) then return end

    local p = getLocal()
    if not p or not p.posX or not p.posY then return end

    local px, py = p.posX, p.posY
    sendPacketRaw(false, { type = 3, value = id, x = x, y = y, px = px, py = py })
end

function sdtr_11(object)
    if not object then return end
    local packet = {}
    packet.type = 11
    packet.value = object.id
    packet.x = object.posX
    packet.y = object.posY
    sendPacketRaw(false, packet)
end

function sdt_11(range)
    local localPlayer = getLocal()
    if not localPlayer then return end

    for _, object in pairs(safeGetObjectList()) do
        if object and math.abs(localPlayer.posX - object.posX) <= (32 * range) and
           math.abs(localPlayer.posY - object.posY) < (32 * range) and inv(object.itemid) < 200 then
            sdtr_11(object)
            Sleep(120)
        end
    end
end

function hasWorldLock()
    for _, tile in pairs(safeGetTiles()) do
        if tile and (tile.fg == WorldLockID or tile.bg == WorldLockID) then
            return true
        end
    end
    return false
end

function findMainDoor()
    for _, tile in pairs(safeGetTiles()) do
        if tile and (tile.fg == 6 or tile.fg == 2 or tile.fg == 3) then
            return tile.x, tile.y
        end
    end
    return 50, 29
end

function ensureSetupItems()
    if not autoDF_running then return end

    if #safeGetInventory() == 0 then
        Sleep(1500)
    end

    local currentWL = inv(WorldLockID)
    local currentDoor = inv(EntranceID)

    if currentWL == 0 or currentDoor < 2 then
        LogToConsole("`w[`0Setup`w] WL (" .. currentWL .. ") / Entrance (" .. currentDoor .. ") kurang. Restock ke Storage...")
        local currentWorld = safeGetWorldName()
        if currentWorld == "" then return end
        
        local targetStorageWorld = PickWL_World ~= "" and PickWL_World or PickDoor_World
        local targetStorageDoor = PickWL_Door ~= "" and PickWL_Door or PickDoor_Door

        if targetStorageWorld == "" then
            LogToConsole("`4[`0Setup Error`4] World Storage WL/Door belum diisi di menu Auto Pick!")
            return
        end

        warp(targetStorageWorld, targetStorageDoor)
        Sleep(6000)

        for _, object in pairs(safeGetObjectList()) do
            if not autoDF_running then return end
            if object and (object.itemid == WorldLockID or object.itemid == EntranceID) then
                walkTo(math.floor((object.posX + 8) / 32) - 1, math.floor(object.posY / 32), 3000)
                Sleep(500)
                sdtr_11(object)
                Sleep(500)
                if inv(WorldLockID) > 0 and inv(EntranceID) >= 2 then
                    break
                end
            end
        end

        warpDFWorld(currentWorld)
        Sleep(6000)
    end
end

function setupNewRandomWorld()
    if not autoDF_running then return false end
    if hasWorldLock() then
        LogToConsole("`4[`0Random World`4] World sudah dilock orang/punya WL, mencari world lain...")
        return false
    end

    ensureSetupItems()
    if not autoDF_running then return false end

    local doorX, doorY = findMainDoor()
    LogToConsole("`w[`0Setup`w] Memasang WL dan Entrance di sekitar Main Door...")

    if inv(WorldLockID) > 0 and safeTile(doorX, doorY - 1).fg == 0 then
        walkTo(doorX, doorY, 3000)
        Sleep(500)
        local timeout = 0
        while safeTile(doorX, doorY - 1).fg == 0 and inv(WorldLockID) > 0 and autoDF_running and timeout < 10 do
            trh1_3(doorX, doorY - 1, WorldLockID)
            Sleep(dpc)
            timeout = timeout + 1
        end
        Sleep(500)
    end

    local sidePositions = { doorX - 1, doorX + 1 }

    for _, targetX in ipairs(sidePositions) do
        if not autoDF_running then break end

        if safeTile(targetX, doorY).fg ~= 0 and safeTile(targetX, doorY).fg ~= EntranceID then
            walkTo(doorX, doorY, 3000)
            Sleep(300)
            local timeout = 0
            while safeTile(targetX, doorY).fg ~= 0 and autoDF_running and timeout < 20 do
                tnjk1_3(targetX, doorY)
                Sleep(dbk)
                timeout = timeout + 1
            end
        end

        if safeTile(targetX, doorY + 1).fg == 0 and inv(2) > 0 then
            trh1_3(targetX, doorY + 1, 2)
            Sleep(dpc)
        end

        if inv(EntranceID) > 0 and safeTile(targetX, doorY).fg ~= EntranceID then
            walkTo(doorX, doorY, 3000)
            Sleep(300)
            local timeout = 0
            while safeTile(targetX, doorY).fg ~= EntranceID and inv(EntranceID) > 0 and autoDF_running and timeout < 10 do
                trh1_3(targetX, doorY, EntranceID)
                Sleep(dpc)
                timeout = timeout + 1
            end
            Sleep(300)
        end
    end

    return true
end

function processAutoDropAndTrash()
    if not autoDF_running then return end
    local currentWorld = safeGetWorldName()
    if currentWorld == "" then return end

    if TrashWorldEnabled and TrashWorld ~= "" then
        local trashMap = parseCoordMap(CustomTrashCoords)
        for trashID, pos in pairs(trashMap) do
            if not autoDF_running then return end
            local jmlTrash = inv(trashID)
            if jmlTrash >= MinTrashToDrop then
                warp(TrashWorld, TrashDoor)
                Sleep(6000)
                walkTo(pos.x, pos.y, 4000)
                Sleep(1000)
                sendPacket(2, "action|drop\nitemID|" .. trashID)
                Sleep(100)
                sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. trashID .. "|\ncount|" .. jmlTrash)
                Sleep(2000)
                warpDFWorld(currentWorld)
                Sleep(6000)
            end
        end
    end

    if AutoDropEnabled and DropWorld ~= "" then
        local dropMap = parseCoordMap(CustomDropCoords)
        for id, pos in pairs(dropMap) do
            if not autoDF_running then return end
            local jml = inv(id)
            if jml >= MinToDrop then
                warp(DropWorld, DropDoor)
                Sleep(6000)
                walkTo(pos.x, pos.y, 4000)
                Sleep(1000)
                sendPacket(2, "action|drop\nitemID|" .. id)
                Sleep(100)
                sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "|\ncount|" .. jml)
                Sleep(2000)
                warpDFWorld(currentWorld)
                Sleep(6000)
            end
        end
    end
end

function processAutoPick()
    if not AutoPickEnabled or not autoDF_running then return end
    if AutoFind_Enabled then
        sdt_11(10)
    end
end

function findEmptyTile(radius)
    local p = getLocal()
    if not p or not p.posX or not p.posY then return nil end
    local px = p.posX // 32
    local py = p.posY // 32

    for x = -radius, radius do
        for y = -radius, radius do
            local tx = px + x
            local ty = py + y
            local tile = safeTile(tx, ty)

            if tile ~= nil then
                local dropCount = 0
                for _, obj in pairs(safeGetObjectList()) do
                    if obj then
                        local ox = math.floor((obj.posX + 8) / 32)
                        local oy = math.floor(obj.posY / 32)
                        if ox == tx and oy == ty then dropCount = dropCount + 1 end
                    end
                end

                if tile.fg == 0 and dropCount == 0 then
                    return { x = tx, y = ty }
                end
            end
        end
    end
    return nil
end

function cekSeed()
    if not autoDF_running then return end
    processAutoDropAndTrash()
    
    local dropMap = parseCoordMap(CustomDropCoords)
    local needDrop = false
    
    for id, _ in pairs(dropMap) do
        if inv(id) >= 190 then 
            needDrop = true 
            break 
        end
    end

    if needDrop and not AutoDropEnabled and worldsaveseed ~= "" and worldsaveseed ~= "PHINIS|DoorID" then
        Sleep(200)
        warp(worldsaveseed, "")
        Sleep(6000)
        for id, _ in pairs(dropMap) do
            if not autoDF_running then return end
            local jumlah = inv(id)
            if jumlah >= 100 then
                local emptyTile = findEmptyTile(5)
                if emptyTile ~= nil then
                    walkTo(emptyTile.x, emptyTile.y, 4000)
                    Sleep(1000)
                    sendPacket(2, "action|drop\nitemID|" .. id)
                    Sleep(100)
                    sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "|\ncount|" .. jumlah)
                    Sleep(2000)
                end
            end
        end
        warpDFWorld(nameworld)
        Sleep(6000)
    end
end

function smpng_12()
    local function clearColumn(column)
        for tiley = 24, 53 do
            if not autoDF_running then return end
            if safeTile(column, tiley).bg == 14 or safeTile(column + 1, tiley).bg == 14 then
                walkTo(column, tiley - 1, 4000)
                local timeout = 0
                while (safeTile(column, tiley).bg == 14 and autoDF_running and timeout < 20) do
                    tnjk1_3(column, tiley)
                    Sleep(dbk)
                    timeout = timeout + 1
                end
                timeout = 0
                while (safeTile(column + 1, tiley).bg == 14 and autoDF_running and timeout < 20) do
                    tnjk1_3(column + 1, tiley)
                    Sleep(dbk)
                    timeout = timeout + 1
                end
                processAutoPick()
            end
            cekSeed()
            processAutoPick()
        end
    end
    clearColumn(0)
    clearColumn(98)
end

function plfS_15()
    if not autoDF_running then return end
    if inv(PlatformID) < 52 then
        Sleep(2000)
        warp(StoragePlatWorld, StoragePlatDoor)
        Sleep(6000)
        
        local attempts = 0
        while inv(PlatformID) < 52 and autoDF_running and attempts < 10 do
            local foundAny = false
            for _, object in pairs(safeGetObjectList()) do
                if not autoDF_running then return end
                if object and object.itemid == PlatformID then
                    foundAny = true
                    walkTo(math.floor((object.posX + 8) / 32) - 1, math.floor(object.posY / 32), 3000)
                    Sleep(1000)
                    sdtr_11(object)
                    Sleep(500)
                    if inv(PlatformID) >= 52 then break end
                end
            end
            if not foundAny then
                attempts = attempts + 1
            end
            Sleep(1000)
        end
        
        warpDFWorld(nameworld)
        Sleep(6000)
    end

    for tiley = 2, 52, 2 do
        if not autoDF_running then return end
        if safeTile(1, tiley).fg == 0 then
            walkTo(0, tiley, 3000)
            Sleep(200)
            local timeout = 0
            while safeTile(1, tiley).fg == 0 and autoDF_running and timeout < 10 do
                trh1_3(1, tiley, PlatformID)
                Sleep(dpc)
                timeout = timeout + 1
            end
        end
    end

    for tiley = 2, 52, 2 do
        if not autoDF_running then return end
        if safeTile(98, tiley).fg == 0 then
            walkTo(99, tiley, 3000)
            Sleep(200)
            local timeout = 0
            while safeTile(98, tiley).fg == 0 and autoDF_running and timeout < 10 do
                trh1_3(98, tiley, PlatformID)
                Sleep(dpc)
                timeout = timeout + 1
            end
        end
    end

    Sleep(1000)
    sendPacket(2, "action|respawn")
    Sleep(4000)
end

function clrd_down_15()
    for tiley = 27, 51, 12 do
        if not autoDF_running then return end
        for tilex = 2, 97, 1 do
            if not autoDF_running then return end
            if safeTile(tilex, tiley - 2).bg ~= 0 or safeTile(tilex, tiley).bg ~= 0 or safeTile(tilex, tiley + 2).bg ~= 0 then
                walkTo(tilex - 1, tiley, 3000)
                Sleep(200)
                for i = -2, 2, 2 do
                    local timeout = 0
                    while safeTile(tilex, tiley + i).bg ~= 0 and autoDF_running and timeout < 20 do
                        tnjk1_3(tilex, tiley + i)
                        Sleep(dbk)
                        timeout = timeout + 1
                    end
                    processAutoPick()
                end
                cekSeed()
                processAutoPick()
            end
        end
    end
end

function brkLv_12()
    for _, tile in pairs(safeGetTiles()) do
        if not autoDF_running then return end
        if tile and tile.fg == 4 then
            walkTo(tile.x, tile.y - 1, 3000)
            Sleep(200)
            local timeout = 0
            while safeTile(tile.x, tile.y).fg == 4 and autoDF_running and timeout < 20 do
                tnjk1_3(tile.x, tile.y)
                Sleep(dbk)
                timeout = timeout + 1
            end
            processAutoPick()
            if safeTile(tile.x, tile.y).fg == 0 and autoDF_running and inv(2) > 0 then
                trh1_3(tile.x, tile.y, 2)
                Sleep(dpc)
            end
        end
    end
end

function plcDrt_2()
    for tiley = 24, 2, -2 do
        if not autoDF_running then return end
        for tilex = 4, 98, 5 do
            if not autoDF_running then return end
            walkTo(tilex, tiley + 1, 3000)
            Sleep(300)
            for i = 1, 5 do
                local tx = (tilex - 3) + i
                if tx <= 98 and safeTile(tx, tiley).fg == 0 then
                    local retry = 0
                    while safeTile(tx, tiley).fg == 0 and inv(2) > 0 and autoDF_running and retry < 5 do
                        trh1_3(tx, tiley, 2)
                        Sleep(dpc)
                        retry = retry + 1
                    end
                end
            end
        end
    end
end

function isWorldAlreadyDone()
    for tiley = 2, 52, 2 do
        if safeTile(1, tiley).fg == 0 or safeTile(98, tiley).fg == 0 then return false end
    end
    return true
end

function StopAll()
    autoDF_running = false
    pcall(function()
        sendPacket(2, "action|input\n|left|0\n|right|0\n|up|0\n|down|0")
        sendPacket(2, "action|input\n|space|0")
    end)
    LogToConsole("`w[`0Auto DF`w]`4 STOP DITEKAN! Pergerakan & pengerjaan dihentikan.")
end

function mainDF()
    if not autoDF_running then return end
    if not nameworld or nameworld == "" then return end

    warpDFWorld(nameworld)
    Sleep(6000)
    LogToConsole("`w[`0Auto DF`w] Masuk world: " .. tostring(nameworld))
    Sleep(2000)

    if UseRandomDF then
        local successSetup = setupNewRandomWorld()
        if not successSetup then 
            Sleep(3000)
            return 
        end
    end

    if not autoDF_running then return end
    if isWorldAlreadyDone() then return end
    smpng_12()
    if not autoDF_running then return end
    plfS_15()
    if not autoDF_running then return end
    clrd_down_15()
    if not autoDF_running then return end
    brkLv_12()
    if not autoDF_running then return end
    plcDrt_2()
    if not autoDF_running then return end

    writeToLocal("finished_df.txt", os.date("[%Y-%m-%d %H:%M] ") .. nameworld .. "\n")
    LogToConsole("`w[`2SUCCESS`w] World " .. nameworld .. " selesai & dicatat ke finished_df.txt!")

    sendPacket(2, "action|respawn")
    Sleep(3000)
end

function LoopMultiWorld()
    while autoDF_running do
        if UseRandomDF then
            nameworld = generateRandomWorld(RandLength, RandWithNumber)
        else
            if index_world > #Config.World.nameworld then index_world = 1 end
            nameworld = Config.World.nameworld[index_world]
        end

        if nameworld then
            mainDF()
        end

        if not autoDF_running then return end
        if not UseRandomDF then
            index_world = index_world + 1
            if index_world > #Config.World.nameworld then index_world = 1 end
        end
        Sleep(2000)
    end
end

-- ==========================================
-- ITEM ID FINDER DIALOG HANDLER
-- ==========================================
function openItemFinderDialog()
    local dialogInput = {}
    dialogInput.v1 = "OnDialogRequest"
    dialogInput.v2 = [[
OnDialogRequest
set_default_color|`b
add_label_with_icon|big|`bFind `eId Item|left|12168|
add_smalltext|`eScript By Freazd|
add_spacer|small|
add_item_picker|idt|`eSelect `wOne of the Items |`eSelect an item to find the ID :|
add_spacer|small|
add_button|back_menu|BACK|noflags|0|0|
add_quick_exit|
end_dialog|picker|||
]]
    sendVariant(dialogInput)
end

function handleItemPickerResponse(type_pkt, pkt)
    if type(pkt) ~= "string" then return false end
    if pkt:find("dialog_name|picker") or pkt:find("dialog_name|jjds") then
        local btn = pkt:match("buttonClicked|([%w_]+)")
        if btn == "back_menu" then
            openMainMenu()
            return true
        end
    end

    if pkt:find("idt|(%d+)") then
        local pick = pkt:match("idt|(%d+)")
        local itemInfo = nil
        if type(getItemInfoManager) == "function" then
            local ok, mgr = pcall(getItemInfoManager)
            if ok and mgr and type(mgr.getItemInfoByID) == "function" then
                itemInfo = mgr:getItemInfoByID(tonumber(pick))
            end
        end
        local nam1 = itemInfo and itemInfo.name or ("Unknown Item " .. tostring(pick))
        local dialogInput = {}
        dialogInput.v1 = "OnDialogRequest"
        dialogInput.v2 = [[
OnDialogRequest
set_default_color|`b
add_label_with_icon|big|`bFound `eItem ID|left|13818|
add_smalltext|`eScript By Freazd|
add_spacer|small|
add_button_with_icon|p|`wItem icon|staticBlueFrames|]] .. pick .. [[||
add_label_with_icon|small|`wItem Name : `e]] .. nam1 .. [[|left|2946|
add_label_with_icon|small|`wItem ID : `e]] .. pick .. [[|left|2946|
add_spacer|small|
add_item_picker|idt|`eFind `wMore?|`eSelect an item to find the ID :|
add_button|back_menu|BACK|noflags|0|0|
add_quick_exit|
end_dialog|jjds|||
]]
        sendVariant(dialogInput)
        return true
    end
    return false
end

function openMainMenu()
    sendVariant({
        v1 = "OnDialogRequest",
        v2 = table.concat({
            "set_default_color|`b",
            "add_label_with_icon|big|`bHelper `eWorld|left|242|",
            "add_smalltext|`eScript By Freazd|",
            "add_spacer|small|",
            "add_button_with_icon|open_autodf|Auto Dirt Farm|staticBlueFrames|2||",
            "add_button_with_icon|open_itemfinder|Find Id Item|staticBlueFrames|12168||",
            "add_quick_exit|",
            "end_dialog|freazd_menu|||"
        }, "\n")
    })
end

function handleMenuDialog(type_pkt, pkt)
    if type(pkt) ~= "string" then return false end
    if pkt:find("dialog_name|freazd_menu") then
        local btn = pkt:match("buttonClicked|([%w_]+)")
        if btn == "open_itemfinder" then
            openItemFinderDialog()
        end
        return true
    end
    return false
end

-- ==========================================
-- GROWLAUNCHER MODULE UI (JSON NATIVE)
-- ==========================================
local module_json = [[
{
    "sub_name": "Helper World (DF)",
    "icon": "Verified",
    "menu": [
        {
            "type": "labelapp",
            "icon": "Verified",
            "text": "Script By Freazd"
        },
        {
            "type": "divider"
        },
        {
            "type": "dialog",
            "text": "Autofarm Setting",
            "support_text": "Settings for autofarm",
            "fill": true,
            "menu": [
                {
                    "type": "input_string",
                    "text": "List World",
                    "default": "CONCG,MLJEG,JVHXP,IIGNV,YCRRU,JSVMB,BIPKC",
                    "icon": "Edit",
                    "alias": "autodf_worldlist"
                },
                {
                    "type": "input_string",
                    "text": "List World Door ID (Opsional)",
                    "default": "",
                    "icon": "Edit",
                    "alias": "autodf_worlddoor"
                },
                {
                    "type": "toggle",
                    "text": "Random World (Auto DF)",
                    "default": false,
                    "alias": "autodf_use_random"
                },
                {
                    "type": "slider",
                    "text": "Random Length",
                    "min": 1,
                    "max": 12,
                    "default": 5,
                    "alias": "rand_length"
                },
                {
                    "type": "toggle",
                    "text": "With Number (Angka)",
                    "default": false,
                    "alias": "rand_with_number"
                },
                {
                    "type": "divider"
                },
                {
                    "type": "toggle",
                    "text": "Verify before punch",
                    "default": false,
                    "alias": "verify_punch"
                },
                {
                    "type": "toggle",
                    "text": "Break",
                    "default": true,
                    "alias": "enable_break"
                },
                {
                    "type": "toggle",
                    "text": "Place",
                    "default": true,
                    "alias": "enable_place"
                },
                {
                    "type": "slider",
                    "text": "Hit Count",
                    "min": 1,
                    "max": 40,
                    "default": 1,
                    "alias": "hit_count"
                },
                {
                    "type": "input_int",
                    "text": "Delay Break",
                    "default": "220",
                    "label": "ms",
                    "placeholder": "millisecond",
                    "icon": "Verified",
                    "alias": "autodf_delaybreak"
                },
                {
                    "type": "input_int",
                    "text": "Delay Place",
                    "default": "120",
                    "label": "ms",
                    "placeholder": "millisecond",
                    "icon": "Verified",
                    "alias": "autodf_delayplace"
                }
            ]
        },
        {
            "type": "toggle_button",
            "text": "Start Autofarm",
            "default": false,
            "alias": "btn_autodf"
        },
        {
            "type": "toggle",
            "text": "📍 Cek Posisi Saya Sekarang (Console Log)",
            "default": false,
            "alias": "toggle_pos_check"
        },
        {
            "type": "divider"
        },
        {
            "type": "dialog",
            "text": "Auto drop Setting",
            "support_text": "Settings for auto drop",
            "fill": true,
            "menu": [
                {
                    "type": "toggle",
                    "text": "Auto drop",
                    "default": false,
                    "alias": "autodrop_toggle"
                },
                {
                    "type": "input_int",
                    "text": "Minimum to drop",
                    "default": "190",
                    "label": "items",
                    "placeholder": "Minimum items",
                    "icon": "Verified",
                    "alias": "min_to_drop"
                },
                {
                    "type": "input_string",
                    "text": "World to drop",
                    "default": "SDZRR",
                    "icon": "Edit",
                    "alias": "drop_world"
                },
                {
                    "type": "input_string",
                    "text": "Door to drop",
                    "default": "",
                    "icon": "Edit",
                    "alias": "drop_door"
                },
                {
                    "type": "input_string",
                    "text": "Drop Coords (ID:X:Y)",
                    "default": "3:26:11, 15:28:11, 5:30:11, 11:32:11",
                    "icon": "Edit",
                    "alias": "custom_drop_coords"
                }
            ]
        },
        {
            "type": "divider"
        },
        {
            "type": "dialog",
            "text": "Trash World Setting",
            "support_text": "Settings for trash items drop",
            "fill": true,
            "menu": [
                {
                    "type": "toggle",
                    "text": "Trash to World",
                    "default": true,
                    "alias": "trash_world_toggle"
                },
                {
                    "type": "input_int",
                    "text": "Min to Trash Drop",
                    "default": "50",
                    "label": "items",
                    "placeholder": "Minimum items",
                    "icon": "Verified",
                    "alias": "min_trash_drop"
                },
                {
                    "type": "input_string",
                    "text": "Trash World Name",
                    "default": "TRASHWORLD",
                    "icon": "Edit",
                    "alias": "trash_world"
                },
                {
                    "type": "input_string",
                    "text": "Trash Door ID",
                    "default": "",
                    "icon": "Edit",
                    "alias": "trash_door"
                },
                {
                    "type": "input_string",
                    "text": "Trash Coords (ID:X:Y)",
                    "default": "4:35:11, 10:37:11, 14:39:11",
                    "icon": "Edit",
                    "alias": "custom_trash_coords"
                }
            ]
        },
        {
            "type": "divider"
        },
        {
            "type": "dialog",
            "text": "Auto pick Setting",
            "support_text": "Settings for auto pick",
            "fill": true,
            "menu": [
                {
                    "type": "toggle",
                    "text": "Auto pick (Global)",
                    "default": false,
                    "alias": "autopick_toggle"
                },
                {
                    "type": "toggle",
                    "text": "Mode: Auto find",
                    "default": true,
                    "alias": "autofind_toggle"
                },
                {
                    "type": "divider"
                },
                {
                    "type": "toggle",
                    "text": "Pick Door Entrance",
                    "default": false,
                    "alias": "pick_door_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Door World Name",
                    "default": "",
                    "icon": "Edit",
                    "alias": "pick_door_world"
                },
                {
                    "type": "input_string",
                    "text": "Door ID / Door Name",
                    "default": "",
                    "icon": "Edit",
                    "alias": "pick_door_doorid"
                },
                {
                    "type": "input_int",
                    "text": "Door Item ID",
                    "default": "0",
                    "label": "ID",
                    "placeholder": "Item ID",
                    "icon": "Verified",
                    "alias": "pick_door_id"
                },
                {
                    "type": "divider"
                },
                {
                    "type": "toggle",
                    "text": "Pick World Lock",
                    "default": false,
                    "alias": "pick_wl_toggle"
                },
                {
                    "type": "input_string",
                    "text": "WL World Name",
                    "default": "",
                    "icon": "Edit",
                    "alias": "pick_wl_world"
                },
                {
                    "type": "input_string",
                    "text": "WL Door ID",
                    "default": "",
                    "icon": "Edit",
                    "alias": "pick_wl_doorid"
                },
                {
                    "type": "input_int",
                    "text": "WL Item ID",
                    "default": "242",
                    "label": "ID",
                    "placeholder": "Item ID",
                    "icon": "Verified",
                    "alias": "pick_wl_id"
                },
                {
                    "type": "divider"
                },
                {
                    "type": "toggle",
                    "text": "Pick Platform",
                    "default": false,
                    "alias": "pick_plat_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Plat World Name",
                    "default": "PHINIS",
                    "icon": "Edit",
                    "alias": "pick_plat_world"
                },
                {
                    "type": "input_string",
                    "text": "Plat Door ID",
                    "default": "DoorID",
                    "icon": "Edit",
                    "alias": "pick_plat_doorid"
                },
                {
                    "type": "input_int",
                    "text": "Plat Item ID",
                    "default": "102",
                    "label": "ID",
                    "placeholder": "Item ID",
                    "icon": "Verified",
                    "alias": "pick_plat_id"
                }
            ]
        },
        {
            "type": "divider"
        },
        {
            "type": "button",
            "text": "Buka Item ID Finder",
            "alias": "btn_itemfinder"
        }
    ]
}
]]

-- Registrasi Module UI Growlauncher
addIntoModule(module_json)

function onValue(type_evt, name, value)
    if name == "autodf_worldlist" then
        local worlds = {}
        for w in tostring(value):gmatch("[^,%s]+") do table.insert(worlds, w) end
        if #worlds > 0 then 
            Config.World.nameworld = worlds 
            if index_world > #Config.World.nameworld then index_world = 1 end
        end
    elseif name == "autodf_worlddoor" then DFWorldDoor = tostring(value)
    elseif name == "autodf_use_random" then UseRandomDF = value
    elseif name == "rand_length" then RandLength = tonumber(value) or 5
    elseif name == "rand_with_number" then RandWithNumber = value
    elseif name == "verify_punch" then VerifyPunch = value
    elseif name == "enable_break" then EnableBreak = value
    elseif name == "enable_place" then EnablePlace = value
    elseif name == "hit_count" then HitCount = tonumber(value) or 1
    elseif name == "autodf_delaybreak" then dbk = tonumber(value) or dbk
    elseif name == "autodf_delayplace" then dpc = tonumber(value) or dpc
    
    elseif name == "toggle_pos_check" then
        if value then
            local p = getLocal()
            if p and p.posX and p.posY then
                local tx = p.posX // 32
                local ty = p.posY // 32
                local t = safeTile(tx, ty)
                LogToConsole("`w[`0POSISI REALTIME`w] `2X=" .. tx .. " Y=" .. ty .. " | FG=" .. t.fg .. " BG=" .. t.bg)
            else
                LogToConsole("`4[`0Error`4] Posisi player tidak ditemukan!")
            end
        end

    elseif name == "autodrop_toggle" then AutoDropEnabled = value
    elseif name == "min_to_drop" then MinToDrop = tonumber(value) or 190
    elseif name == "drop_world" then DropWorld = tostring(value)
    elseif name == "drop_door" then DropDoor = tostring(value)
    elseif name == "custom_drop_coords" then CustomDropCoords = tostring(value)

    elseif name == "trash_world_toggle" then TrashWorldEnabled = value
    elseif name == "min_trash_drop" then MinTrashToDrop = tonumber(value) or 50
    elseif name == "trash_world" then TrashWorld = tostring(value)
    elseif name == "trash_door" then TrashDoor = tostring(value)
    elseif name == "custom_trash_coords" then CustomTrashCoords = tostring(value)
    
    elseif name == "autopick_toggle" then AutoPickEnabled = value
    elseif name == "autofind_toggle" me AutoFind_Enabled = value
    
    elseif name == "pick_door_toggle" then PickDoor_Enabled = value
    elseif name == "pick_door_world" then PickDoor_World = tostring(value)
    elseif name == "pick_door_doorid" then PickDoor_Door = tostring(value)
    elseif name == "pick_door_id" then PickDoor_ID = tonumber(value) or 0
    
    elseif name == "pick_wl_toggle" then PickWL_Enabled = value
    elseif name == "pick_wl_world" then PickWL_World = tostring(value)
    elseif name == "pick_wl_doorid" then PickWL_Door = tostring(value)
    elseif name == "pick_wl_id" then PickWL_ID = tonumber(value) or 242
    
    elseif name == "pick_plat_toggle" then PickPlat_Enabled = value
    elseif name == "pick_plat_world" then PickPlat_World = tostring(value)
    elseif name == "pick_plat_doorid" then PickPlat_Door = tostring(value)
    elseif name == "pick_plat_id" then PickPlat_ID = tonumber(value) or PlatformID
    
    elseif name == "btn_itemfinder" then openItemFinderDialog()
    
    elseif name == "btn_autodf" then
        autoDF_running = value
        if value == true then
            LogToConsole("`w[`0Auto DF`w] Konfigurasi aman & siap dikerjakan!")
        else
            StopAll()
        end
    end
end
addHook(onValue, "onValue")

function onSendPacket(type_pkt, pkt)
    if handleItemPickerResponse(type_pkt, pkt) then return true end
    if handleMenuDialog(type_pkt, pkt) then return true end
    return false
end
addHook(onSendPacket, "onSendPacket")
applyHook()

sendVariant({v1 = "OnTextOverlay", v2 = "`9Script DF `wCreated By `9Freazd"})

runCoroutine(function()
    while true do
        if autoDF_running then
            LoopMultiWorld()
        else
            Sleep(300)
        end
    end
end)

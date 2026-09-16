Config = {
    World = {
        nameworld = {"CONCG", "MLJEG", "JVHXP", "IIGNV", "YCRRU", "JSVMB", "BIPKC"},
        StoragePlatWorld = "PHINIS",
        StoragePlatDoor = "DoorID",
        worldsaveseed = "PHINIS|DoorID"
     },

    DelaySettings = {
        DELAY_PLACE = 80,
        DELAY_BREAK = 180
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

TrashID = {2, 14, 4, 10}
SeedID = {3, 15, 5, 11}
PlatformID = 102
WorldLockID = 242
EntranceID = 6

-- State / Status Fitur Utama
autoDF_running = false
CW_running = false

-- State Pengaturan Autofarm
EnableBreak = true
EnablePlace = true
HitCount = 1
VerifyPunch = false

-- State Auto Drop Setting
AutoDropEnabled = false
MinToDrop = 190
DropPosX = 26
DropPosY = 11
DropWorld = "SDZRR"

-- State Auto Pick Setting & Storage Backup
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

-- State Random World
UseRandomDF = false
UseRandomCW = false
RandLength = 5
RandWithNumber = false

math.randomseed(os.time())

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

function inv(itemID)
    for _, item in pairs(safeGetInventory()) do
        if item and item.id == itemID then return item.amount end
    end
    return 0
end

local function getLocalPos()
    local p = getLocal()
    if not p then return 0, 0 end
    return p.posX or 0, p.posY or 0
end

function tnjk1_3(x, y)
    if not EnableBreak then return end
    local px, py = getLocalPos()
    for i = 1, (HitCount or 1) do
        sendPacketRaw(false, { type = 3, state = 2592, value = 18, px = x, py = y, x = px, y = py })
        Sleep(10)
    end
end

function trh1_3(x, y, id)
    if not EnablePlace then return end
    local px, py = getLocalPos()
    sendPacketRaw(false, { type = 3, value = id, px = x, py = y, x = px, y = py })
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
            Sleep(15)
        end
    end
end

function sdt_11_target(targetID, range)
    local localPlayer = getLocal()
    if not localPlayer then return end

    for _, object in pairs(safeGetObjectList()) do
        if object and object.itemid == targetID and
           math.abs(localPlayer.posX - object.posX) <= (32 * range) and
           math.abs(localPlayer.posY - object.posY) < (32 * range) and inv(object.itemid) < 200 then
            sdtr_11(object)
            Sleep(15)
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

-- Fungsi Ambil Setup Item (WL & Entrance) dari World Storage yang diinput user
function ensureSetupItems()
    if inv(WorldLockID) == 0 or inv(EntranceID) == 0 then
        LogToConsole("`w[`0Setup`w] Item WL/Entrance kurang, mengambil ke Storage...")
        local currentWorld = safeGetWorldName()
        
        local targetStorageWorld = PickWL_World ~= "" and PickWL_World or PickDoor_World
        local targetStorageDoor = PickWL_Door ~= "" and PickWL_Door or PickDoor_Door

        if targetStorageWorld == "" then
            LogToConsole("`4[`0Setup Error`4] World Storage WL/Door belum diisi di menu Auto Pick!")
            return
        end

        warp(targetStorageWorld, targetStorageDoor)
        Sleep(4000)

        for _, object in pairs(safeGetObjectList()) do
            if object and (object.itemid == WorldLockID or object.itemid == EntranceID) then
                FindPath(math.floor((object.posX + 8) / 32) - 1, math.floor(object.posY / 32))
                Sleep(500)
                sdtr_11(object)
                Sleep(500)
                if inv(WorldLockID) > 0 and inv(EntranceID) > 0 then
                    break
                end
            end
        end

        warp(currentWorld, "")
        Sleep(4000)
    end
end

function setupNewRandomWorld()
    if hasWorldLock() then
        LogToConsole("`4[`0Random World`4] World sudah dilock orang/punya WL, mencari world lain...")
        return false
    end

    ensureSetupItems()

    local doorX, doorY = findMainDoor()
    LogToConsole("`w[`0Setup`w] Memasang WL dan Entrance di sekitar Main Door...")

    if inv(WorldLockID) > 0 and safeTile(doorX, doorY - 1).fg == 0 then
        FindPath(doorX, doorY)
        Sleep(500)
        trh1_3(doorX, doorY - 1, WorldLockID)
        Sleep(1000)
    end

    if inv(EntranceID) > 0 then
        if safeTile(doorX - 1, doorY).fg == 0 then
            trh1_3(doorX - 1, doorY, EntranceID)
            Sleep(500)
        end
        if safeTile(doorX + 1, doorY).fg == 0 then
            trh1_3(doorX + 1, doorY, EntranceID)
            Sleep(500)
        end
    end

    return true
end

function processAutoDropAndTrash()
    for _, trashID in ipairs(TrashID) do
        local jmlTrash = inv(trashID)
        if jmlTrash >= 50 then
            sendPacket(2, "action|trash\n|itemID|" .. trashID)
            Sleep(1000)
            sendPacket(2, "action|dialog_return\ndialog_name|trash_item\nitemID|" .. trashID .. "|\ncount|" .. jmlTrash)
            Sleep(1000)
        end
    end

    if AutoDropEnabled then
        for _, id in pairs(SeedID) do
            local jml = inv(id)
            if jml >= MinToDrop then
                local currentWorld = safeGetWorldName()
                warp(DropWorld, "")
                Sleep(5000)
                FindPath(DropPosX, DropPosY)
                Sleep(1000)
                sendPacket(2, "action|drop\n|itemID|" .. id)
                Sleep(100)
                sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "|\ncount|" .. jml)
                Sleep(2000)
                warp(currentWorld, "")
                Sleep(5000)
            end
        end
    end
end

function processAutoPick()
    if not AutoPickEnabled then return end
    local currentWorld = safeGetWorldName()

    if AutoFind_Enabled then
        sdt_11(10)
    end

    if PickDoor_Enabled and PickDoor_ID > 0 and PickDoor_World ~= "" then
        if currentWorld ~= PickDoor_World then
            warp(PickDoor_World, PickDoor_Door)
            Sleep(4000)
        end
        sdt_11_target(PickDoor_ID, 10)
    end

    if PickWL_Enabled and PickWL_ID > 0 and PickWL_World ~= "" then
        if currentWorld ~= PickWL_World then
            warp(PickWL_World, PickWL_Door)
            Sleep(4000)
        end
        sdt_11_target(PickWL_ID, 10)
    end

    if PickPlat_Enabled and PickPlat_ID > 0 and PickPlat_World ~= "" then
        if currentWorld ~= PickPlat_World then
            warp(PickPlat_World, PickPlat_Door)
            Sleep(4000)
        end
        sdt_11_target(PickPlat_ID, 10)
    end
end

function findEmptyTile(radius)
    local px = getLocal().posX // 32
    local py = getLocal().posY // 32

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

                if tile.fg == 0 and tile.bg == 0 and dropCount == 0 then
                    return { x = tx, y = ty }
                end
            end
        end
    end
    return nil
end

function cekSeed()
    processAutoDropAndTrash()
    local needDrop = false
    for _, id in pairs(SeedID) do
        if inv(id) >= 100 then needDrop = true break end
    end

    if needDrop and not AutoDropEnabled then
        Sleep(200)
        warp(worldsaveseed, "")
        Sleep(6000)
        for _, id in pairs(SeedID) do
            local jumlah = inv(id)
            if jumlah >= 100 then
                local emptyTile = findEmptyTile(5)
                if emptyTile ~= nil then
                    FindPath(emptyTile.x, emptyTile.y)
                    Sleep(1000)
                    sendPacket(2, "action|drop\n|itemID|" .. id)
                    Sleep(100)
                    sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "|\ncount|" .. jumlah)
                    Sleep(2000)
                end
            end
        end
        warp(nameworld, "")
        Sleep(6000)
    end
end

function smpng_12()
    local function clearColumn(column)
        for tiley = 24, 53 do
            if safeTile(column, tiley).bg == 14 or safeTile(column + 1, tiley).bg == 14 then
                FindPath(column, tiley - 1)
                Sleep(1000)
                while safeTile(column, tiley).bg == 14 do tnjk1_3(column, tiley) Sleep(dbk) end
                while safeTile(column + 1, tiley).bg == 14 do tnjk1_3(column + 1, tiley) Sleep(dbk) end
                processAutoPick()
            end
            cekSeed()
            processAutoPick()
        end
    end
    clearColumn(0)
    clearColumn(98)
end

function plfS_15(world)
    if inv(PlatformID) < 52 then
        Sleep(2000)
        warp(StoragePlatWorld, StoragePlatDoor)
        Sleep(4000)
        while inv(PlatformID) < 52 do
            for _, object in pairs(safeGetObjectList()) do
                if object and object.itemid == PlatformID then
                    FindPath(math.floor((object.posX + 8) / 32) - 1, math.floor(object.posY / 32))
                    Sleep(1000)
                    sdtr_11(object)
                    Sleep(500)
                    if inv(PlatformID) >= 52 then break end
                end
            end
        end
        warp(nameworld, "")
        Sleep(4000)
    end
    for tiley = 2, 52, 2 do
        if safeTile(1, tiley).fg == 0 then
            FindPath(0, tiley)
            Sleep(200)
            while safeTile(1, tiley).fg == 0 do trh1_3(1, tiley, PlatformID) Sleep(dpc) end
        end
    end
    for tiley = 2, 52, 2 do
        if safeTile(98, tiley).fg == 0 then
            FindPath(99, tiley)
            Sleep(200)
            while safeTile(98, tiley).fg == 0 do trh1_3(98, tiley, PlatformID) Sleep(dpc) end
        end
    end
    Sleep(1000)
    sendPacket(2, "action|respawn")
    Sleep(4000)
end

function clrd_down_15()
    for tiley = 27, 51, 12 do
        for tilex = 2, 97, 1 do
            if safeTile(tilex, tiley - 2).bg ~= 0 or safeTile(tilex, tiley).bg ~= 0 or safeTile(tilex, tiley + 2).bg ~= 0 then
                FindPath(tilex - 1, tiley)
                Sleep(200)
                for i = -2, 2, 2 do
                    while safeTile(tilex, tiley + i).bg ~= 0 do tnjk1_3(tilex, tiley + i) Sleep(dbk) end
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
        if tile and tile.fg == 4 then
            FindPath(tile.x, tile.y - 1)
            Sleep(200)
            while safeTile(tile.x, tile.y).fg == 4 do tnjk1_3(tile.x, tile.y) Sleep(dbk) end
            processAutoPick()
            if safeTile(tile.x, tile.y).fg == 0 then
                trh1_3(tile.x, tile.y, 2)
                Sleep(dpc)
            end
        end
    end
end

function plcDrt_2()
    for tiley = 24, 2, -2 do
        for tilex = 4, 98, 5 do
            FindPath(tilex, tiley + 1)
            Sleep(300)
            for i = 1, 5 do
                local tx = (tilex - 3) + i
                if tx <= 98 and safeTile(tx, tiley).fg == 0 then
                    while safeTile(tx, tiley).fg == 0 and inv(2) > 0 do
                        trh1_3(tx, tiley, 2)
                        Sleep(dpc)
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

function mainDF()
    if not autoDF_running then return end
    warp(nameworld, "")
    Sleep(4000)
    LogToConsole("`w[`0Auto DF`w] Masuk world: " .. nameworld)
    Sleep(2000)

    if UseRandomDF then
        local successSetup = setupNewRandomWorld()
        if not successSetup then return end
    end

    if isWorldAlreadyDone() then return end
    smpng_12()
    plfS_15()
    clrd_down_15()
    brkLv_12()
    plcDrt_2()
    sendPacket(2, "action|respawn")
    Sleep(3000)
end

function LoopMultiWorld()
    while autoDF_running do
        if UseRandomDF then
            nameworld = generateRandomWorld(RandLength, RandWithNumber)
        else
            nameworld = Config.World.nameworld[index_world]
        end
        mainDF()
        if not autoDF_running then return end
        if not UseRandomDF then
            index_world = index_world + 1
            if index_world > #Config.World.nameworld then index_world = 1 end
        end
        Sleep(2000)
    end
end

-- Clear World Logic
CW_DelayBreak = 180
CW_WorldList = {"WORLD1", "WORLD2", "WORLD3"}
CW_index_world = 1
CurrentCWWorld = ""

function mainCW()
    if not CW_running then return end
    warp(CurrentCWWorld, "")
    Sleep(4000)
    LogToConsole("`w[`0Clear World`w] Masuk world: " .. CurrentCWWorld)
    Sleep(2000)

    if UseRandomCW then
        local successSetup = setupNewRandomWorld()
        if not successSetup then return end
    end

    for y = 0, 53 do
        if not CW_running then return end
        for x = 0, 99 do
            if not CW_running then return end
            local tile = safeTile(x, y)
            if tile.bg ~= 0 or (tile.fg ~= 0 and tile.fg ~= 8) then
                while (safeTile(x, y).fg ~= 0 or safeTile(x, y).bg ~= 0) and CW_running do
                    tnjk1_3(x, y)
                    Sleep(CW_DelayBreak)
                end
            end
        end
    end
    sendPacket(2, "action|respawn")
    Sleep(3000)
end

function LoopClearWorld()
    while CW_running do
        if UseRandomCW then
            CurrentCWWorld = generateRandomWorld(RandLength, RandWithNumber)
        else
            CurrentCWWorld = CW_WorldList[CW_index_world]
        end

        mainCW()

        if not CW_running then return end
        if not UseRandomCW then
            CW_index_world = CW_index_world + 1
            if CW_index_world > #CW_WorldList then CW_index_world = 1 end
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

function handleItemPickerResponse(type, pkt)
    if pkt:find("dialog_name|picker") or pkt:find("dialog_name|jjds") then
        local btn = pkt:match("buttonClicked|([%w_]+)")
        if btn == "back_menu" then
            openMainMenu()
            return true
        end
    end

    if pkt:find("idt|(%d+)") then
        local pick = pkt:match("idt|(%d+)")
        local itemInfo = getItemInfoByID(tonumber(pick))
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
            "add_button_with_icon|open_cw|Auto Clear World|staticBlueFrames|2||",
            "add_button_with_icon|open_itemfinder|Find Id Item|staticBlueFrames|12168||",
            "add_quick_exit|",
            "end_dialog|freazd_menu|||"
        }, "\n")
    })
end

function handleMenuDialog(type, pkt)
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
-- STRUKTUR UI IMGUI
-- ==========================================
local ui = UserInterface.new("Helper World", "ImGui")

ui:addLabelApp("HELPER WORLD", "ImGui")
ui:addLabelApp("Script By Freazd", "ImGui")
ui:addDivider()

local dialog_autodf = ui:addDialog("Autofarm Setting", "Settings for autofarm", {})
ui:addChildInputString(dialog_autodf.menu, "List World", table.concat(Config.World.nameworld, ","), "world1,...", "Pisah koma", "World", "autodf_worldlist")
ui:addChildToggle(dialog_autodf.menu, "Random World (Auto DF)", UseRandomDF, "autodf_use_random")
ui:addChildSlider(dialog_autodf.menu, "Random Length", 1, 12, RandLength, 1, false, "rand_length")
ui:addChildToggle(dialog_autodf.menu, "With Number (Angka)", RandWithNumber, "rand_with_number")
ui:addDivider(dialog_autodf.menu)
ui:addChildToggle(dialog_autodf.menu, "Verify before punch", VerifyPunch, "verify_punch")
ui:addChildToggle(dialog_autodf.menu, "Break", EnableBreak, "enable_break")
ui:addChildToggle(dialog_autodf.menu, "Place", EnablePlace, "enable_place")
ui:addChildSlider(dialog_autodf.menu, "Hit Count", 1, 40, HitCount, 1, false, "hit_count")
ui:addChildInputInt(dialog_autodf.menu, "Delay Break", dbk, "ms", "millisecond", "Verified", "autodf_delaybreak")
ui:addChildInputInt(dialog_autodf.menu, "Delay Place", dpc, "ms", "millisecond", "Verified", "autodf_delayplace")
ui:addDivider()
ui:addToggleButton("Start Autofarm", false, "btn_autodf")

ui:addDivider()

local dialog_cw = ui:addDialog("Set Auto Clear World", "Setting Auto Clear World", {})
ui:addChildInputString(dialog_cw.menu, "List World", table.concat(CW_WorldList, ","), "world1,world2,...", "Pisah koma", "World", "cw_worldlist")
ui:addChildToggle(dialog_cw.menu, "Random World (Clear World)", UseRandomCW, "cw_use_random")
ui:addChildSlider(dialog_cw.menu, "Random Length", 1, 12, RandLength, 1, false, "rand_length_cw")
ui:addChildToggle(dialog_cw.menu, "With Number (Angka)", RandWithNumber, "rand_with_number_cw")
ui:addDivider(dialog_cw.menu)
ui:addChildInputInt(dialog_cw.menu, "Delay Break", CW_DelayBreak, "ms", "Delay hancur block", "Verified", "cw_delaybreak")
ui:addDivider()
ui:addToggleButton("Clear World: Start / Stop", false, "btn_clearworld")

ui:addDivider()

local dialog_autodrop = ui:addDialog("Auto drop Setting", "Settings for auto drop", {})
ui:addChildToggle(dialog_autodrop.menu, "Auto drop", AutoDropEnabled, "autodrop_toggle")
ui:addChildInputInt(dialog_autodrop.menu, "Minimum to drop", MinToDrop, "items", "Minimum items", "Verified", "min_to_drop")
ui:addChildInputInt(dialog_autodrop.menu, "Position x block", DropPosX, "Block position X", "X coordinate", "Verified", "drop_pos_x")
ui:addChildInputInt(dialog_autodrop.menu, "Position y block", DropPosY, "Block position Y", "Y coordinate", "Verified", "drop_pos_y")
ui:addChildInputString(dialog_autodrop.menu, "World to drop", DropWorld, "World Name", "Target world", "World Name", "drop_world")
ui:addDivider()

local dialog_autopick = ui:addDialog("Auto pick Setting", "Settings for auto pick", {})
ui:addChildToggle(dialog_autopick.menu, "Auto pick (Global)", AutoPickEnabled, "autopick_toggle")
ui:addChildToggle(dialog_autopick.menu, "Mode: Auto find", AutoFind_Enabled, "autofind_toggle")
ui:addDivider(dialog_autopick.menu)

ui:addChildToggle(dialog_autopick.menu, "Pick Door Entrance", PickDoor_Enabled, "pick_door_toggle")
ui:addChildInputString(dialog_autopick.menu, "Door World Name", PickDoor_World, "World Name", "World name", "World", "pick_door_world")
ui:addChildInputString(dialog_autopick.menu, "Door ID / Door Name", PickDoor_Door, "Door ID", "Door ID", "Door", "pick_door_doorid")
ui:addChildInputInt(dialog_autopick.menu, "Door Item ID", PickDoor_ID, "Item ID", "Item ID", "ID", "pick_door_id")
ui:addDivider(dialog_autopick.menu)

ui:addChildToggle(dialog_autopick.menu, "Pick World Lock", PickWL_Enabled, "pick_wl_toggle")
ui:addChildInputString(dialog_autopick.menu, "WL World Name", PickWL_World, "World Name", "World name", "World", "pick_wl_world")
ui:addChildInputString(dialog_autopick.menu, "WL Door ID", PickWL_Door, "Door ID", "Door ID", "Door", "pick_wl_doorid")
ui:addChildInputInt(dialog_autopick.menu, "WL Item ID", PickWL_ID, "Item ID", "Item ID", "ID", "pick_wl_id")
ui:addDivider(dialog_autopick.menu)

ui:addChildToggle(dialog_autopick.menu, "Pick Platform", PickPlat_Enabled, "pick_plat_toggle")
ui:addChildInputString(dialog_autopick.menu, "Plat World Name", PickPlat_World, "World Name", "World name", "World", "pick_plat_world")
ui:addChildInputString(dialog_autopick.menu, "Plat Door ID", PickPlat_Door, "Door ID", "Door ID", "Door", "pick_plat_doorid")
ui:addChildInputInt(dialog_autopick.menu, "Plat Item ID", PickPlat_ID, "Item ID", "Item ID", "ID", "pick_plat_id")
ui:addDivider()

ui:addDivider()
ui:addButton("Buka Item ID Finder", "btn_itemfinder")

-- TEMPORARY STORAGE UNTUK MENAMPUNG KETIKAN USER
local temp = {
    autodf_worldlist = table.concat(Config.World.nameworld, ","),
    autodf_use_random = UseRandomDF,
    cw_worldlist = table.concat(CW_WorldList, ","),
    cw_use_random = UseRandomCW,
    cw_delaybreak = tostring(CW_DelayBreak),
    verify_punch = VerifyPunch,
    enable_break = EnableBreak,
    enable_place = EnablePlace,
    hit_count = HitCount,
    autodf_delaybreak = tostring(dbk),
    autodf_delayplace = tostring(dpc),
    autodrop_toggle = AutoDropEnabled,
    min_to_drop = tostring(MinToDrop),
    drop_pos_x = tostring(DropPosX),
    drop_pos_y = tostring(DropPosY),
    drop_world = DropWorld,
    autopick_toggle = AutoPickEnabled,
    autofind_toggle = AutoFind_Enabled,
    pick_door_toggle = PickDoor_Enabled,
    pick_door_world = PickDoor_World,
    pick_door_doorid = PickDoor_Door,
    pick_door_id = tostring(PickDoor_ID),
    pick_wl_toggle = PickWL_Enabled,
    pick_wl_world = PickWL_World,
    pick_wl_doorid = PickWL_Door,
    pick_wl_id = tostring(PickWL_ID),
    pick_plat_toggle = PickPlat_Enabled,
    pick_plat_world = PickPlat_World,
    pick_plat_doorid = PickPlat_Door,
    pick_plat_id = tostring(PlatformID)
}

-- FUNGSI UNTUK MENYIMPAN NILAI DARI KOTAK INPUT (BAIK KETIK ATAU DI-CENTANG)
function onValue(type, name, value)
    temp[name] = value -- Simpan ke temp table secara universal

    if name == "autodf_worldlist" then
        local worlds = {}
        for w in tostring(value):gmatch("[^,%s]+") do table.insert(worlds, w) end
        if #worlds > 0 then Config.World.nameworld = worlds end
    elseif name == "autodf_use_random" then UseRandomDF = value
    elseif name == "rand_length" then RandLength = tonumber(value) or 5
    elseif name == "rand_with_number" then RandWithNumber = value
    elseif name == "rand_length_cw" then RandLength = tonumber(value) or 5
    elseif name == "rand_with_number_cw" then RandWithNumber = value
    elseif name == "cw_worldlist" then
        local worlds = {}
        for w in tostring(value):gmatch("[^,%s]+") do table.insert(worlds, w) end
        if #worlds > 0 then CW_WorldList = worlds end
    elseif name == "cw_use_random" then UseRandomCW = value
    elseif name == "cw_delaybreak" then CW_DelayBreak = tonumber(value) or CW_DelayBreak
    elseif name == "verify_punch" then VerifyPunch = value
    elseif name == "enable_break" then EnableBreak = value
    elseif name == "enable_place" then EnablePlace = value
    elseif name == "hit_count" then HitCount = tonumber(value) or 1
    elseif name == "autodf_delaybreak" then dbk = tonumber(value) or dbk
    elseif name == "autodf_delayplace" then dpc = tonumber(value) or dpc
    
    elseif name == "autodrop_toggle" then AutoDropEnabled = value
    elseif name == "min_to_drop" then MinToDrop = tonumber(value) or 190
    elseif name == "drop_pos_x" then DropPosX = tonumber(value) or 26
    elseif name == "drop_pos_y" then DropPosY = tonumber(value) or 11
    elseif name == "drop_world" then DropWorld = value
    
    elseif name == "autopick_toggle" then AutoPickEnabled = value
    elseif name == "autofind_toggle" then AutoFind_Enabled = value
    
    elseif name == "pick_door_toggle" then PickDoor_Enabled = value
    elseif name == "pick_door_world" then PickDoor_World = value
    elseif name == "pick_door_doorid" then PickDoor_Door = value
    elseif name == "pick_door_id" then PickDoor_ID = tonumber(value) or 0
    
    elseif name == "pick_wl_toggle" then PickWL_Enabled = value
    elseif name == "pick_wl_world" then PickWL_World = value
    elseif name == "pick_wl_doorid" then PickWL_Door = value
    elseif name == "pick_wl_id" then PickWL_ID = tonumber(value) or 242
    
    elseif name == "pick_plat_toggle" then PickPlat_Enabled = value
    elseif name == "pick_plat_world" then PickPlat_World = value
    elseif name == "pick_plat_doorid" then PickPlat_Door = value
    elseif name == "pick_plat_id" then PickPlat_ID = tonumber(value) or PlatformID
    
    elseif name == "btn_itemfinder" then openItemFinderDialog()
    
    -- KETIKA TOMBOL START DIKLIK, AUTO-SYNC SEMUA DATA DARI KOTAK INPUT KE VARIABEL AKTIF
    elseif name == "btn_autodf" then
        autoDF_running = value
        if value == true then
            PickDoor_World = temp.pick_door_world or PickDoor_World
            PickDoor_Door = temp.pick_door_doorid or PickDoor_Door
            PickWL_World = temp.pick_wl_world or PickWL_World
            PickWL_Door = temp.pick_wl_doorid or PickWL_Door
            PickPlat_World = temp.pick_plat_world or PickPlat_World
            PickPlat_Door = temp.pick_plat_doorid or PickPlat_Door
            LogToConsole("`w[`0Auto DF`w] Konfigurasi tersinkronisasi otomatis!")
        end
    elseif name == "btn_clearworld" then
        CW_running = value
        if value == true then
            PickDoor_World = temp.pick_door_world or PickDoor_World
            PickDoor_Door = temp.pick_door_doorid or PickDoor_Door
            PickWL_World = temp.pick_wl_world or PickWL_World
            PickWL_Door = temp.pick_wl_doorid or PickWL_Door
            LogToConsole("`w[`0Clear World`w] Konfigurasi tersinkronisasi otomatis!")
        end
    end
end
addHook(onValue, "onValue")

function onDraw(d)
    removeHook("onDraw")
    runCoroutine(function()
        Sleep(2000)
        addIntoModule(ui:generateJSON())
    end)
end
addHook(onDraw, "onDraw")

function onSendPacket(type, pkt)
    if handleItemPickerResponse(type, pkt) then return true end
    if handleMenuDialog(type, pkt) then return true end
    return false
end
addHook(onSendPacket, "onSendPacket")
applyHook()

sendVariant({v1 = "OnTextOverlay", v2 = "`9Script `wCreated By `9Freazd"})

runCoroutine(function()
    while true do
        if autoDF_running then
            LoopMultiWorld()
        elseif CW_running then
            LoopClearWorld()
        else
            Sleep(300)
        end
    end
end)
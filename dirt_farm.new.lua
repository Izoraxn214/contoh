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

-- State Auto Drop Setting (Seed / Item Utama)
AutoDropEnabled = false
MinToDrop = 190
DropPosX = 26
DropPosY = 11
DropWorld = "SDZRR"
DropDoor = ""
CustomDropIDs = "3, 15, 5, 11"

-- State Trash World Setting
TrashWorldEnabled = true
MinTrashToDrop = 50
TrashPosX = 26
TrashPosY = 11
TrashWorld = "TRASHWORLD"
TrashDoor = ""
CustomTrashIDs = "4, 10, 14"

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

local function getDropIDList()
    local ids = {}
    for id in tostring(CustomDropIDs):gmatch("[^,%s]+") do
        local num = tonumber(id)
        if num then table.insert(ids, num) end
    end
    if #ids == 0 then ids = {3, 15, 5, 11} end
    return ids
end

local function getTrashIDList()
    local ids = {}
    for id in tostring(CustomTrashIDs):gmatch("[^,%s]+") do
        local num = tonumber(id)
        if num then table.insert(ids, num) end
    end
    if #ids == 0 then ids = {4, 10, 14} end
    return ids
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

function ensureSetupItems()
    if not autoDF_running then return end
    if inv(WorldLockID) == 0 or inv(EntranceID) == 0 then
        LogToConsole("`w[`0Setup`w] Item WL/Entrance kurang, mengambil ke Storage...")
        local currentWorld = safeGetWorldName()
        if currentWorld == "" then return end
        
        local targetStorageWorld = PickWL_World ~= "" and PickWL_World or PickDoor_World
        local targetStorageDoor = PickWL_Door ~= "" and PickWL_Door or PickDoor_Door

        if targetStorageWorld == "" then
            LogToConsole("`4[`0Setup Error`4] World Storage WL/Door belum diisi di menu Auto Pick!")
            return
        end

        warp(targetStorageWorld, targetStorageDoor)
        Sleep(4000)

        for _, object in pairs(safeGetObjectList()) do
            if not autoDF_running then return end
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
    if not autoDF_running then return end
    local currentWorld = safeGetWorldName()
    if currentWorld == "" then return end

    -- 1. Drop Sampah ke Trash World
    if TrashWorldEnabled and TrashWorld ~= "" then
        local trashIDs = getTrashIDList()
        for _, trashID in ipairs(trashIDs) do
            if not autoDF_running then return end
            local jmlTrash = inv(trashID)
            if jmlTrash >= MinTrashToDrop then
                warp(TrashWorld, TrashDoor)
                Sleep(5000)
                FindPath(TrashPosX, TrashPosY)
                Sleep(1000)
                sendPacket(2, "action|drop\n|itemID|" .. trashID)
                Sleep(100)
                sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. trashID .. "|\ncount|" .. jmlTrash)
                Sleep(2000)
                warp(currentWorld, "")
                Sleep(5000)
            end
        end
    end

    -- 2. Drop Item Utama/Seed
    if AutoDropEnabled and DropWorld ~= "" then
        local dropIDs = getDropIDList()
        for _, id in pairs(dropIDs) do
            if not autoDF_running then return end
            local jml = inv(id)
            if jml >= MinToDrop then
                warp(DropWorld, DropDoor)
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
    if not AutoPickEnabled or not autoDF_running then return end
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

                if tile.fg == 0 and tile.bg == 0 and dropCount == 0 then
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
    local dropIDs = getDropIDList()
    local needDrop = false
    for _, id in pairs(dropIDs) do
        if inv(id) >= 100 then needDrop = true break end
    end

    if needDrop and not AutoDropEnabled then
        Sleep(200)
        warp(worldsaveseed, "")
        Sleep(6000)
        for _, id in pairs(dropIDs) do
            if not autoDF_running then return end
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
            if not autoDF_running then return end
            if safeTile(column, tiley).bg == 14 or safeTile(column + 1, tiley).bg == 14 then
                FindPath(column, tiley - 1)
                Sleep(1000)
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
        Sleep(4000)
        
        local attempts = 0
        while inv(PlatformID) < 52 and autoDF_running and attempts < 10 do
            local foundAny = false
            for _, object in pairs(safeGetObjectList()) do
                if not autoDF_running then return end
                if object and object.itemid == PlatformID then
                    foundAny = true
                    FindPath(math.floor((object.posX + 8) / 32) - 1, math.floor(object.posY / 32))
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
        
        warp(nameworld, "")
        Sleep(4000)
    end

    for tiley = 2, 52, 2 do
        if not autoDF_running then return end
        if safeTile(1, tiley).fg == 0 then
            FindPath(0, tiley)
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
            FindPath(99, tiley)
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
                FindPath(tilex - 1, tiley)
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
            FindPath(tile.x, tile.y - 1)
            Sleep(200)
            local timeout = 0
            while safeTile(tile.x, tile.y).fg == 4 and autoDF_running and timeout < 20 do
                tnjk1_3(tile.x, tile.y)
                Sleep(dbk)
                timeout = timeout + 1
            end
            processAutoPick()
            if safeTile(tile.x, tile.y).fg == 0 and autoDF_running then
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
            FindPath(tilex, tiley + 1)
            Sleep(300)
            for i = 1, 5 do
                local tx = (tilex - 3) + i
                if tx <= 98 and safeTile(tx, tiley).fg == 0 then
                    local timeout = 0
                    while safeTile(tx, tiley).fg == 0 and inv(2) > 0 and autoDF_running and timeout < 10 do
                        trh1_3(tx, tiley, 2)
                        Sleep(dpc)
                        timeout = timeout + 1
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
    if not nameworld or nameworld == "" then return end

    warp(nameworld, "")
    Sleep(4000)
    LogToConsole("`w[`0Auto DF`w] Masuk world: " .. tostring(nameworld))
    Sleep(2000)

    if UseRandomDF then
        local successSetup = setupNewRandomWorld()
        if not successSetup then return end
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
                    "default": "180",
                    "label": "ms",
                    "placeholder": "millisecond",
                    "icon": "Verified",
                    "alias": "autodf_delaybreak"
                },
                {
                    "type": "input_int",
                    "text": "Delay Place",
                    "default": "80",
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
                    "type": "input_int",
                    "text": "Position x block",
                    "default": "26",
                    "label": "X",
                    "placeholder": "X coordinate",
                    "icon": "Verified",
                    "alias": "drop_pos_x"
                },
                {
                    "type": "input_int",
                    "text": "Position y block",
                    "default": "11",
                    "label": "Y",
                    "placeholder": "Y coordinate",
                    "icon": "Verified",
                    "alias": "drop_pos_y"
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
                    "text": "Custom Drop IDs",
                    "default": "3, 15, 5, 11",
                    "icon": "Edit",
                    "alias": "custom_drop_ids"
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
                    "type": "input_int",
                    "text": "Trash X block",
                    "default": "26",
                    "label": "X",
                    "placeholder": "X coordinate",
                    "icon": "Verified",
                    "alias": "trash_pos_x"
                },
                {
                    "type": "input_int",
                    "text": "Trash Y block",
                    "default": "11",
                    "label": "Y",
                    "placeholder": "Y coordinate",
                    "icon": "Verified",
                    "alias": "trash_pos_y"
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
                    "text": "Custom Trash IDs",
                    "default": "4, 10, 14",
                    "icon": "Edit",
                    "alias": "custom_trash_ids"
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
    elseif name == "autodf_use_random" then UseRandomDF = value
    elseif name == "rand_length" then RandLength = tonumber(value) or 5
    elseif name == "rand_with_number" then RandWithNumber = value
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
    elseif name == "drop_world" then DropWorld = tostring(value)
    elseif name == "drop_door" then DropDoor = tostring(value)
    elseif name == "custom_drop_ids" then CustomDropIDs = tostring(value)

    elseif name == "trash_world_toggle" then TrashWorldEnabled = value
    elseif name == "min_trash_drop" then MinTrashToDrop = tonumber(value) or 50
    elseif name == "trash_pos_x" then TrashPosX = tonumber(value) or 26
    elseif name == "trash_pos_y" then TrashPosY = tonumber(value) or 11
    elseif name == "trash_world" then TrashWorld = tostring(value)
    elseif name == "trash_door" then TrashDoor = tostring(value)
    elseif name == "custom_trash_ids" then CustomTrashIDs = tostring(value)
    
    elseif name == "autopick_toggle" then AutoPickEnabled = value
    elseif name == "autofind_toggle" then AutoFind_Enabled = value
    
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
            LogToConsole("`w[`0Auto DF`w] Autofarm dihentikan.")
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
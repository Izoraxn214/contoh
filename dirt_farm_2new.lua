-- ==========================================
-- SET CONFIG TERPUSAT (UBAH SETELAN DI SINI)
-- ==========================================
Config = {
    -- Target World Dirt Farm
    WorldList = {"TKTYW", "QVSVF", "FCMQW", "DEJCA", "ACMFA", "FZSGR", "KWYRY", "DWTWG", "JZUXA", "TUIGE", "JTLQM", "IMCKM", "DQKQU", "FUQRB", "WZWGW"},
    DFWorldDoor = "IWP2145",

    -- World Storage Seed & Restock
    WorldSaveSeed = "PLATSAVEHAM",
    WorldSaveSeedDoor = "12345",

    -- Setelan Auto Drop
    AutoDropEnabled = true,
    DropWorld = "PLATSAVEHAM",
    DropDoor = "12345",
    DropCooldown = 20, -- Jeda antar drop (detik)
    KeepPercent = 0.50, -- MENYISAKAN 50% UNTUK SEMUA ITEM DI BACKPACK SAAT DROP

    -- Fitur Anti FC / Stabilitas Memori
    RestEveryWorld = 15, -- Istirahat setiap N world selesai
    RestDuration = 15,   -- Durasi istirahat (detik)

    -- Slot Drop Items (8 Slots)
    ItemSlots = {
        { id = 3,  min = 190, x = 98, y = 22 }, -- Seed Dirt
        { id = 2,  min = 190, x = 98, y = 23 }, -- Dirt Block
        { id = 15, min = 190, x = 98, y = 21 }, -- Seed Cave
        { id = 14, min = 50,  x = 98, y = 20 }, -- Cave Block
        { id = 11, min = 190, x = 98, y = 19 }, -- Seed Rock
        { id = 10, min = 50,  x = 98, y = 18 }, -- Rock Block
        { id = 5,  min = 190, x = 98, y = 17 }, -- Seed Lava
        { id = 4,  min = 50,  x = 98, y = 16 }  -- Lava Block
    },

    -- Speed & Delay Execution (ms)
    DelayPlace = 120,
    DelayBreak = 220,
    HitCount = 1,
    VerifyPunch = false,
    EnableBreak = true,
    EnablePlace = true,

    -- Platform & Storage Settings
    PlatformID = 1324,
    StoragePlatWorld = "PLATSAVEHAM",
    StoragePlatDoor = "12345",
    PickPlat_Enabled = true,

    -- World Lock & Door Entrance
    WorldLockID = 242,
    EntranceID = 5036,

    -- Auto Pick Door
    PickDoor_Enabled = true,
    PickDoor_World = "PLATSAVEHAM",
    PickDoor_Door = "12345",
    PickDoor_ID = 5036,

    -- Auto Pick WL
    PickWL_Enabled = true,
    PickWL_World = "PLATSAVEHAM",
    PickWL_Door = "12345",
    PickWL_ID = 242,

    -- Random World Feature
    UseRandomDF = false,
    RandLength = 5,
    RandWithNumber = false,

    -- Global Auto Pick
    AutoPickEnabled = true,
    AutoFind_Enabled = true
}

local CONFIG_FILE = "df_config_save.txt"
local worldCompletedCount = 0

-- ==========================================
-- FUNGSI SAVE & LOAD CONFIG DARI HP (PERSISTENT)
-- ==========================================
function saveConfigToStorage()
    local lines = {}
    for k, v in pairs(Config) do
        if type(v) ~= "table" then
            table.insert(lines, k .. "=" .. tostring(v))
        end
    end
    if Config.WorldList then
        table.insert(lines, "WorldList=" .. table.concat(Config.WorldList, ","))
    end

    local dataStr = table.concat(lines, "\n")
    local ok, err = pcall(writeToLocal, CONFIG_FILE, dataStr)
    if ok then
        LogToConsole("`w[`2Config Saved`w] Setelan disimpan ke memori HP!")
    else
        LogToConsole("`4[`0Config Error`4] Gagal menyimpan file config!")
    end
end

function loadConfigFromStorage()
    local ok, content = pcall(readFromLocal, CONFIG_FILE)
    if ok and content and content ~= "" then
        for line in content:gmatch("[^\r\n]+") do
            local k, v = line:match("^([^=]+)=(.*)$")
            if k and v then
                if k == "WorldList" then
                    local list = {}
                    for w in v:gmatch("[^,%s]+") do table.insert(list, w) end
                    if #list > 0 then Config.WorldList = list end
                else
                    if v == "true" then v = true
                    elseif v == "false" then v = false
                    elseif tonumber(v) then v = tonumber(v)
                    end
                    Config[k] = v
                end
            end
        end
        LogToConsole("`w[`2Config Loaded`w] Berhasil memuat setelan lokal!")
        return true
    end
    return false
end

-- ==========================================
-- SINKRONISASI CONFIG KE GLOBAL VARIABLES
-- ==========================================
function applyConfig()
    WorldList = Config.WorldList
    index_world = 1
    nameworld = WorldList[index_world]

    worldsaveseed = Config.WorldSaveSeed
    worldsaveseedDoor = Config.WorldSaveSeedDoor
    DFWorldDoor = Config.DFWorldDoor

    dpc = Config.DelayPlace
    dbk = Config.DelayBreak
    HitCount = Config.HitCount
    VerifyPunch = Config.VerifyPunch
    EnableBreak = Config.EnableBreak
    EnablePlace = Config.EnablePlace

    PlatformID = Config.PlatformID
    StoragePlatWorld = Config.StoragePlatWorld
    StoragePlatDoor = Config.StoragePlatDoor
    PickPlat_Enabled = Config.PickPlat_Enabled

    WorldLockID = Config.WorldLockID
    EntranceID = Config.EntranceID

    AutoDropEnabled = Config.AutoDropEnabled
    DropWorld = Config.DropWorld
    DropDoor = Config.DropDoor
    DropCooldown = Config.DropCooldown
    KeepPercent = Config.KeepPercent or 0.50
    ItemSlots = Config.ItemSlots

    PickDoor_Enabled = Config.PickDoor_Enabled
    PickDoor_World = Config.PickDoor_World
    PickDoor_Door = Config.PickDoor_Door
    PickDoor_ID = Config.PickDoor_ID

    PickWL_Enabled = Config.PickWL_Enabled
    PickWL_World = Config.PickWL_World
    PickWL_Door = Config.PickWL_Door
    PickWL_ID = Config.PickWL_ID

    UseRandomDF = Config.UseRandomDF
    RandLength = Config.RandLength
    RandWithNumber = Config.RandWithNumber

    AutoPickEnabled = Config.AutoPickEnabled
    AutoFind_Enabled = Config.AutoFind_Enabled
    
    saveConfigToStorage()
end

loadConfigFromStorage()
applyConfig()

-- ==========================================
-- SYSTEM TOGGLES & INTERNAL STATES
-- ==========================================
EditToggle("Antibounce", true)
EditToggle("ModFly", true)
EditToggle("Antilag", true)
EditToggle("Fast Trash", true)
EditToggle("Fast Drop", true)
EditToggle("Cant Pickup Item", true)
EditToggle("Anti Lava", true)

autoDF_running = false
lastDropTime = 0
botStartTime = os.time()
worldStartTime = os.time()

math.randomseed(os.time())

local function isUnbreakable(fg)
    local id = tonumber(fg) or 0
    if id == 0 then return false end

    local dynamicDoorID = tonumber(PickDoor_ID) or 5036
    local dynamicWLID = tonumber(PickWL_ID) or 242
    local dynamicPlatID = tonumber(PlatformID) or 1324

    if id == 8 or id == 6 or id == dynamicWLID or id == 202 or id == 204 or id == 206 
        or id == 2408 or id == 4994 or id == 1790 
        or id == dynamicDoorID or id == tonumber(EntranceID)
        or id == dynamicPlatID then
        return true
    end

    local clearableDFBlocks = {
        [2]  = true,
        [3]  = true,
        [4]  = true,
        [10] = true,
        [14] = true
    }

    if not clearableDFBlocks[id] then
        return true
    end

    return false
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

local function waitForTilesToLoad()
    local timeout = 0
    while autoDF_running and timeout < 20 do
        local tiles = safeGetTiles()
        if #tiles >= 1000 then
            return true
        end
        Sleep(500)
        timeout = timeout + 1
    end
    return false
end

function warp(worldName, doorId)
    if not worldName or worldName == "" then return false end
    
    Sleep(1000)

    local target = worldName
    if doorId and doorId ~= "" then target = worldName .. "|" .. doorId end
    local ok, err = pcall(growtopia.warpTo, target)
    if not ok then
        LogToConsole("`4[`0Warp Error`4] " .. tostring(err))
        return false
    end
    return true
end

function warpDFWorld(worldEntry)
    if not worldEntry or worldEntry == "" then return false end
    local wName, dId = worldEntry:match("([^|]+)|?(.*)")
    if (dId == nil or dId == "") and DFWorldDoor ~= "" and not UseRandomDF then
        dId = DFWorldDoor
    end
    return warp(wName, dId)
end

function inv(itemID)
    local targetID = math.floor(tonumber(itemID) or 0)
    for _, item in pairs(safeGetInventory()) do
        if item then
            local id = math.floor(tonumber(item.id or item.itemid or item.item_id) or 0)
            if id == targetID then 
                return math.floor(tonumber(item.amount or item.count or 0) or 0)
            end
        end
    end
    return 0
end

function walkTo(targetX, targetY, maxWaitMs)
    targetX = math.max(0, math.min(99, targetX))
    targetY = math.max(0, math.min(53, targetY))

    local p = getLocal()
    if not p or not p.posX or not p.posY then return false end

    local curX = p.posX // 32
    local curY = p.posY // 32

    if curX == targetX and curY == targetY then
        return true
    end

    FindPath(targetX, targetY)

    local elapsed = 0
    maxWaitMs = maxWaitMs or 1500
    while autoDF_running and elapsed < maxWaitMs do
        Sleep(100)
        elapsed = elapsed + 100
        local pl = getLocal()
        if pl and pl.posX and pl.posY then
            if (pl.posX // 32) == targetX and (pl.posY // 32) == targetY then
                return true
            end
        end
    end

    p = getLocal()
    if not p or not p.posX or not p.posY then return false end
    curX = p.posX // 32
    curY = p.posY // 32

    local stepX = curX
    if curX < targetX then stepX = curX + 1
    elseif curX > targetX then stepX = curX - 1 end

    local stepY = curY
    if curY < targetY then stepY = curY + 1
    elseif curY > targetY then stepY = curY - 1 end

    if safeTile(stepX, stepY).fg ~= 0 and not isUnbreakable(safeTile(stepX, stepY).fg) then
        tnjk1_3(stepX, stepY)
        Sleep(dbk)
    end
    if safeTile(stepX, curY).fg ~= 0 and not isUnbreakable(safeTile(stepX, curY).fg) then
        tnjk1_3(stepX, curY)
        Sleep(dbk)
    end

    FindPath(targetX, targetY)
    Sleep(200)

    p = getLocal()
    if p and p.posX and p.posY then
        return (p.posX // 32 == targetX and p.posY // 32 == targetY)
    end
    return false
end

function tnjk1_3(x, y)
    if not EnableBreak or not autoDF_running then return false end
    
    local p = getLocal()
    if not p or not p.posX or not p.posY then return false end

    local pxTile = p.posX // 32
    local pyTile = p.posY // 32

    if math.abs(pxTile - x) > 3 or math.abs(pyTile - y) > 3 then
        local standX = (x > pxTile) and (x - 1) or (x + 1)
        if not walkTo(standX, y, 1500) then return false end
        p = getLocal()
        if not p or not p.posX or not p.posY then return false end
    end

    local packet = {}
    packet.type = 3
    packet.state = (p and p.state) and p.state or 0
    packet.value = 18
    packet.px = math.floor(x)
    packet.py = math.floor(y)
    packet.x = p.posX
    packet.y = p.posY

    for i = 1, (HitCount or 1) do
        sendPacketRaw(false, packet)
        Sleep(100)
    end
    return true
end

function trh1_3(x, y, id)
    if not EnablePlace or not autoDF_running then return false end
    
    local itemRealID = math.floor(tonumber(id) or 0)
    if itemRealID <= 0 then return false end

    local p = getLocal()
    if not p or not p.posX or not p.posY then return false end

    local pxTile = p.posX // 32
    local pyTile = p.posY // 32

    if math.abs(pxTile - x) > 3 or math.abs(pyTile - y) > 3 then
        local standX = (x > pxTile) and (x - 1) or (x + 1)
        local standY = y

        if safeTile(standX, standY).fg ~= 0 and safeTile(standX, standY).fg ~= 102 then
            standY = y + 1
        end

        if not walkTo(standX, standY, 1500) then 
            if not walkTo(x, y + 1, 1500) then return false end
        end

        p = getLocal()
        if not p or not p.posX or not p.posY then return false end
    end

    local packet = {}
    packet.type = 3
    packet.value = itemRealID
    packet.px = math.floor(x)
    packet.py = math.floor(y)
    packet.x = p.posX
    packet.y = p.posY

    sendPacketRaw(false, packet)
    return true
end

function sdtr_11(object)
    if not object then return end
    local packet = {}
    packet.type = 11
    packet.value = math.floor(tonumber(object.netid or object.id) or 0)
    packet.x = object.posX or object.x or 0
    packet.y = object.posY or object.y or 0
    sendPacketRaw(false, packet)
end

function sdt_11(range)
    local localPlayer = getLocal()
    if not localPlayer then return end

    local pickedCount = 0
    local maxPickPerCycle = 3

    for _, object in pairs(safeGetObjectList()) do
        if object then
            local itemID = math.floor(tonumber(object.itemid or object.type or object.item_id) or 0)
            if math.abs(localPlayer.posX - (object.posX or 0)) <= (32 * range) and
               math.abs(localPlayer.posY - (object.posY or 0)) <= (32 * range) and inv(itemID) < 200 then
                sdtr_11(object)
                pickedCount = pickedCount + 1
                Sleep(250)
                if pickedCount >= maxPickPerCycle then
                    break
                end
            end
        end
    end
end

function hasWorldLock()
    local dynamicWLID = tonumber(PickWL_ID) or 242
    for _, tile in pairs(safeGetTiles()) do
        if tile then
            local id = tile.fg or 0
            if id == dynamicWLID or id == 202 or id == 204 or id == 206 or id == 2408 or id == 4994 or id == 1790 then
                return true
            end
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

    if #safeGetInventory() == 0 then Sleep(1500) end

    local currentWL = inv(WorldLockID)
    local currentDoor = inv(EntranceID)

    if currentWL == 0 or currentDoor < 2 then
        LogToConsole("`w[`0Setup`w] WL (" .. currentWL .. ") / Entrance (" .. currentDoor .. ") kurang. Restock ke Storage...")
        local currentWorld = safeGetWorldName()
        if currentWorld == "" then return end
        
        local targetStorageWorld = PickWL_World ~= "" and PickWL_World or PickDoor_World
        local targetStorageDoor = PickWL_Door ~= "" and PickWL_Door or PickDoor_Door

        if targetStorageWorld == "" then
            LogToConsole("`4[`0Setup Error`4] World Storage WL/Door belum diisi!")
            return
        end

        warp(targetStorageWorld, targetStorageDoor)
        Sleep(7000)
        waitForTilesToLoad()
        Sleep(1000)

        local attempts = 0
        while (inv(WorldLockID) == 0 or inv(EntranceID) < 2) and autoDF_running and attempts < 5 do
            local foundAny = false
            for _, object in pairs(safeGetObjectList()) do
                if not autoDF_running then return end
                if object then
                    local itemID = math.floor(tonumber(object.itemid or object.type or object.item_id) or 0)
                    if itemID == WorldLockID or itemID == EntranceID then
                        foundAny = true
                        local targetX = math.floor(((object.posX or 0) + 8) / 32)
                        local targetY = math.floor((object.posY or 0) / 32)
                        
                        walkTo(targetX, targetY, 2000)
                        Sleep(400)
                        
                        sdtr_11(object)
                        sdt_11(1)
                        Sleep(500)
                        
                        if inv(WorldLockID) > 0 and inv(EntranceID) >= 2 then break end
                    end
                end
            end
            if not foundAny then
                attempts = attempts + 1
                Sleep(1000)
            else
                if inv(WorldLockID) > 0 and inv(EntranceID) >= 2 then break end
                attempts = attempts + 1
                Sleep(500)
            end
        end

        warpDFWorld(currentWorld)
        Sleep(7000)
        waitForTilesToLoad()
        Sleep(1000)
    end
end

function setupNewRandomWorld()
    if not autoDF_running then return false end
    if hasWorldLock() then
        LogToConsole("`4[`0Random World`4] World sudah dilock orang/punya Lock, mencari world lain...")
        return false
    end

    ensureSetupItems()
    if not autoDF_running then return false end

    local doorX, doorY = findMainDoor()
    LogToConsole("`w[`0Setup`w] Memasang WL dan Entrance di sekitar Main Door...")

    if safeTile(doorX, doorY - 1).fg ~= 0 and safeTile(doorX, doorY - 1).fg ~= WorldLockID then
        walkTo(doorX, doorY, 2000)
        local timeout = 0
        while safeTile(doorX, doorY - 1).fg ~= 0 and autoDF_running and timeout < 20 do
            tnjk1_3(doorX, doorY - 1)
            Sleep(dbk)
            timeout = timeout + 1
        end
    end

    if inv(WorldLockID) > 0 and safeTile(doorX, doorY - 1).fg == 0 then
        walkTo(doorX, doorY, 2000)
        Sleep(300)
        local timeout = 0
        while safeTile(doorX, doorY - 1).fg == 0 and inv(WorldLockID) > 0 and autoDF_running and timeout < 10 do
            trh1_3(doorX, doorY - 1, WorldLockID)
            Sleep(dpc)
            timeout = timeout + 1
        end
        Sleep(300)
    end

    local sidePositions = { doorX - 1, doorX + 1 }

    for _, targetX in ipairs(sidePositions) do
        if not autoDF_running then break end

        if safeTile(targetX, doorY).fg ~= 0 and safeTile(targetX, doorY).fg ~= EntranceID then
            walkTo(doorX, doorY, 2000)
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
            walkTo(doorX, doorY, 2000)
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

-- LOGIKA AUTO DROP DENGAN MENYISAKAN 50% UNTUK SEMUA ITEM
function processAutoDropAndTrash()
    if not autoDF_running or not AutoDropEnabled then return end

    local currentTime = os.time()
    if (currentTime - lastDropTime) < DropCooldown then
        return
    end

    local currentWorld = safeGetWorldName()
    if currentWorld == "" then return end

    for idx, slot in ipairs(ItemSlots) do
        if not autoDF_running then return end

        if slot.id > 0 and slot.min > 0 then
            local jml = inv(slot.id)
            if jml >= slot.min and DropWorld ~= "" then
                
                local ratio = KeepPercent or 0.50
                local keepAmount = math.floor(jml * ratio)
                local dropAmount = jml - keepAmount

                if dropAmount > 0 then
                    LogToConsole("`w[`0Auto Drop`w] Item ID (" .. slot.id .. ") capai limit (" .. jml .. "/" .. slot.min .. "). Dropping 50% (" .. dropAmount .. " pcs) ke Storage: " .. DropWorld)
                    
                    warp(DropWorld, DropDoor)
                    Sleep(7000)
                    waitForTilesToLoad()
                    
                    local targetX = slot.x
                    local targetY = slot.y
                    local dropSuccess = false
                    local attempts = 0

                    while autoDF_running and not dropSuccess and attempts < 10 and targetX >= 1 do
                        walkTo(targetX, targetY, 2000)
                        Sleep(800)

                        local countBefore = inv(slot.id)

                        sendPacket(2, "action|drop\nitemID|" .. slot.id)
                        Sleep(600)
                        sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. slot.id .. "|\ncount|" .. dropAmount)
                        Sleep(1500)

                        local countAfter = inv(slot.id)

                        if countAfter < countBefore then
                            dropSuccess = true
                            slot.x = targetX
                            LogToConsole("`w[`2Auto Drop Success`w] Berhasil drop di X=" .. targetX .. " Y=" .. targetY)
                        else
                            targetX = targetX - 1
                            attempts = attempts + 1
                            Sleep(1200)
                        end
                    end

                    warpDFWorld(currentWorld)
                    Sleep(7000)
                    waitForTilesToLoad()
                    Sleep(1000)

                    lastDropTime = os.time()
                end
            end
        end
    end
end

function processAutoPick()
    if not autoDF_running then return end
    if AutoPickEnabled then
        sdt_11(5)
    end
    processAutoDropAndTrash()
end

function cekSeed()
    if not autoDF_running then return end
    processAutoDropAndTrash()
end

function ambilSeed(id, jumlah)
    if not autoDF_running then return end
    if inv(id) < jumlah then
        if worldsaveseed == "" then return end
        LogToConsole("`w[`0Setup`w] Restock Item ID (" .. id .. ") ke Save World: " .. worldsaveseed)
        
        local initialAmount = inv(id)
        warp(worldsaveseed, worldsaveseedDoor)
        Sleep(7000)
        waitForTilesToLoad()
        Sleep(1000)

        local attempts = 0
        while inv(id) < jumlah and autoDF_running and attempts < 5 do
            local foundAny = false
            for _, object in pairs(safeGetObjectList()) do
                if not autoDF_running then return end
                if object then
                    local itemID = math.floor(tonumber(object.itemid or object.type or object.item_id) or 0)
                    if itemID == math.floor(tonumber(id) or 0) then
                        foundAny = true
                        local targetX = math.floor(((object.posX or 0) + 8) / 32)
                        local targetY = math.floor((object.posY or 0) / 32)
                        
                        walkTo(targetX, targetY, 2000)
                        Sleep(400)
                        
                        sdtr_11(object)
                        sdt_11(1)
                        Sleep(500)
                        
                        if inv(id) >= jumlah then break end
                    end
                end
            end
            
            if not foundAny then
                attempts = attempts + 1
                Sleep(1000)
            else
                if inv(id) >= jumlah then break end
                attempts = attempts + 1
                Sleep(500)
            end
        end

        warpDFWorld(nameworld)
        Sleep(7000)
        waitForTilesToLoad()
        Sleep(1000)

        if inv(id) <= initialAmount then
            LogToConsole("`4[`0Warning`4] Stok Item ID (" .. id .. ") di Storage habis!")
        end
    end
end

function plntDf_122()
    if not autoDF_running then return end
    if inv(2) >= 30 then return end

    LogToConsole("`w[`0Auto DF`w] Dirt Block kurang (" .. inv(2) .. "/30). Mengambil langsung dari Storage: " .. worldsaveseed)

    ambilSeed(2, 50)
    
    if inv(2) >= 30 then
        return
    end

    while autoDF_running and inv(2) < 30 do
        if inv(3) == 0 then
            ambilSeed(3, 50)
            if not autoDF_running then return end
        end

        local plantedAny = false
        for tilex = 2, 25 do
            if not autoDF_running or inv(3) == 0 then break end

            if safeTile(tilex, 26).fg == 0 then
                trh1_3(tilex, 26, 2)
                Sleep(dpc)
            end

            if safeTile(tilex, 25).fg == 0 and inv(3) > 0 then
                walkTo(tilex - 1, 25, 1000)
                trh1_3(tilex, 25, 3)
                Sleep(dpc)
                plantedAny = true
            end
        end

        if not plantedAny then break end

        local waitTime = 0
        while autoDF_running and waitTime < 32 do
            local readyCount = 0
            for tilex = 2, 25 do
                if safeTile(tilex, 25).readyharvest then
                    readyCount = readyCount + 1
                end
            end
            if readyCount >= 10 then break end

            Sleep(1000)
            waitTime = waitTime + 1
        end

        for tilex = 2, 25 do
            if not autoDF_running then break end

            if safeTile(tilex, 25).fg == 3 and safeTile(tilex, 25).readyharvest then
                walkTo(tilex - 1, 25, 1000)
                while safeTile(tilex, 25).fg == 3 and safeTile(tilex, 25).readyharvest and autoDF_running do
                    tnjk1_3(tilex, 25)
                    Sleep(dbk)
                end
                sdt_11(1)
                processAutoDropAndTrash()
            end
        end

        if inv(2) >= 30 then break end
    end
end

function smpng_12()
    local p = getLocal()
    if p and p.posX and p.posY then
        local doorX = p.posX // 32
        walkTo(doorX, 23, 2000)
        Sleep(200)
    end

    local function clearSideColumns(col1, col2, standX)
        for tiley = 24, 53 do
            if not autoDF_running then return end
            if safeTile(col1, tiley).bg == 14 or safeTile(col1, tiley).fg ~= 0 or
               safeTile(col2, tiley).bg == 14 or safeTile(col2, tiley).fg ~= 0 then
                
                walkTo(standX, tiley - 1, 1500)
                Sleep(150)
                
                local timeout = 0
                while (safeTile(col1, tiley).fg ~= 0 or safeTile(col1, tiley).bg == 14) 
                      and not isUnbreakable(safeTile(col1, tiley).fg) 
                      and autoDF_running and timeout < 20 do
                    if not tnjk1_3(col1, tiley) then Sleep(100) end
                    Sleep(dbk)
                    timeout = timeout + 1
                end

                timeout = 0
                while (safeTile(col2, tiley).fg ~= 0 or safeTile(col2, tiley).bg == 14) 
                      and not isUnbreakable(safeTile(col2, tiley).fg) 
                      and autoDF_running and timeout < 20 do
                    if not tnjk1_3(col2, tiley) then Sleep(100) end
                    Sleep(dbk)
                    timeout = timeout + 1
                end

                processAutoPick()
                cekSeed()
            end
        end
    end

    clearSideColumns(0, 1, 0)
    clearSideColumns(98, 99, 99)
end

function plfS_15()
    if not autoDF_running or not PickPlat_Enabled then return end

    if inv(PlatformID) < 52 then
        if StoragePlatWorld == "" then return end

        warp(StoragePlatWorld, StoragePlatDoor)
        Sleep(7000)
        waitForTilesToLoad()
        Sleep(1500)
        
        local attempts = 0
        while inv(PlatformID) < 52 and autoDF_running and attempts < 5 do
            local foundAny = false
            for _, object in pairs(safeGetObjectList()) do
                if not autoDF_running then return end
                if object then
                    local itemID = math.floor(tonumber(object.itemid or object.type or object.item_id) or 0)
                    if itemID == math.floor(tonumber(PlatformID) or 1324) then
                        foundAny = true
                        local targetX = math.floor(((object.posX or 0) + 8) / 32)
                        local targetY = math.floor((object.posY or 0) / 32)
                        
                        walkTo(targetX, targetY, 2000)
                        Sleep(400)
                        
                        sdtr_11(object)
                        sdt_11(1)
                        Sleep(500)
                        
                        if inv(PlatformID) >= 52 then break end
                    end
                end
            end
            if not foundAny then
                attempts = attempts + 1
                Sleep(1000)
            else
                if inv(PlatformID) >= 52 then break end
                attempts = attempts + 1
                Sleep(500)
            end
        end
        
        warpDFWorld(nameworld)
        Sleep(7000)
        waitForTilesToLoad()
        Sleep(1000)
    end

    if inv(PlatformID) == 0 then return end

    for tiley = 2, 52, 2 do
        if not autoDF_running then return end
        if inv(PlatformID) == 0 then break end

        if safeTile(1, tiley).fg == 0 then
            walkTo(0, tiley, 1500)
            Sleep(200)
            local timeout = 0
            while safeTile(1, tiley).fg == 0 and inv(PlatformID) > 0 and autoDF_running and timeout < 10 do
                if not trh1_3(1, tiley, PlatformID) then Sleep(200) end
                Sleep(dpc)
                timeout = timeout + 1
            end
        end
    end

    for tiley = 2, 52, 2 do
        if not autoDF_running then return end
        if inv(PlatformID) == 0 then break end

        if safeTile(98, tiley).fg == 0 then
            walkTo(99, tiley, 1500)
            Sleep(200)
            local timeout = 0
            while safeTile(98, tiley).fg == 0 and inv(PlatformID) > 0 and autoDF_running and timeout < 10 do
                if not trh1_3(98, tiley, PlatformID) then Sleep(200) end
                Sleep(dpc)
                timeout = timeout + 1
            end
        end
    end

    Sleep(1000)
    local currentWorld = safeGetWorldName()
    if currentWorld ~= "" then
        warpDFWorld(currentWorld)
        Sleep(7000)
    end
end

function clrd_down_15()
    for tiley = 27, 51, 12 do
        if not autoDF_running then return end

        for tilex = 2, 97, 1 do
            if not autoDF_running then return end
            
            local needBreak = false
            for _, checkY in ipairs({-2, 0, 2}) do
                local t = safeTile(tilex, tiley + checkY)
                if (t.fg ~= 0 or t.bg ~= 0) and not isUnbreakable(t.fg) then
                    needBreak = true
                    break
                end
            end

            if needBreak then
                walkTo(tilex - 1, tiley, 1500)
                Sleep(150)
                for i = -2, 2, 2 do
                    local timeout = 0
                    while (safeTile(tilex, tiley + i).fg ~= 0 or safeTile(tilex, tiley + i).bg == 14) 
                          and not isUnbreakable(safeTile(tilex, tiley + i).fg) 
                          and autoDF_running and timeout < 20 do
                        if not tnjk1_3(tilex, tiley + i) then Sleep(100) end
                        Sleep(dbk)
                        timeout = timeout + 1
                    end
                    processAutoPick()
                end
                cekSeed()
                processAutoPick()
            end
        end

        if (tiley + 6) <= 53 then
            for tilex = 97, 2, -1 do
                if not autoDF_running then return end
                
                local needBreak = false
                for _, checkY in ipairs({4, 6, 8}) do
                    local t = safeTile(tilex, tiley + checkY)
                    if (t.fg ~= 0 or t.bg ~= 0) and not isUnbreakable(t.fg) then
                        needBreak = true
                        break
                    end
                end

                if needBreak then
                    walkTo(tilex + 1, tiley + 6, 1500)
                    Sleep(150)
                    for i = 4, 8, 2 do
                        local timeout = 0
                        while (safeTile(tilex, tiley + i).fg ~= 0 or safeTile(tilex, tiley + i).bg == 14) 
                              and not isUnbreakable(safeTile(tilex, tiley + i).fg) 
                              and autoDF_running and timeout < 20 do
                            if not tnjk1_3(tilex, tiley + i) then Sleep(100) end
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
        collectgarbage("step", 100)
    end
end

function brkLv_12()
    for _, tile in pairs(safeGetTiles()) do
        if not autoDF_running then return end
        if tile and tile.fg == 4 then
            walkTo(tile.x, tile.y - 1, 2000)
            Sleep(200)
            local timeout = 0
            while safeTile(tile.x, tile.y).fg == 4 and autoDF_running and timeout < 20 do
                if not tnjk1_3(tile.x, tile.y) then Sleep(200) end
                Sleep(dbk)
                timeout = timeout + 1
            end
            processAutoPick()
            if safeTile(tile.x, tile.y).fg == 0 and autoDF_running then
                while inv(2) == 0 and autoDF_running do
                    plntDf_122()
                    Sleep(500)
                end
                trh1_3(tile.x, tile.y, 2)
                Sleep(dpc)
            end
        end
    end
end

function plcDrt_2()
    for tiley = 24, 2, -2 do
        if not autoDF_running then return end
        for tilex = 4, 99, 5 do
            if not autoDF_running then return end
            
            local hasEmptyTile = false
            for i = 1, 5 do
                local tx = (tilex - 3) + i
                if tx >= 2 and tx <= 97 and safeTile(tx, tiley).fg == 0 then
                    hasEmptyTile = true
                    break
                end
            end

            if hasEmptyTile then
                if inv(2) == 0 and autoDF_running then
                    plntDf_122()
                    Sleep(300)
                end

                local standY = tiley + 1
                if safeTile(tilex, standY).fg ~= 0 and not isUnbreakable(safeTile(tilex, standY).fg) then
                    tnjk1_3(tilex, standY)
                    Sleep(dbk)
                end

                local reached = walkTo(tilex, standY, 1500)
                if reached then
                    Sleep(150)
                    for i = 1, 5 do
                        local tx = (tilex - 3) + i
                        if tx >= 2 and tx <= 97 and safeTile(tx, tiley).fg == 0 then
                            if inv(2) == 0 and autoDF_running then
                                plntDf_122()
                                Sleep(300)
                                walkTo(tilex, standY, 1500)
                            end
                            local retry = 0
                            while safeTile(tx, tiley).fg == 0 and inv(2) > 0 and autoDF_running and retry < 3 do
                                trh1_3(tx, tiley, 2)
                                Sleep(dpc)
                                retry = retry + 1
                            end
                        end
                    end
                    processAutoPick()
                end
            end
            Sleep(50)
        end
        collectgarbage("step", 100)
    end
end

function fillEmptyCaveTiles()
    if not autoDF_running then return end

    for tiley = 24, 53 do
        if not autoDF_running then return end
        for tilex = 0, 99 do
            if not autoDF_running then return end
            local tile = safeTile(tilex, tiley)

            if tile and tile.bg == 14 and tile.fg == 0 then
                if inv(2) == 0 and autoDF_running then
                    plntDf_122()
                    Sleep(300)
                end

                local reached = walkTo(tilex, tiley - 1, 1000)
                if not reached then
                    reached = walkTo(tilex - 1, tiley, 1000) or walkTo(tilex + 1, tiley, 1000)
                end

                if reached then
                    Sleep(100)
                    local timeout = 0
                    while safeTile(tilex, tiley).fg == 0 and inv(2) > 0 and autoDF_running and timeout < 3 do
                        trh1_3(tilex, tiley, 2)
                        Sleep(dpc)
                        timeout = timeout + 1
                    end
                    processAutoPick()
                end
            end
        end
    end
end

function clearLeftoverSafe()
    if not autoDF_running then return end
    Sleep(500)

    for tiley = 2, 25 do
        if not autoDF_running then return end
        for tilex = 0, 99 do
            if not autoDF_running then return end
            local tile = safeTile(tilex, tiley)

            if tile.fg == 3 then
                walkTo(tilex, tiley + 1, 1500)
                Sleep(150)
                local timeout = 0
                while safeTile(tilex, tiley).fg == 3 and autoDF_running and timeout < 15 do
                    tnjk1_3(tilex, tiley)
                    Sleep(dbk)
                    timeout = timeout + 1
                end
                sdt_11(1)
                processAutoDropAndTrash()

                if tiley <= 23 and tilex >= 2 and tilex <= 97 and safeTile(tilex, tiley).fg == 0 and inv(2) > 0 then
                    trh1_3(tilex, tiley, 2)
                    Sleep(dpc)
                end
            end

            for _, obj in pairs(safeGetObjectList()) do
                if obj then
                    local ox = math.floor(((obj.posX or 0) + 8) / 32)
                    local oy = math.floor((obj.posY or 0) / 32)
                    if ox == tilex and oy == tiley then
                        sdtr_11(obj)
                        Sleep(150)
                        processAutoDropAndTrash()
                    end
                end
            end
        end
    end
end

function isWorldAlreadyDone()
    Sleep(2000)

    if not waitForTilesToLoad() then
        return false
    end

    local tiles = safeGetTiles()
    if #tiles < 1000 then
        return false
    end

    local unclearedCount = 0
    local emptySkyCount = 0
    local leftoverTreeCount = 0

    for _, t in pairs(tiles) do
        if t and t.x and t.y then
            if t.y >= 24 and t.y <= 53 and t.x >= 0 and t.x <= 99 then
                if t.bg == 14 or (t.fg ~= 0 and not isUnbreakable(t.fg)) then 
                    unclearedCount = unclearedCount + 1
                end
            end

            if t.y >= 2 and t.y <= 23 and t.x >= 2 and t.x <= 97 then
                if t.fg ~= 2 and not isUnbreakable(t.fg) then
                    emptySkyCount = emptySkyCount + 1
                end
            end

            if t.y >= 2 and t.y <= 25 and t.fg == 3 then
                leftoverTreeCount = leftoverTreeCount + 1
            end
        end
    end

    LogToConsole("`w[`0Audit World`w] Gua Kotor: `e" .. unclearedCount .. "`w | Langit Bolong: `e" .. emptySkyCount .. "`w | Pohon Sisa: `e" .. leftoverTreeCount)

    if unclearedCount > 0 or emptySkyCount > 0 or leftoverTreeCount > 0 then
        return false
    end

    return true
end

function verifyAndPatchWorld()
    if not autoDF_running then return true end
    
    local retryLimit = 1
    local currentRetry = 0
    
    while autoDF_running and currentRetry < retryLimit do
        if isWorldAlreadyDone() then
            LogToConsole("`w[`2VERIFIKASI AMAN`w] World 100% selesai & tertutup rapat!")
            return true
        end
        
        currentRetry = currentRetry + 1
        LogToConsole("`4[`0Penambalan`4] Masih ada sisa/bagian bolong! Memulai penambalan ulang...")
        
        clrd_down_15()
        if not autoDF_running then return false end

        brkLv_12()
        if not autoDF_running then return false end

        clearLeftoverSafe()
        if not autoDF_running then return false end

        plcDrt_2()
        if not autoDF_running then return false end
        
        fillEmptyCaveTiles()
        if not autoDF_running then return false end
        
        Sleep(1000)
    end
    
    return isWorldAlreadyDone()
end

function StopAll()
    autoDF_running = false
    pcall(function()
        sendPacket(2, "action|input\n|left|0\n|right|0\n|up|0\n|down|0")
        sendPacket(2, "action|input\n|space|0")
    end)
    LogToConsole("`w[`0Auto DF`w]`4 STOP DITEKAN! Pengerjaan dihentikan.")
end

function mainDF()
    if not autoDF_running then return end
    if not nameworld or nameworld == "" then return end

    worldStartTime = os.time()

    warpDFWorld(nameworld)
    Sleep(7000)
    LogToConsole("`w[`0Auto DF`w] Masuk world: " .. tostring(nameworld))
    Sleep(1000)

    if UseRandomDF then
        local successSetup = setupNewRandomWorld()
        if not successSetup then 
            Sleep(3000)
            return 
        end
    end

    if not autoDF_running then return end

    if isWorldAlreadyDone() then 
        LogToConsole("`w[`0Auto DF`w] World " .. nameworld .. " SUDAH BERSIH! Pindah world...")
        collectgarbage("collect")
        return 
    end

    smpng_12()
    if not autoDF_running then return end
    
    plfS_15()
    if not autoDF_running then return end
    
    clrd_down_15()
    if not autoDF_running then return end
    
    brkLv_12()
    if not autoDF_running then return end

    if inv(2) < 30 then
        plntDf_122()
        if not autoDF_running then return end
    end

    plcDrt_2()
    if not autoDF_running then return end

    fillEmptyCaveTiles()
    if not autoDF_running then return end

    clearLeftoverSafe()
    if not autoDF_running then return end

    if verifyAndPatchWorld() then
        writeToLocal("finished_df.txt", os.date("[%Y-%m-%d %H:%M] ") .. nameworld .. "\n")
        LogToConsole("`w[`2SUCCESS`w] World " .. nameworld .. " selesai & dicatat!")
    else
        LogToConsole("`4[`0Warning`4] World " .. nameworld .. " masih ada bagian belum sempurna!")
    end

    -- STABILISASI MEMORI LOKAL
    collectgarbage("collect")
end

function LoopMultiWorld()
    while autoDF_running do
        if UseRandomDF then
            nameworld = generateRandomWorld(RandLength, RandWithNumber)
        else
            if index_world > #WorldList then index_world = 1 end
            nameworld = WorldList[index_world]
        end

        if nameworld then
            mainDF()
            worldCompletedCount = worldCompletedCount + 1
        end

        if not autoDF_running then return end

        -- CIKLIS COOLING DOWN (ANTI FC) SETIAP N WORLD SELESAI
        local restThreshold = Config.RestEveryWorld or 15
        local restTime = Config.RestDuration or 15
        if worldCompletedCount > 0 and (worldCompletedCount % restThreshold == 0) then
            LogToConsole("`w[`0Cooling Down`w] Telah merapikan " .. worldCompletedCount .. " world. Istirahat " .. restTime .. " detik untuk menyegarkan VRAM...")
            collectgarbage("collect")
            Sleep(restTime * 1000)
        end

        if not UseRandomDF then
            index_world = index_world + 1
            if index_world > #WorldList then index_world = 1 end
        end

        collectgarbage("collect")
        Sleep(3000)
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
add_smalltext|`eScript By LOLIStore|
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
                itemInfo = mgr:getItemInfoByID(math.floor(tonumber(pick) or 0))
            end
        end
        local nam1 = itemInfo and itemInfo.name or ("Unknown Item " .. tostring(pick))
        local dialogInput = {}
        dialogInput.v1 = "OnDialogRequest"
        dialogInput.v2 = [[
OnDialogRequest
set_default_color|`b
add_label_with_icon|big|`bFound `eItem ID|left|13818|
add_smalltext|`eScript By LOLIStore|
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
            "add_smalltext|`eScript By LOLIStore|",
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
            "text": "Script By LOLIStore"
        },
        {
            "type": "divider"
        },
        {
            "type": "button",
            "text": "Apply Config (Save Setelan)",
            "alias": "btn_apply_config"
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
                    "default": "]] .. table.concat(Config.WorldList, ",") .. [[",
                    "icon": "Edit",
                    "alias": "autodf_worldlist"
                },
                {
                    "type": "input_string",
                    "text": "List World Door ID (Opsional)",
                    "default": "]] .. Config.DFWorldDoor .. [[",
                    "icon": "Edit",
                    "alias": "autodf_worlddoor"
                },
                {
                    "type": "input_string",
                    "text": "World Save Seed (WORLD)",
                    "default": "]] .. Config.WorldSaveSeed .. [[",
                    "icon": "Edit",
                    "alias": "autodf_worldsaveseed"
                },
                {
                    "type": "input_string",
                    "text": "World Save Seed Door ID",
                    "default": "]] .. Config.WorldSaveSeedDoor .. [[",
                    "icon": "Edit",
                    "alias": "autodf_worldsaveseed_door"
                },
                {
                    "type": "toggle",
                    "text": "Random World (Auto DF)",
                    "default": ]] .. tostring(Config.UseRandomDF) .. [[,
                    "alias": "autodf_use_random"
                },
                {
                    "type": "slider",
                    "text": "Random Length",
                    "min": 1,
                    "max": 12,
                    "default": ]] .. Config.RandLength .. [[,
                    "alias": "rand_length"
                },
                {
                    "type": "toggle",
                    "text": "With Number (Angka)",
                    "default": ]] .. tostring(Config.RandWithNumber) .. [[,
                    "alias": "rand_with_number"
                },
                {
                    "type": "divider"
                },
                {
                    "type": "toggle",
                    "text": "Verify before punch",
                    "default": ]] .. tostring(Config.VerifyPunch) .. [[,
                    "alias": "verify_punch"
                },
                {
                    "type": "toggle",
                    "text": "Break",
                    "default": ]] .. tostring(Config.EnableBreak) .. [[,
                    "alias": "enable_break"
                },
                {
                    "type": "toggle",
                    "text": "Place",
                    "default": ]] .. tostring(Config.EnablePlace) .. [[,
                    "alias": "enable_place"
                },
                {
                    "type": "slider",
                    "text": "Hit Count",
                    "min": 1,
                    "max": 40,
                    "default": ]] .. Config.HitCount .. [[,
                    "alias": "hit_count"
                },
                {
                    "type": "input_int",
                    "text": "Delay Break",
                    "default": "]] .. Config.DelayBreak .. [[",
                    "label": "ms",
                    "placeholder": "millisecond",
                    "icon": "Verified",
                    "alias": "autodf_delaybreak"
                },
                {
                    "type": "input_int",
                    "text": "Delay Place",
                    "default": "]] .. Config.DelayPlace .. [[",
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
            "text": "Cek Posisi Saya Sekarang (Console Log)",
            "default": false,
            "alias": "toggle_pos_check"
        },
        {
            "type": "divider"
        },
        {
            "type": "dialog",
            "text": "Drop Item Setting (8 Slots)",
            "support_text": "Pengaturan Slot Drop Item",
            "fill": true,
            "menu": [
                {
                    "type": "toggle",
                    "text": "Drop Item",
                    "default": ]] .. tostring(Config.AutoDropEnabled) .. [[,
                    "alias": "autodrop_toggle"
                },
                {
                    "type": "input_string",
                    "text": "World Drop Item",
                    "default": "]] .. Config.DropWorld .. [[",
                    "icon": "Edit",
                    "alias": "drop_world"
                },
                {
                    "type": "input_string",
                    "text": "Door",
                    "default": "]] .. Config.DropDoor .. [[",
                    "icon": "Edit",
                    "alias": "drop_door"
                },
                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 1 (Seed Dirt) ---" },
                { "type": "input_int", "text": "ID Item 1", "default": "]] .. Config.ItemSlots[1].id .. [[", "alias": "item1_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[1].min .. [[", "alias": "item1_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[1].x .. [[", "alias": "item1_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[1].y .. [[", "alias": "item1_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 2 (Dirt Block) ---" },
                { "type": "input_int", "text": "ID Item 2", "default": "]] .. Config.ItemSlots[2].id .. [[", "alias": "item2_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[2].min .. [[", "alias": "item2_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[2].x .. [[", "alias": "item2_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[2].y .. [[", "alias": "item2_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 3 (Seed Cave) ---" },
                { "type": "input_int", "text": "ID Item 3", "default": "]] .. Config.ItemSlots[3].id .. [[", "alias": "item3_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[3].min .. [[", "alias": "item3_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[3].x .. [[", "alias": "item3_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[3].y .. [[", "alias": "item3_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 4 (Cave Block) ---" },
                { "type": "input_int", "text": "ID Item 4", "default": "]] .. Config.ItemSlots[4].id .. [[", "alias": "item4_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[4].min .. [[", "alias": "item4_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[4].x .. [[", "alias": "item4_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[4].y .. [[", "alias": "item4_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 5 (Seed Rock) ---" },
                { "type": "input_int", "text": "ID Item 5", "default": "]] .. Config.ItemSlots[5].id .. [[", "alias": "item5_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[5].min .. [[", "alias": "item5_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[5].x .. [[", "alias": "item5_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[5].y .. [[", "alias": "item5_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 6 (Rock Block) ---" },
                { "type": "input_int", "text": "ID Item 6", "default": "]] .. Config.ItemSlots[6].id .. [[", "alias": "item6_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[6].min .. [[", "alias": "item6_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[6].x .. [[", "alias": "item6_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[6].y .. [[", "alias": "item6_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 7 (Seed Lava) ---" },
                { "type": "input_int", "text": "ID Item 7", "default": "]] .. Config.ItemSlots[7].id .. [[", "alias": "item7_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[7].min .. [[", "alias": "item7_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[7].x .. [[", "alias": "item7_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[7].y .. [[", "alias": "item7_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 8 (Lava Block) ---" },
                { "type": "input_int", "text": "ID Item 8", "default": "]] .. Config.ItemSlots[8].id .. [[", "alias": "item8_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "]] .. Config.ItemSlots[8].min .. [[", "alias": "item8_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "]] .. Config.ItemSlots[8].x .. [[", "alias": "item8_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "]] .. Config.ItemSlots[8].y .. [[", "alias": "item8_y" }
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
                    "default": ]] .. tostring(Config.AutoPickEnabled) .. [[,
                    "alias": "autopick_toggle"
                },
                {
                    "type": "toggle",
                    "text": "Mode: Auto find",
                    "default": ]] .. tostring(Config.AutoFind_Enabled) .. [[,
                    "alias": "autofind_toggle"
                },
                {
                    "type": "divider"
                },
                {
                    "type": "toggle",
                    "text": "Pick Door Entrance",
                    "default": ]] .. tostring(Config.PickDoor_Enabled) .. [[,
                    "alias": "pick_door_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Door World Name",
                    "default": "]] .. Config.PickDoor_World .. [[",
                    "icon": "Edit",
                    "alias": "pick_door_world"
                },
                {
                    "type": "input_string",
                    "text": "Door ID / Door Name",
                    "default": "]] .. Config.PickDoor_Door .. [[",
                    "icon": "Edit",
                    "alias": "pick_door_doorid"
                },
                {
                    "type": "input_int",
                    "text": "Door Item ID",
                    "default": "]] .. Config.PickDoor_ID .. [[",
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
                    "default": ]] .. tostring(Config.PickWL_Enabled) .. [[,
                    "alias": "pick_wl_toggle"
                },
                {
                    "type": "input_string",
                    "text": "WL World Name",
                    "default": "]] .. Config.PickWL_World .. [[",
                    "icon": "Edit",
                    "alias": "pick_wl_world"
                },
                {
                    "type": "input_string",
                    "text": "WL Door ID",
                    "default": "]] .. Config.PickWL_Door .. [[",
                    "icon": "Edit",
                    "alias": "pick_wl_doorid"
                },
                {
                    "type": "input_int",
                    "text": "WL Item ID",
                    "default": "]] .. Config.PickWL_ID .. [[",
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
                    "default": ]] .. tostring(Config.PickPlat_Enabled) .. [[,
                    "alias": "pick_plat_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Plat World Name",
                    "default": "]] .. Config.StoragePlatWorld .. [[",
                    "icon": "Edit",
                    "alias": "pick_plat_world"
                },
                {
                    "type": "input_string",
                    "text": "Plat Door ID",
                    "default": "]] .. Config.StoragePlatDoor .. [[",
                    "icon": "Edit",
                    "alias": "pick_plat_doorid"
                },
                {
                    "type": "input_int",
                    "text": "Plat Item ID",
                    "default": "]] .. Config.PlatformID .. [[",
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

addIntoModule(module_json)

function onValue(type_evt, name, value)
    if name == "autodf_worldlist" then
        local worlds = {}
        for w in tostring(value):gmatch("[^,%s]+") do table.insert(worlds, w) end
        if #worlds > 0 then 
            Config.WorldList = worlds
            WorldList = worlds 
            if index_world > #WorldList then index_world = 1 end
        end
    elseif name == "autodf_worlddoor" then Config.DFWorldDoor = tostring(value); DFWorldDoor = Config.DFWorldDoor
    elseif name == "autodf_worldsaveseed" then Config.WorldSaveSeed = tostring(value); worldsaveseed = Config.WorldSaveSeed
    elseif name == "autodf_worldsaveseed_door" then Config.WorldSaveSeedDoor = tostring(value); worldsaveseedDoor = Config.WorldSaveSeedDoor
    elseif name == "autodf_use_random" then Config.UseRandomDF = value; UseRandomDF = value
    elseif name == "rand_length" then Config.RandLength = math.floor(tonumber(value) or 5); RandLength = Config.RandLength
    elseif name == "rand_with_number" then Config.RandWithNumber = value; RandWithNumber = value
    elseif name == "verify_punch" then Config.VerifyPunch = value; VerifyPunch = value
    elseif name == "enable_break" then Config.EnableBreak = value; EnableBreak = value
    elseif name == "enable_place" then Config.EnablePlace = value; EnablePlace = value
    elseif name == "hit_count" then Config.HitCount = math.floor(tonumber(value) or 1); HitCount = Config.HitCount
    elseif name == "autodf_delaybreak" then Config.DelayBreak = math.floor(tonumber(value) or dbk); dbk = Config.DelayBreak
    elseif name == "autodf_delayplace" then Config.DelayPlace = math.floor(tonumber(value) or dpc); dpc = Config.DelayPlace

    elseif name == "btn_apply_config" then
        applyConfig()
        LogToConsole("`w[`2SUCCESS`w] Config berhasil disimpan & diterapkan!")

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

    elseif name == "autodrop_toggle" then Config.AutoDropEnabled = value; AutoDropEnabled = value
    elseif name == "drop_world" then Config.DropWorld = tostring(value); DropWorld = Config.DropWorld
    elseif name == "drop_door" then Config.DropDoor = tostring(value); DropDoor = Config.DropDoor

    elseif name:find("^item(%d+)_([%w_]+)$") then
        local idxStr, prop = name:match("^item(%d+)_([%w_]+)$")
        local idx = tonumber(idxStr)
        if idx and idx >= 1 and idx <= 8 then
            if prop == "id" then Config.ItemSlots[idx].id = math.floor(tonumber(value) or 0)
            elseif prop == "min" then Config.ItemSlots[idx].min = math.floor(tonumber(value) or 0)
            elseif prop == "x" then Config.ItemSlots[idx].x = math.floor(tonumber(value) or 0)
            elseif prop == "y" then Config.ItemSlots[idx].y = math.floor(tonumber(value) or 0)
            end
            ItemSlots = Config.ItemSlots
        end

    elseif name == "autopick_toggle" then Config.AutoPickEnabled = value; AutoPickEnabled = value
    elseif name == "autofind_toggle" then Config.AutoFind_Enabled = value; AutoFind_Enabled = value
    
    elseif name == "pick_door_toggle" then Config.PickDoor_Enabled = value; PickDoor_Enabled = value
    elseif name == "pick_door_world" then Config.PickDoor_World = tostring(value); PickDoor_World = Config.PickDoor_World
    elseif name == "pick_door_doorid" then Config.PickDoor_Door = tostring(value); PickDoor_Door = Config.PickDoor_Door
    elseif name == "pick_door_id" then 
        Config.PickDoor_ID = math.floor(tonumber(value) or 5036)
        PickDoor_ID = Config.PickDoor_ID
        EntranceID = PickDoor_ID
    
    elseif name == "pick_wl_toggle" then Config.PickWL_Enabled = value; PickWL_Enabled = value
    elseif name == "pick_wl_world" then Config.PickWL_World = tostring(value); PickWL_World = Config.PickWL_World
    elseif name == "pick_wl_doorid" then Config.PickWL_Door = tostring(value); PickWL_Door = Config.PickWL_Door
    elseif name == "pick_wl_id" then 
        Config.PickWL_ID = math.floor(tonumber(value) or 242)
        PickWL_ID = Config.PickWL_ID
        WorldLockID = PickWL_ID
    
    elseif name == "pick_plat_toggle" then Config.PickPlat_Enabled = value; PickPlat_Enabled = value
    elseif name == "pick_plat_world" then Config.StoragePlatWorld = tostring(value); StoragePlatWorld = Config.StoragePlatWorld
    elseif name == "pick_plat_doorid" then Config.StoragePlatDoor = tostring(value); StoragePlatDoor = Config.StoragePlatDoor
    elseif name == "pick_plat_id" then Config.PlatformID = math.floor(tonumber(value) or 1324); PlatformID = Config.PlatformID
    
    elseif name == "btn_itemfinder" then openItemFinderDialog()
    
    elseif name == "btn_autodf" then
        autoDF_running = value
        if value == true then
            botStartTime = os.time()
            LogToConsole("`w[`0Auto DF`w] Config terpasang & bot siap dikerjakan!")
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

sendVariant({v1 = "OnTextOverlay", v2 = "`9Script Dirt Farm `wby `2LOLIStore"})

runCoroutine(function()
    while true do
        if autoDF_running then
            LoopMultiWorld()
        else
            Sleep(300)
        end
    end
end)

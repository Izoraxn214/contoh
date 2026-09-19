-- ==========================================
-- GLOBAL STATE VARIABLES (FULL CONTROLLED BY MGUI)
-- ==========================================
WorldList = {"TKTYW", "QVSVF", "FCMQW", "DEJCA", "ACMFA", "FZSGR", "KWYRY", "DWTWG", "JZUXA", "TUIGE", "JTLQM", "IMCKM", "DQKQU", "FUQRB", "WZWGW"}
index_world = 1
nameworld = WorldList[index_world]

worldsaveseed = "PLATSAVEHAM"
worldsaveseedDoor = "12345"

dpc = 120 -- Delay Place (ms)
dbk = 220 -- Delay Break (ms)

PlatformID = 1324
StoragePlatWorld = "PLATSAVEHAM"
StoragePlatDoor = "12345"
PickPlat_Enabled = true

WorldLockID = 242
EntranceID = 6

EditToggle("Antibounce", true)
EditToggle("ModFly", true)
EditToggle("Antilag", true)
EditToggle("Fast Trash", true)
EditToggle("Fast Drop", true)
EditToggle("Cant Pickup Item", true)
EditToggle("Anti Lava", true)

autoDF_running = false

EnableBreak = true
EnablePlace = true
HitCount = 1
VerifyPunch = false

DFWorldDoor = "IWP2145"

-- LOGIKA AUTO DROP 8 SLOTS (SAFE DIALOG TIMING)
AutoDropEnabled = true

DropWorld = "PLATSAVEHAM"
DropDoor = "12345"

ItemSlots = {
    { id = 3,  min = 190, x = 55, y = 21 }, -- Seed Dirt
    { id = 2,  min = 190, x = 55, y = 18 }, -- Dirt
    { id = 15, min = 190, x = 47, y = 21 }, -- Seed Cave
    { id = 14, min = 50,  x = 47, y = 18 }, -- Cave
    { id = 11, min = 190, x = 47, y = 15 }, -- Seed Rock
    { id = 10, min = 50,  x = 47, y = 12 }, -- Rock
    { id = 5,  min = 190, x = 55, y = 15 }, -- Seed Lava
    { id = 4,  min = 50,  x = 55, y = 12 }  -- Lava
}

-- DISCORD WEBHOOK VARIABLES
WebhookEnabled = false
WebhookURL = ""
WebhookUserID = ""

botStartTime = os.time()
worldStartTime = os.time()

AutoPickEnabled = true
AutoFind_Enabled = true

PickDoor_Enabled = true
PickDoor_World = "PLATSAVEHAM"
PickDoor_Door = "12345"
PickDoor_ID = 5036

PickWL_Enabled = true
PickWL_World = "PLATSAVEHAM"
PickWL_Door = "12345"
PickWL_ID = 242

UseRandomDF = false
RandLength = 5
RandWithNumber = false

math.randomseed(os.time())

local function isUnbreakable(fg)
    local id = tonumber(fg) or 0
    return id == 8 or id == 6 or id == 242 or id == 202 or id == 204 or id == 206 or id == 2408 or id == 4994 or id == 1790
end

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

local function sendDiscordWebhookEmbed(statusType, customMessage)
    if not WebhookEnabled or WebhookURL == "" or not WebhookURL:find("http") then return end

    local pName = "Unknown"
    local p = getLocal()
    if p and p.name then pName = p.name end

    local execTimeStr = formatTime(os.time() - worldStartTime)
    local uptimeStr = formatTime(os.time() - botStartTime)
    local progressStr = index_world .. " / " .. #WorldList

    local title = "DIRT FARM COMPLETED"
    local color = 3066993 -- Hijau
    local statusDesc = "100% Cleared & Sealed"

    if statusType == "STARTED" then
        title = "DIRT FARM STARTED"
        color = 3447003 -- Biru
        statusDesc = "Working..."
    elseif statusType == "WARNING" or statusType == "ERROR" then
        title = "DIRT FARM ALERT"
        color = 15158332 -- Merah
        statusDesc = customMessage or "Need Attention!"
    end

    local pingText = ""
    if WebhookUserID ~= "" and (statusType == "WARNING" or statusType == "ERROR") then
        pingText = "<@" .. WebhookUserID .. "> "
    end

    local jsonPayload = string.format([[
    {
      "content": "%s",
      "username": "LOLIStore Helper",
      "embeds": [
        {
          "title": "%s",
          "color": %d,
          "fields": [
            { "name": "Account", "value": "%s", "inline": true },
            { "name": "World", "value": "%s", "inline": true },
            { "name": "Progress", "value": "%s", "inline": true },
            { "name": "Execute Time", "value": "%s", "inline": true },
            { "name": "Total Uptime", "value": "%s", "inline": true },
            { "name": "Status", "value": "%s", "inline": true }
          ],
          "footer": {
            "text": "Script Dirt Farm by LOLIStore • %s"
          }
        }
      ]
    }]], pingText, title, color, pName, nameworld, progressStr, execTimeStr, uptimeStr, statusDesc, os.date("%Y-%m-%d %H:%M:%S"))

    pcall(function()
        if type(makeRequest) == "function" then
            makeRequest(WebhookURL, "POST", {["Content-Type"] = "application/json"}, jsonPayload)
        elseif type(httpPost) == "function" then
            httpPost(WebhookURL, jsonPayload)
        elseif type(httpRequest) == "function" then
            httpRequest(WebhookURL, "POST", jsonPayload)
        end
    end)
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

    local dist = math.abs(curX - targetX) + math.abs(curY - targetY)
    maxWaitMs = maxWaitMs or math.min(2000, math.max(1000, dist * 200))

    FindPath(targetX, targetY)

    local elapsed = 0
    while autoDF_running and elapsed < maxWaitMs do
        Sleep(150)
        elapsed = elapsed + 150
        local pl = getLocal()
        if pl and pl.posX and pl.posY then
            local pxTile = pl.posX // 32
            local pyTile = pl.posY // 32
            if pxTile == targetX and pyTile == targetY then
                Sleep(150)
                return true
            end
        end
    end
    return false
end

-- FIX NO 3: DYNAMIC PACKET STATE (MENGGUNAKAN STATE ASLI KARAKTER)
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
    packet.state = (p and p.state) and p.state or 0 -- Dynamic state dari local player
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

-- FIX NO 4: LIMIT 3 ITEM PER CYCLE + DELAY 250ms (ANTI-SPAM PACKET 11)
function sdt_11(range)
    local localPlayer = getLocal()
    if not localPlayer then return end

    local pickedCount = 0
    local maxPickPerCycle = 3

    for _, object in pairs(safeGetObjectList()) do
        if object then
            local itemID = math.floor(tonumber(object.itemid or object.type or object.item_id) or 0)
            if math.abs(localPlayer.posX - (object.posX or 0)) <= (32 * range) and
               math.abs(localPlayer.posY - (object.posY or 0)) < (32 * range) and inv(itemID) < 200 then
                sdtr_11(object)
                pickedCount = pickedCount + 1
                Sleep(250) -- Delay dinaikkan agar natural
                if pickedCount >= maxPickPerCycle then
                    break
                end
            end
        end
    end
end

function hasWorldLock()
    for _, tile in pairs(safeGetTiles()) do
        if tile and (isUnbreakable(tile.fg) or isUnbreakable(tile.bg)) then
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
            sendDiscordWebhookEmbed("WARNING", "World Storage WL/Door belum diisi!")
            return
        end

        warp(targetStorageWorld, targetStorageDoor)
        Sleep(6000)
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
                        local targetX = math.max(0, math.floor(((object.posX or 0) + 8) / 32) - 1)
                        local targetY = math.floor((object.posY or 0) / 32)
                        walkTo(targetX, targetY, 2000)
                        Sleep(500)
                        sdtr_11(object)
                        sdt_11(5)
                        Sleep(500)
                        if inv(WorldLockID) > 0 and inv(EntranceID) >= 2 then
                            break
                        end
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
        Sleep(6000)
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

-- FIX NO 1: AUTO DROP JEDA 600ms MENUNGGU DIALOG RESMI SERVER
function processAutoDropAndTrash()
    if not autoDF_running or not AutoDropEnabled then return end

    local currentWorld = safeGetWorldName()
    if currentWorld == "" then return end

    for idx, slot in ipairs(ItemSlots) do
        if not autoDF_running then return end

        if slot.id > 0 and slot.min > 0 then
            local jml = inv(slot.id)
            if jml >= slot.min and DropWorld ~= "" then
                LogToConsole("`w[`0Auto Drop`w] Item ID (" .. slot.id .. ") capai limit (" .. jml .. "/" .. slot.min .. "). Meluncur ke World Drop: " .. DropWorld)
                warp(DropWorld, DropDoor)
                Sleep(6000)
                waitForTilesToLoad()
                walkTo(slot.x, slot.y, 2000)
                Sleep(1000)
                sendPacket(2, "action|drop\nitemID|" .. slot.id)
                Sleep(600) -- Jeda aman menunggu server membuka dialog secara resmi
                sendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. slot.id .. "|\ncount|" .. jml)
                Sleep(2000)
                warpDFWorld(currentWorld)
                Sleep(6000)
                waitForTilesToLoad()
            end
        end
    end
end

function processAutoPick()
    if not autoDF_running then return end
    if AutoPickEnabled and AutoFind_Enabled then
        sdt_11(5)
    end
    processAutoDropAndTrash()
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
                        local ox = math.floor(((obj.posX or 0) + 8) / 32)
                        local oy = math.floor((obj.posY or 0) / 32)
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
end

function ambilSeed(id, jumlah)
    if not autoDF_running then return end
    if inv(id) < jumlah then
        if worldsaveseed == "" then return end
        LogToConsole("`w[`0Setup`w] Restock Seed/Item (" .. id .. ") ke Save World: " .. worldsaveseed)
        
        local initialAmount = inv(id)
        warp(worldsaveseed, worldsaveseedDoor)
        Sleep(6000)
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
                        local targetX = math.max(0, math.floor(((object.posX or 0) + 8) / 32) - 1)
                        local targetY = math.floor((object.posY or 0) / 32)
                        walkTo(targetX, targetY, 2000)
                        Sleep(500)
                        sdtr_11(object)
                        sdt_11(5)
                        Sleep(600)
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
        Sleep(6000)
        waitForTilesToLoad()
        Sleep(1000)

        if inv(id) <= initialAmount then
            LogToConsole("`4[`0Warning`4] Stok item di Storage habis atau gagal dipungut! Melanjutkan...")
            sendDiscordWebhookEmbed("WARNING", "Stok Seed/Item (" .. id .. ") di Storage habis!")
        end
    end
end

function plntDf_122()
    if not autoDF_running then return end
    if inv(2) >= 30 then return end

    LogToConsole("`w[`0Auto DF`w] Kehabisan Dirt Block! Menanam & memanen Dirt Seed mandiri...")
    walkTo(2, 22, 2000)
    Sleep(500)

    while autoDF_running do
        for tilex = 2, 25 do
            if not autoDF_running then return end
            if inv(3) == 0 then
                ambilSeed(3, 50)
                Sleep(200)
            end

            local tile = safeTile(tilex, 23)

            if tile.fg == 3 and tile.readyharvest then
                walkTo(tilex, 22, 1500)
                Sleep(200)
                while safeTile(tilex, 23).fg == 3 and safeTile(tilex, 23).readyharvest and autoDF_running do
                    tnjk1_3(tilex, 23)
                    Sleep(dbk)
                end
                sdt_11(5)
                processAutoDropAndTrash()
            end

            if tile.fg == 0 and inv(3) > 0 then
                walkTo(tilex, 22, 1500)
                Sleep(200)
                while safeTile(tilex, 23).fg == 0 and inv(3) > 0 and autoDF_running do
                    trh1_3(tilex, 23, 3)
                    Sleep(dpc)
                end
            end

            if inv(2) >= 30 then break end
        end

        if inv(2) >= 30 then break end
        
        local waitElapsed = 0
        while autoDF_running and waitElapsed < 5000 do
            Sleep(500)
            waitElapsed = waitElapsed + 500
        end
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
                
                local reached = walkTo(standX, tiley - 1, 1500)
                
                if not reached then
                    local curP = getLocal()
                    if curP and curP.posX and curP.posY then
                        local curX = curP.posX // 32
                        local curY = curP.posY // 32
                        local stepX = (standX > curX) and (curX + 1) or (curX - 1)
                        if safeTile(stepX, curY).fg ~= 0 and not isUnbreakable(safeTile(stepX, curY).fg) then
                            tnjk1_3(stepX, curY)
                            Sleep(dbk)
                        end
                    end
                    reached = walkTo(standX, tiley - 1, 1500)
                end

                if reached then
                    Sleep(100)
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
    end

    clearSideColumns(0, 1, 0)
    clearSideColumns(98, 99, 99)
end

function plfS_15()
    if not autoDF_running or not PickPlat_Enabled then return end

    if inv(PlatformID) < 52 then
        if StoragePlatWorld == "" then
            LogToConsole("`4[`0Plat Error`4] Nama World Storage Platform belum diisi!")
            sendDiscordWebhookEmbed("WARNING", "World Storage Platform belum diisi!")
            return
        end

        LogToConsole("`w[`0Auto DF`w] Platform kurang (" .. inv(PlatformID) .. "/52). Ambil ke Storage: " .. StoragePlatWorld)
        warp(StoragePlatWorld, StoragePlatDoor)
        Sleep(6000)
        waitForTilesToLoad()
        Sleep(1500)
        
        local attempts = 0
        while inv(PlatformID) < 52 and autoDF_running and attempts < 5 do
            local foundAny = false
            for _, object in pairs(safeGetObjectList()) do
                if not autoDF_running then return end
                if object then
                    local itemID = math.floor(tonumber(object.itemid or object.type or object.item_id) or 0)
                    if itemID == math.floor(tonumber(PlatformID) or 102) then
                        foundAny = true
                        local targetX = math.max(0, math.floor(((object.posX or 0) + 8) / 32) - 1)
                        local targetY = math.floor((object.posY or 0) / 32)
                        walkTo(targetX, targetY, 2000)
                        Sleep(400)
                        sdtr_11(object)
                        sdt_11(5)
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
        Sleep(6000)
        waitForTilesToLoad()
        Sleep(1000)
    end

    local currentPlatCount = inv(PlatformID)
    LogToConsole("`w[`0Auto DF`w] Stok Platform di backpack: `e" .. currentPlatCount)
    if currentPlatCount == 0 then
        LogToConsole("`4[`0Warning`4] Stok Platform di backpack 0! Pemasangan platform dilewati...")
        return
    end

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
    LogToConsole("`w[`0Auto DF`w] Platform samping selesai. Refresh warp...")
    local currentWorld = safeGetWorldName()
    if currentWorld ~= "" then
        warpDFWorld(currentWorld)
        Sleep(6000)
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
                    ambilSeed(3, 50)
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
            walkTo(tilex, tiley + 1, 1500)
            Sleep(300)
            for i = 1, 5 do
                local tx = (tilex - 3) + i
                if tx >= 2 and tx <= 97 and safeTile(tx, tiley).fg == 0 then
                    if inv(2) == 0 and autoDF_running then
                        ambilSeed(3, 50)
                        plntDf_122()
                        Sleep(200)
                        walkTo(tilex, tiley + 1, 2000)
                        Sleep(300)
                    end
                    local retry = 0
                    while safeTile(tx, tiley).fg == 0 and inv(2) > 0 and autoDF_running and retry < 5 do
                        if not trh1_3(tx, tiley, 2) then
                            walkTo(tilex, tiley + 1, 1000)
                            Sleep(150)
                        end
                        Sleep(dpc)
                        retry = retry + 1
                    end
                end
            end
            processAutoPick()
        end
    end
end

function fillEmptyCaveTiles()
    if not autoDF_running then return end
    LogToConsole("`w[`0Auto DF`w] Menutupi sisa ubin gua yang belum terpasang dirt...")

    for tiley = 24, 53 do
        if not autoDF_running then return end
        for tilex = 0, 99 do
            if not autoDF_running then return end
            local tile = safeTile(tilex, tiley)

            if tile and tile.bg == 14 and tile.fg == 0 then
                local reached = walkTo(tilex, tiley - 1, 1000)
                if not reached then
                    reached = walkTo(tilex - 1, tiley, 1000) or walkTo(tilex + 1, tiley, 1000)
                end

                if reached then
                    if inv(2) == 0 and autoDF_running then
                        ambilSeed(3, 50)
                        plntDf_122()
                        Sleep(200)
                    end

                    local timeout = 0
                    while safeTile(tilex, tiley).fg == 0 and inv(2) > 0 and autoDF_running and timeout < 5 do
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
    LogToConsole("`w[`0Auto DF`w] Membersihkan sisa pohon & item tercecer...")
    Sleep(1000)

    for tiley = 2, 24 do
        if not autoDF_running then return end
        for tilex = 0, 99 do
            if not autoDF_running then return end
            local tile = safeTile(tilex, tiley)

            if tile.fg == 3 and tile.readyharvest then
                walkTo(tilex, tiley + 1, 1500)
                Sleep(150)
                while safeTile(tilex, tiley).fg == 3 and safeTile(tilex, tiley).readyharvest and autoDF_running do
                    tnjk1_3(tilex, tiley)
                    Sleep(dbk)
                end
                sdt_11(5)
                processAutoDropAndTrash()
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
    if not waitForTilesToLoad() then
        LogToConsole("`4[`0Warning`4] Data tile world gagal ter-load sempurna! Melanjutkan pemindaian...")
        return false
    end

    local unclearedCount = 0
    local emptySkyCount = 0

    for tiley = 24, 53 do
        for tilex = 0, 99 do
            local t = safeTile(tilex, tiley)
            if t.bg == 14 or (t.fg ~= 0 and not isUnbreakable(t.fg)) then 
                unclearedCount = unclearedCount + 1
            end
        end
        Sleep(5)
    end

    for tiley = 2, 23 do
        for tilex = 2, 97 do
            local t = safeTile(tilex, tiley)
            if t.fg == 0 then
                emptySkyCount = emptySkyCount + 1
            end
        end
        Sleep(5)
    end

    LogToConsole("`w[`0Audit Total 100%`w] Gua Kotor: `e" .. unclearedCount .. "`w ubin | Langit Kosong: `e" .. emptySkyCount .. "`w ubin")

    if unclearedCount > 0 or emptySkyCount > 0 then
        return false
    end

    return true
end

function verifyAndPatchWorld()
    if not autoDF_running then return true end
    LogToConsole("`w[`0Audit Akhir`w] Memeriksa ulang seluruh world sebelum pindah...")
    
    local retryLimit = 3
    local currentRetry = 0
    
    while autoDF_running and currentRetry < retryLimit do
        if isWorldAlreadyDone() then
            LogToConsole("`w[`2VERIFIKASI AMAN`w] World 100% selesai & tertutup rapat!")
            return true
        end
        
        currentRetry = currentRetry + 1
        LogToConsole("`4[`0Penambalan`4] Masih ada ubin bolong/kotor! Memulai perbaikan otomatis ke-" .. currentRetry .. "...")
        
        plcDrt_2()
        if not autoDF_running then return false end
        
        fillEmptyCaveTiles()
        if not autoDF_running then return false end
        
        clearLeftoverSafe()
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
    LogToConsole("`w[`0Auto DF`w]`4 STOP DITEKAN! Pergerakan & pengerjaan dihentikan.")
end

function mainDF()
    if not autoDF_running then return end
    if not nameworld or nameworld == "" then return end

    worldStartTime = os.time()

    warpDFWorld(nameworld)
    Sleep(6000)
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
        LogToConsole("`w[`0Auto DF`w] World " .. nameworld .. " SUDAH BERSIH / SELESAI! Memotong ke world berikutnya...")
        return 
    end
    
    sendDiscordWebhookEmbed("STARTED")

    smpng_12()
    if not autoDF_running then return end
    
    plfS_15()
    if not autoDF_running then return end
    
    clrd_down_15()
    if not autoDF_running then return end
    
    brkLv_12()
    if not autoDF_running then return end

    if inv(3) < 25 then
        ambilSeed(3, 50)
        if not autoDF_running then return end
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
        LogToConsole("`w[`2SUCCESS`w] World " .. nameworld .. " selesai & dicatat ke finished_df.txt!")
        sendDiscordWebhookEmbed("COMPLETED")
    else
        LogToConsole("`4[`0Warning`4] World " .. nameworld .. " masih ada bagian belum tertutup sempurna setelah 3x penambalan!")
        sendDiscordWebhookEmbed("WARNING", "World gagal ditutup sempurna setelah 3x penambalan!")
    end
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
        end

        if not autoDF_running then return end
        if not UseRandomDF then
            index_world = index_world + 1
            if index_world > #WorldList then index_world = 1 end
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
            "type": "dialog",
            "text": "Autofarm Setting",
            "support_text": "Settings for autofarm",
            "fill": true,
            "menu": [
                {
                    "type": "input_string",
                    "text": "List World",
                    "default": "TKTYW,QVSVF,FCMQW,DEJCA,ACMFA,FZSGR,KWYRY,DWTWG,JZUXA,TUIGE,JTLQM,IMCKM,DQKQU,FUQRB,WZWGW",
                    "icon": "Edit",
                    "alias": "autodf_worldlist"
                },
                {
                    "type": "input_string",
                    "text": "List World Door ID (Opsional)",
                    "default": "IWP2145",
                    "icon": "Edit",
                    "alias": "autodf_worlddoor"
                },
                {
                    "type": "input_string",
                    "text": "World Save Seed (WORLD)",
                    "default": "PLATSAVEHAM",
                    "icon": "Edit",
                    "alias": "autodf_worldsaveseed"
                },
                {
                    "type": "input_string",
                    "text": "World Save Seed Door ID",
                    "default": "12345",
                    "icon": "Edit",
                    "alias": "autodf_worldsaveseed_door"
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
            "text": "Cek Posisi Saya Sekarang (Console Log)",
            "default": false,
            "alias": "toggle_pos_check"
        },
        {
            "type": "divider"
        },
        {
            "type": "dialog",
            "text": "Discord Webhook Setting",
            "support_text": "Pengaturan Notifikasi Discord",
            "fill": true,
            "menu": [
                {
                    "type": "toggle",
                    "text": "Enable Discord Webhook",
                    "default": false,
                    "alias": "webhook_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Discord Webhook URL",
                    "default": "",
                    "icon": "Edit",
                    "alias": "webhook_url"
                },
                {
                    "type": "input_string",
                    "text": "Discord User ID (Ping on Alert)",
                    "default": "",
                    "icon": "Edit",
                    "alias": "webhook_userid"
                }
            ]
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
                    "default": true,
                    "alias": "autodrop_toggle"
                },
                {
                    "type": "input_string",
                    "text": "World Drop Item",
                    "default": "PLATSAVEHAM",
                    "icon": "Edit",
                    "alias": "drop_world"
                },
                {
                    "type": "input_string",
                    "text": "Door",
                    "default": "12345",
                    "icon": "Edit",
                    "alias": "drop_door"
                },
                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 1 (Seed Dirt) ---" },
                { "type": "input_int", "text": "ID Item 1", "default": "3", "alias": "item1_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "190", "alias": "item1_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "55", "alias": "item1_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "21", "alias": "item1_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 2 (Dirt Block) ---" },
                { "type": "input_int", "text": "ID Item 2", "default": "2", "alias": "item2_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "190", "alias": "item2_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "55", "alias": "item2_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "18", "alias": "item2_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 3 (Seed Cave) ---" },
                { "type": "input_int", "text": "ID Item 3", "default": "15", "alias": "item3_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "190", "alias": "item3_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "47", "alias": "item3_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "21", "alias": "item3_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 4 (Cave Block) ---" },
                { "type": "input_int", "text": "ID Item 4", "default": "14", "alias": "item4_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "50", "alias": "item4_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "47", "alias": "item4_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "18", "alias": "item4_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 5 (Seed Rock) ---" },
                { "type": "input_int", "text": "ID Item 5", "default": "11", "alias": "item5_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "190", "alias": "item5_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "47", "alias": "item5_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "15", "alias": "item5_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 6 (Rock Block) ---" },
                { "type": "input_int", "text": "ID Item 6", "default": "10", "alias": "item6_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "50", "alias": "item6_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "47", "alias": "item6_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "12", "alias": "item6_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 7 (Seed Lava) ---" },
                { "type": "input_int", "text": "ID Item 7", "default": "5", "alias": "item7_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "190", "alias": "item7_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "55", "alias": "item7_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "15", "alias": "item7_y" },

                { "type": "divider" },
                { "type": "labelapp", "icon": "Verified", "text": "--- ITEM 8 (Lava Block) ---" },
                { "type": "input_int", "text": "ID Item 8", "default": "4", "alias": "item8_id" },
                { "type": "input_int", "text": "Minimal Drop", "default": "50", "alias": "item8_min" },
                { "type": "input_int", "text": "Koordinat X", "default": "55", "alias": "item8_x" },
                { "type": "input_int", "text": "Koordinat Y", "default": "12", "alias": "item8_y" }
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
                    "default": true,
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
                    "default": true,
                    "alias": "pick_door_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Door World Name",
                    "default": "PLATSAVEHAM",
                    "icon": "Edit",
                    "alias": "pick_door_world"
                },
                {
                    "type": "input_string",
                    "text": "Door ID / Door Name",
                    "default": "12345",
                    "icon": "Edit",
                    "alias": "pick_door_doorid"
                },
                {
                    "type": "input_int",
                    "text": "Door Item ID",
                    "default": "5036",
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
                    "default": true,
                    "alias": "pick_wl_toggle"
                },
                {
                    "type": "input_string",
                    "text": "WL World Name",
                    "default": "PLATSAVEHAM",
                    "icon": "Edit",
                    "alias": "pick_wl_world"
                },
                {
                    "type": "input_string",
                    "text": "WL Door ID",
                    "default": "12345",
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
                    "default": true,
                    "alias": "pick_plat_toggle"
                },
                {
                    "type": "input_string",
                    "text": "Plat World Name",
                    "default": "PLATSAVEHAM",
                    "icon": "Edit",
                    "alias": "pick_plat_world"
                },
                {
                    "type": "input_string",
                    "text": "Plat Door ID",
                    "default": "12345",
                    "icon": "Edit",
                    "alias": "pick_plat_doorid"
                },
                {
                    "type": "input_int",
                    "text": "Plat Item ID",
                    "default": "1324",
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
            WorldList = worlds 
            if index_world > #WorldList then index_world = 1 end
        end
    elseif name == "autodf_worlddoor" then DFWorldDoor = tostring(value)
    elseif name == "autodf_worldsaveseed" then worldsaveseed = tostring(value)
    elseif name == "autodf_worldsaveseed_door" then worldsaveseedDoor = tostring(value)
    elseif name == "autodf_use_random" then UseRandomDF = value
    elseif name == "rand_length" then RandLength = math.floor(tonumber(value) or 5)
    elseif name == "rand_with_number" then RandWithNumber = value
    elseif name == "verify_punch" then VerifyPunch = value
    elseif name == "enable_break" then EnableBreak = value
    elseif name == "enable_place" then EnablePlace = value
    elseif name == "hit_count" then HitCount = math.floor(tonumber(value) or 1)
    elseif name == "autodf_delaybreak" then dbk = math.floor(tonumber(value) or dbk)
    elseif name == "autodf_delayplace" then dpc = math.floor(tonumber(value) or dpc)
    
    elseif name == "webhook_toggle" then WebhookEnabled = value
    elseif name == "webhook_url" then WebhookURL = tostring(value)
    elseif name == "webhook_userid" then WebhookUserID = tostring(value)

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
    elseif name == "drop_world" then DropWorld = tostring(value)
    elseif name == "drop_door" then DropDoor = tostring(value)

    elseif name:find("^item(%d+)_([%w_]+)$") then
        local idxStr, prop = name:match("^item(%d+)_([%w_]+)$")
        local idx = tonumber(idxStr)
        if idx and idx >= 1 and idx <= 8 then
            if prop == "id" then ItemSlots[idx].id = math.floor(tonumber(value) or 0)
            elseif prop == "min" then ItemSlots[idx].min = math.floor(tonumber(value) or 0)
            elseif prop == "x" then ItemSlots[idx].x = math.floor(tonumber(value) or 0)
            elseif prop == "y" then ItemSlots[idx].y = math.floor(tonumber(value) or 0)
            end
        end

    elseif name == "autopick_toggle" then AutoPickEnabled = value
    elseif name == "autofind_toggle" then AutoFind_Enabled = value
    
    elseif name == "pick_door_toggle" then PickDoor_Enabled = value
    elseif name == "pick_door_world" then PickDoor_World = tostring(value)
    elseif name == "pick_door_doorid" then PickDoor_Door = tostring(value)
    elseif name == "pick_door_id" then PickDoor_ID = math.floor(tonumber(value) or 0)
    
    elseif name == "pick_wl_toggle" then PickWL_Enabled = value
    elseif name == "pick_wl_world" then PickWL_World = tostring(value)
    elseif name == "pick_wl_doorid" then PickWL_Door = tostring(value)
    elseif name == "pick_wl_id" then PickWL_ID = math.floor(tonumber(value) or 242)
    
    elseif name == "pick_plat_toggle" then PickPlat_Enabled = value
    elseif name == "pick_plat_world" then StoragePlatWorld = tostring(value)
    elseif name == "pick_plat_doorid" then StoragePlatDoor = tostring(value)
    elseif name == "pick_plat_id" then PlatformID = math.floor(tonumber(value) or 1324)
    
    elseif name == "btn_itemfinder" then openItemFinderDialog()
    
    elseif name == "btn_autodf" then
        autoDF_running = value
        if value == true then
            botStartTime = os.time()
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

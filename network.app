-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- name: Network
-- icon: [NET]
-- vers: [1.0]

-- network.app
-- Lubinty Network - File sharing only

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys
local peripheral = peripheral
local rednet = rednet

-- ========== GLOBALS ==========

local network = {
    running = true,
    myId = nil,
    myName = nil,
    devices = {},
    selectedDevice = 1,
    scrollOffset = 0,
    transferMode = false,
    transferFile = nil,
    transferProgress = 0,
    receivingFile = nil,
    receivingData = nil,
    receivingSize = 0,
    notification = nil,
    notificationTimer = 0
}

local modemAttached = false
local modemSide = nil
local modem = nil

-- ========== COLORS ==========

local colors_net = {
    bg = colors.black,
    fg = colors.white,
    header = colors.cyan,
    selected = colors.blue,
    online = colors.green,
    offline = colors.red,
    progress = colors.lime,
    border = colors.gray,
    title = colors.yellow
}

-- ========== UTILITIES ==========

local function getSize()
    local w, h = term.getSize()
    if w < 1 then w = 51 end
    if h < 1 then h = 19 end
    return w, h
end

local function writeAt(text, x, y, bg, fg)
    if not text then return end
    local w, h = getSize()
    if x >= 1 and x <= w and y >= 1 and y <= h then
        term.setCursorPos(x, y)
        if bg then term.setBackgroundColor(bg) end
        if fg then term.setTextColor(fg) end
        term.write(text)
    end
end

local function centerText(text, y, bg, fg)
    local w = getSize()
    local x = math.max(1, math.floor((w - #text) / 2))
    writeAt(text, x, y, bg, fg)
end

local function drawBox(x1, y1, x2, y2, bg, border, title)
    for y = y1, y2 do
        writeAt(" ", x1, y, border, border)
        writeAt(" ", x2, y, border, border)
    end
    for x = x1, x2 do
        writeAt("-", x, y1, border, border)
        writeAt("-", x, y2, border, border)
    end
    writeAt("+", x1, y1, border, border)
    writeAt("+", x2, y1, border, border)
    writeAt("+", x1, y2, border, border)
    writeAt("+", x2, y2, border, border)
    
    if title then
        writeAt(" " .. title .. " ", x1 + 2, y1, border, colors_net.title)
    end
end

local function drawProgressBar(x, y, width, percent, color)
    local filled = math.floor(width * percent / 100)
    local bar = string.rep("█", filled) .. string.rep("░", width - filled)
    writeAt(bar, x, y, color, color)
    writeAt(string.format(" %d%%", percent), x + width + 1, y, colors_net.bg, colors_net.fg)
end

local function showNotification(msg, isError)
    network.notification = msg
    network.notificationTimer = os.clock() + 3
    if isError then
        network.notificationIsError = true
    else
        network.notificationIsError = false
    end
    network.needsRedraw = true
end

-- ========== MODEM SETUP ==========

local function attachModem()
    -- Check if modem already attached
    local sides = {"left", "right", "back", "front", "top", "bottom"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            modemSide = side
            modem = peripheral.wrap(side)
            modemAttached = true
            return true
        end
    end
    
    -- Try to attach modem to left side
    if peripheral.getType("left") ~= "modem" then
        shell.run("attach left modem")
        sleep(0.5)
    end
    
    if peripheral.getType("left") == "modem" then
        modemSide = "left"
        modem = peripheral.wrap("left")
        modemAttached = true
        return true
    end
    
    return false
end

local function initNetwork()
    -- Check if already initialized this session
    if network.initialized then
        return true
    end
    
    if not attachModem() then
        return false, "No modem found. Please attach a wireless modem."
    end
    
    modem.open(42)  -- Lubinty network channel
    rednet.host("lubinty", network.myName or "Lubinty-Device")
    
    -- Load or generate ID
    if fs.exists("network_id.cfg") then
        local f = fs.open("network_id.cfg", "r")
        if f then
            network.myName = f.readAll()
            f.close()
        end
    end
    
    if not network.myName or network.myName == "" then
        local names = {"Kolik", "Joas", "Lub", "Pixel", "Neon", "Zerg", "Fenix", "Titan", "Nova"}
        local num = math.random(1, 999)
        local name = names[math.random(#names)]
        network.myName = "#" .. num .. " " .. name
        local f = fs.open("network_id.cfg", "w")
        if f then
            f.write(network.myName)
            f.close()
        end
    end
    
    network.myId = os.getComputerID()
    network.initialized = true
    return true
end

-- ========== DEVICE DISCOVERY ==========

local function broadcastPresence()
    rednet.broadcast("lubinty_ping", "lubinty")
end

local function scanDevices()
    network.devices = {}
    network.selectedDevice = 1
    network.scrollOffset = 0
    
    -- Send broadcast
    broadcastPresence()
    
    -- Wait for responses
    local startTime = os.clock()
    local timeout = 3
    
    while os.clock() - startTime < timeout do
        local sender, message, protocol = rednet.receive("lubinty", 0.2)
        if sender and message then
            -- Check if device already in list
            local found = false
            for _, dev in ipairs(network.devices) do
                if dev.id == sender then
                    found = true
                    dev.lastSeen = os.clock()
                    break
                end
            end
            
            if not found and sender ~= network.myId then
                local devName = "Computer " .. sender
                if message ~= "lubinty_ping" and type(message) == "string" and message:match("^#") then
                    devName = message
                end
                table.insert(network.devices, {
                    id = sender,
                    name = devName,
                    lastSeen = os.clock()
                })
            end
        end
    end
    
    return #network.devices
end

-- ========== FILE TRANSFER ==========

local function sendFile(device, filePath)
    if not fs.exists(filePath) then
        return false, "File not found"
    end
    
    if fs.isDir(filePath) then
        return false, "Cannot send directory"
    end
    
    local f = fs.open(filePath, "rb")
    if not f then
        return false, "Cannot open file"
    end
    
    local data = f.readAll()
    f.close()
    
    local fileName = fs.getName(filePath)
    local fileSize = #data
    
    -- Send file info
    rednet.send(device.id, {
        type = "file_info",
        name = fileName,
        size = fileSize
    }, "lubinty")
    
    -- Send file in chunks
    local chunkSize = 4096
    local offset = 1
    local chunks = math.ceil(fileSize / chunkSize)
    
    for i = 1, chunks do
        local chunk = data:sub(offset, offset + chunkSize - 1)
        rednet.send(device.id, {
            type = "file_chunk",
            data = chunk,
            chunkNum = i,
            total = chunks
        }, "lubinty")
        offset = offset + chunkSize
        network.transferProgress = math.floor((i / chunks) * 100)
        network.needsRedraw = true
        sleep(0.05)
    end
    
    -- Send completion signal
    rednet.send(device.id, {
        type = "file_done",
        name = fileName
    }, "lubinty")
    
    return true, fileName
end

local function receiveFile(sender, data)
    if data.type == "file_info" then
        network.receivingFile = {
            name = data.name,
            size = data.size,
            data = "",
            received = 0,
            sender = sender
        }
        showNotification("Receiving: " .. data.name)
        return true
        
    elseif data.type == "file_chunk" then
        if network.receivingFile then
            network.receivingFile.data = network.receivingFile.data .. data.data
            network.receivingFile.received = #network.receivingFile.data
            network.transferProgress = math.floor(network.receivingFile.received / network.receivingFile.size * 100)
            network.needsRedraw = true
        end
        return true
        
    elseif data.type == "file_done" then
        if network.receivingFile and network.receivingFile.name == data.name then
            if not fs.exists("/saved") then
                fs.makeDir("/saved")
            end
            local path = "/saved/" .. network.receivingFile.name
            local f = fs.open(path, "wb")
            if f then
                f.write(network.receivingFile.data)
                f.close()
            end
            showNotification("Received: " .. network.receivingFile.name .. " -> /saved/")
            network.receivingFile = nil
            network.transferProgress = 0
            network.needsRedraw = true
        end
        return true
    end
    
    return false
end

-- ========== LISTENER ==========

local function startListener()
    while network.running do
        local sender, message, protocol = rednet.receive("lubinty", 0.2)
        if sender and message then
            if type(message) == "table" and (message.type == "file_info" or message.type == "file_chunk" or message.type == "file_done") then
                receiveFile(sender, message)
            elseif message == "lubinty_ping" then
                rednet.send(sender, network.myName, "lubinty")
            end
        end
    end
end

-- ========== DRAW UI ==========

local function drawHeader()
    local w = getSize()
    for x = 1, w do
        writeAt(" ", x, 1, colors_net.header, colors_net.fg)
    end
    centerText(" LUBINTY NETWORK - FILE SHARING ", 1, colors_net.header, colors_net.fg)
end

local function drawDeviceList()
    local w, h = getSize()
    local startY = 4
    local maxItems = h - 9
    
    drawBox(2, 3, w - 2, h - 4, colors_net.bg, colors_net.border, " DEVICES (" .. #network.devices .. ") ")
    
    -- Headers
    writeAt("ID", 5, 4, colors_net.header, colors_net.fg)
    writeAt("DEVICE NAME", 15, 4, colors_net.header, colors_net.fg)
    writeAt("STATUS", w - 12, 4, colors_net.header, colors_net.fg)
    
    for i = 1, maxItems do
        local idx = network.scrollOffset + i
        local y = startY + i
        
        if idx <= #network.devices then
            local dev = network.devices[idx]
            local bg = colors_net.bg
            local fg = colors_net.fg
            
            if idx == network.selectedDevice then
                bg = colors_net.selected
                fg = colors_net.bg
            end
            
            local status = "● ONLINE"
            local statusColor = colors_net.online
            if os.clock() - dev.lastSeen > 10 then
                status = "○ OFFLINE"
                statusColor = colors_net.offline
            end
            
            writeAt(string.format("%-8d", dev.id), 5, y, bg, fg)
            local name = dev.name
            if #name > 20 then name = name:sub(1, 17) .. ".." end
            writeAt(name, 15, y, bg, fg)
            writeAt(status, w - #status - 3, y, bg, statusColor)
        end
    end
    
    -- Footer
    writeAt("[R] Refresh   [S] Send File   [ESC] Exit", 4, h - 2, colors_net.bg, colors_net.header)
end

local function drawFileSelector()
    local w, h = getSize()
    local winW = 40
    local winH = 8
    local winX = math.floor((w - winW) / 2)
    local winY = math.floor((h - winH) / 2)
    
    drawBox(winX, winY, winX + winW, winY + winH, colors_net.bg, colors_net.border, " SEND FILE ")
    
    if network.selectedDevice <= #network.devices then
        local dev = network.devices[network.selectedDevice]
        writeAt("To: " .. dev.name, winX + 3, winY + 2, colors_net.bg, colors_net.header)
    end
    
    writeAt("File path:", winX + 3, winY + 3, colors_net.bg, colors_net.fg)
    writeAt("> ", winX + 3, winY + 5, colors_net.bg, colors_net.header)
    
    if network.transferProgress > 0 then
        drawProgressBar(winX + 6, winY + 5, 25, network.transferProgress, colors_net.progress)
    else
        if network.transferFile then
            writeAt(network.transferFile, winX + 6, winY + 5, colors_net.bg, colors_net.fg)
            writeAt("_", winX + 7 + #network.transferFile, winY + 5, colors_net.bg, colors_net.header)
        else
            writeAt("_", winX + 6, winY + 5, colors_net.bg, colors_net.header)
        end
    end
    
    writeAt("Enter path, then ENTER to send, ESC to cancel", winX + 3, winY + 7, colors_net.bg, colors_net.lightGray)
end

local function drawTransferProgress()
    local w, h = getSize()
    if network.transferProgress > 0 and network.transferProgress < 100 then
        local msg = "Sending... " .. network.transferProgress .. "%"
        centerText(msg, h - 1, colors_net.bg, colors_net.progress)
    elseif network.receivingFile then
        local msg = "Receiving... " .. network.transferProgress .. "%"
        centerText(msg, h - 1, colors_net.bg, colors_net.progress)
    end
end

local function drawNotification()
    if network.notification and os.clock() < network.notificationTimer then
        local w, h = getSize()
        local color = network.notificationIsError and colors_net.offline or colors_net.online
        centerText(network.notification, h - 3, colors_net.bg, color)
    elseif network.notification then
        network.notification = nil
    end
end

local function drawNetwork()
    getSize()
    term.clear()
    term.setBackgroundColor(colors_net.bg)
    term.setTextColor(colors_net.fg)
    
    drawHeader()
    drawDeviceList()
    drawTransferProgress()
    drawNotification()
    
    if network.transferMode then
        drawFileSelector()
    end
end

-- ========== FILE SELECTOR LOOP ==========

local function fileSelectorLoop(device)
    network.transferMode = true
    network.transferFile = ""
    network.transferProgress = 0
    local input = ""
    local cursorPos = 1
    local redrawNeeded = true
    
    while network.transferMode do
        if redrawNeeded then
            drawNetwork()
            redrawNeeded = false
        end
        
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                network.transferMode = false
                network.transferProgress = 0
                break
                
            elseif key == keys.enter then
                if input ~= "" then
                    network.transferFile = input
                    network.transferProgress = 1
                    redrawNeeded = true
                    
                    local success, result = sendFile(device, input)
                    if success then
                        showNotification("Sent: " .. result)
                    else
                        showNotification("Error: " .. tostring(result), true)
                    end
                    network.transferProgress = 0
                    network.transferMode = false
                    break
                end
                
            elseif key == keys.backspace then
                input = input:sub(1, -2)
                redrawNeeded = true
                
            else
                local char = keys.getName(key)
                if char and #char == 1 and char:match("[%w%s%p/%-_]") then
                    if #input < 100 then
                        input = input .. char
                        redrawNeeded = true
                    end
                end
            end
        elseif event == "rednet_message" then
            -- Continue receiving in background
            local sender, message = p1, p2
            if sender and message and type(message) == "table" then
                receiveFile(sender, message)
                redrawNeeded = true
            end
        end
    end
    
    network.transferMode = false
    network.transferProgress = 0
end

-- ========== MAIN LOOP ==========

local function mainLoop()
    local redrawNeeded = true
    
    while network.running do
        if redrawNeeded then
            drawNetwork()
            redrawNeeded = false
        end
        
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.escape then
                network.running = false
                break
                
            elseif key == keys.r then
                showNotification("Scanning for devices...")
                redrawNeeded = true
                local count = scanDevices()
                showNotification("Found " .. count .. " device(s)")
                redrawNeeded = true
                
            elseif key == keys.s then
                if #network.devices >= network.selectedDevice then
                    local dev = network.devices[network.selectedDevice]
                    if os.clock() - dev.lastSeen <= 10 then
                        fileSelectorLoop(dev)
                        redrawNeeded = true
                    else
                        showNotification("Device offline, refresh list", true)
                        redrawNeeded = true
                    end
                else
                    showNotification("No device selected", true)
                    redrawNeeded = true
                end
                
            elseif key == keys.up then
                if #network.devices > 0 then
                    network.selectedDevice = math.max(1, network.selectedDevice - 1)
                    if network.selectedDevice <= network.scrollOffset then
                        network.scrollOffset = math.max(0, network.selectedDevice - 1)
                    end
                    redrawNeeded = true
                end
                
            elseif key == keys.down then
                if #network.devices > 0 then
                    network.selectedDevice = math.min(#network.devices, network.selectedDevice + 1)
                    local maxItems = getSize() - 9
                    if network.selectedDevice > network.scrollOffset + maxItems then
                        network.scrollOffset = network.selectedDevice - maxItems
                    end
                    redrawNeeded = true
                end
            end
            
        elseif event == "rednet_message" then
            local sender, message = p1, p2
            if sender and message and type(message) == "table" then
                if receiveFile(sender, message) then
                    redrawNeeded = true
                end
            elseif sender and message == "lubinty_ping" then
                rednet.send(sender, network.myName, "lubinty")
            end
            
        elseif event == "term_resize" then
            redrawNeeded = true
        end
    end
end

-- ========== MAIN ==========

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    term.setCursorBlink(false)
    
    centerText("LUBINTY NETWORK", 3, colors_net.bg, colors_net.header)
    centerText("Initializing...", 5, colors_net.bg, colors_net.fg)
    
    local success, err = initNetwork()
    if not success then
        centerText(err, 7, colors_net.bg, colors_net.offline)
        centerText("Press any key to exit...", 9, colors_net.bg, colors_net.fg)
        os.pullEvent("key")
        term.clear()
        return
    end
    
    centerText("Your ID: " .. network.myName, 7, colors_net.bg, colors_net.online)
    centerText("Scanning for devices...", 9, colors_net.bg, colors_net.fg)
    sleep(1)
    
    scanDevices()
    
    -- Start listener in parallel
    parallel.waitForAny(
        startListener,
        mainLoop
    )
    
    term.clear()
    centerText("Disconnected", 5, colors_net.bg, colors_net.header)
    sleep(1)
    term.clear()
end

-- Run network
local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Network error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

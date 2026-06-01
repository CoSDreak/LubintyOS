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

-- Quit with Q (ESC disabled)
-- name: Image Viewer
-- icon: [IMG]
-- vers: [1.0]

-- imageview.app
-- Image viewer for Lubinty OS (supports BMP, PNT, NFP)

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local currentPath = nil
local imageWidth = 0
local imageHeight = 0
local imageData = nil
local zoom = 1
local zoomMin = 1
local zoomMax = 8

local w, h = 0, 0
local files = {}
local selectedFile = 1
local scrollOffset = 0
local mode = "browse"
local redrawNeeded = true

-- ========== COLORS ==========

local colors_view = {
    bg = colors.black,
    fg = colors.white,
    header = colors.cyan,
    selected = colors.blue,
    file = colors.white,
    status = colors.lightGray,
    border = colors.gray
}

-- ========== UTILITIES ==========

local function getSize()
    local newW, newH = term.getSize()
    if newW < 1 then newW = 51 end
    if newH < 1 then newH = 19 end
    local changed = (w ~= newW or h ~= newH)
    w, h = newW, newH
    return w, h, changed
end

local function writeAt(text, x, y, bg, fg)
    if not text then return end
    if x >= 1 and x <= w and y >= 1 and y <= h then
        term.setCursorPos(x, y)
        if bg then term.setBackgroundColor(bg) end
        if fg then term.setTextColor(fg) end
        term.write(text)
    end
end

local function centerText(text, y, bg, fg)
    local x = math.max(1, math.floor((w - #text) / 2))
    writeAt(text, x, y, bg, fg)
end

-- ========== BMP LOADER (16-COLOR) ==========

local function loadBMP16(path)
    if not fs.exists(path) then return false end
    
    local f = fs.open(path, "rb")
    if not f then return false end
    
    local data = f.readAll()
    f.close()
    
    -- Check BMP signature
    if data:sub(1, 2) ~= "BM" then
        return false
    end
    
    -- Parse BMP header
    local pixelOffset = data:byte(11) + data:byte(12)*256 + data:byte(13)*65536 + data:byte(14)*16777216
    local headerSize = data:byte(15) + data:byte(16)*256 + data:byte(17)*65536 + data:byte(18)*16777216
    
    if headerSize ~= 40 then
        return false
    end
    
    imageWidth = data:byte(19) + data:byte(20)*256 + data:byte(21)*65536 + data:byte(22)*16777216
    imageHeight = data:byte(23) + data:byte(24)*256 + data:byte(25)*65536 + data:byte(26)*16777216
    local bpp = data:byte(29) + data:byte(30)*256
    
    if bpp ~= 4 and bpp ~= 8 and bpp ~= 24 then
        return false
    end
    
    -- Color palette for 4-bit and 8-bit
    local palette = {}
    if bpp == 4 or bpp == 8 then
        local colorCount = (pixelOffset - 54) / 4
        for i = 0, colorCount - 1 do
            local b = data:byte(54 + i*4 + 1) or 0
            local g = data:byte(54 + i*4 + 2) or 0
            local r = data:byte(54 + i*4 + 3) or 0
            
            -- Convert RGB to CC color (16-color mapping)
            local avg = (r + g + b) / 3
            if avg < 32 then
                palette[i] = colors.black
            elseif avg < 96 then
                palette[i] = colors.gray
            elseif avg < 160 then
                palette[i] = colors.lightGray
            else
                palette[i] = colors.white
            end
            
            -- Color approximations
            if r > 200 and g < 100 and b < 100 then palette[i] = colors.red
            elseif r < 100 and g > 200 and b < 100 then palette[i] = colors.green
            elseif r < 100 and g < 100 and b > 200 then palette[i] = colors.blue
            elseif r > 200 and g > 200 and b < 100 then palette[i] = colors.yellow
            elseif r < 100 and g > 200 and b > 200 then palette[i] = colors.cyan
            elseif r > 200 and g < 100 and b > 200 then palette[i] = colors.purple
            elseif r > 200 and g > 100 and b < 100 then palette[i] = colors.orange
            end
        end
    end
    
    -- Read pixel data
    imageData = {}
    local rowSize = math.floor((imageWidth * bpp + 31) / 32) * 4
    
    for y = 1, imageHeight do
        imageData[y] = {}
        local rowOffset = pixelOffset + (imageHeight - y) * rowSize
        
        for x = 1, imageWidth do
            local color
            if bpp == 24 then
                local b = data:byte(rowOffset + (x-1)*3 + 1) or 0
                local g = data:byte(rowOffset + (x-1)*3 + 2) or 0
                local r = data:byte(rowOffset + (x-1)*3 + 3) or 0
                local avg = (r + g + b) / 3
                if avg < 32 then color = colors.black
                elseif avg < 96 then color = colors.gray
                elseif avg < 160 then color = colors.lightGray
                else color = colors.white end
                if r > 200 and g < 100 and b < 100 then color = colors.red
                elseif r < 100 and g > 200 and b < 100 then color = colors.green
                elseif r < 100 and g < 100 and b > 200 then color = colors.blue
                elseif r > 200 and g > 200 and b < 100 then color = colors.yellow
                elseif r < 100 and g > 200 and b > 200 then color = colors.cyan
                elseif r > 200 and g < 100 and b > 200 then color = colors.purple
                end
            elseif bpp == 8 then
                local byte = data:byte(rowOffset + (x-1)) or 0
                color = palette[byte] or colors.white
            elseif bpp == 4 then
                local byte = data:byte(rowOffset + math.floor((x-1)/2)) or 0
                if (x-1) % 2 == 0 then
                    color = palette[math.floor(byte / 16)] or colors.white
                else
                    color = palette[byte % 16] or colors.white
                end
            end
            imageData[y][x] = color or colors.white
        end
    end
    
    return true
end

local function loadPNT(path)
    if not fs.exists(path) then return false end
    
    local f = fs.open(path, "r")
    if not f then return false end
    
    local data = textutils.unserialize(f.readAll())
    f.close()
    
    if data and data.pixels then
        imageWidth = data.width
        imageHeight = data.height
        imageData = data.pixels
        return true
    end
    return false
end

local function loadNFP(path)
    if not fs.exists(path) then return false end
    
    local f = fs.open(path, "r")
    if not f then return false end
    
    local content = f.readAll()
    f.close()
    
    imageData = {}
    imageHeight = 0
    imageWidth = 0
    
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    for num, line in ipairs(lines) do
        imageData[num] = {}
        for x = 1, #line do
            local char = line:sub(x, x)
            local color = colors.white
            if char == " " then color = colors.black
            elseif char == "@" then color = colors.cyan
            elseif char == "#" then color = colors.white
            elseif char == "X" then color = colors.red
            elseif char == "O" then color = colors.orange
            elseif char == "=" then color = colors.green
            elseif char == "-" then color = colors.blue
            elseif char == "+" then color = colors.yellow
            elseif char == "*" then color = colors.purple
            else color = colors.gray end
            imageData[num][x] = color
        end
        if #line > imageWidth then imageWidth = #line end
        imageHeight = num
    end
    
    return imageHeight > 0
end

local function loadImage(path)
    if path:match("%.bmp$") then
        return loadBMP16(path)
    elseif path:match("%.pnt$") then
        return loadPNT(path)
    elseif path:match("%.nfp$") then
        return loadNFP(path)
    end
    return false
end

-- ========== SCAN IMAGES ==========

local function scanImages()
    files = {}
    local paths = {"/saved/", "/"}
    
    for _, dir in ipairs(paths) do
        if fs.exists(dir) then
            local list = fs.list(dir)
            for _, name in ipairs(list) do
                if name:match("%.bmp$") or name:match("%.pnt$") or name:match("%.nfp$") then
                    table.insert(files, {
                        name = name,
                        path = fs.combine(dir, name),
                        type = name:match("%.bmp$") and "BMP" or (name:match("%.pnt$") and "PNT" or "NFP")
                    })
                end
            end
        end
    end
    
    table.sort(files, function(a, b) return a.name < b.name end)
end

-- ========== DRAW IMAGE ==========

local function drawImage()
    if not imageData then return end
    
    local startX = math.floor((w - imageWidth * zoom) / 2)
    local startY = math.floor((h - imageHeight * zoom) / 2) + 2
    
    if startX < 1 then startX = 1 end
    if startY < 2 then startY = 2 end
    
    for y = 1, imageHeight do
        for x = 1, imageWidth do
            local color = imageData[y] and imageData[y][x] or colors.black
            
            for zy = 0, zoom - 1 do
                for zx = 0, zoom - 1 do
                    local screenX = startX + (x - 1) * zoom + zx
                    local screenY = startY + (y - 1) * zoom + zy
                    
                    if screenX >= 1 and screenX <= w and screenY >= 1 and screenY <= h then
                        writeAt(" ", screenX, screenY, color, color)
                    end
                end
            end
        end
    end
end

-- ========== DRAW VIEWER ==========

local function drawViewer()
    term.clear()
    term.setBackgroundColor(colors_view.bg)
    
    -- Header bar
    for x = 1, w do
        writeAt(" ", x, 1, colors_view.header, colors_view.fg)
    end
    
    local title = " IMAGE VIEWER - " .. fs.getName(currentPath) .. " "
    writeAt(title, 2, 1, colors_view.header, colors_view.fg)
    
    local info = string.format(" %dx%d Zoom:%dx ", imageWidth, imageHeight, zoom)
    writeAt(info, w - #info - 1, 1, colors_view.header, colors_view.fg)
    
    -- Image area border
    for x = 1, w do
        writeAt("-", x, 2, colors_view.border, colors_view.border)
        writeAt("-", x, h - 1, colors_view.border, colors_view.border)
    end
    
    -- Draw image
    drawImage()
    
    -- Footer
    local footer = " [+] Zoom In  [-] Zoom Out  [S] Save Copy  [ESC] Back  [Q] Exit "
    centerText(footer, h, colors_view.header, colors_view.fg)
end

-- ========== DRAW BROWSER ==========

local function drawBrowser()
    term.clear()
    term.setBackgroundColor(colors_view.bg)
    term.setTextColor(colors_view.fg)
    
    -- Header
    centerText("═══ LUBINTY IMAGE BROWSER ═══", 2, colors_view.header, colors_view.fg)
    
    -- File list
    local startY = 4
    local maxItems = h - 6
    
    for i = 1, maxItems do
        local idx = scrollOffset + i
        local y = startY + i - 1
        
        if idx <= #files then
            local file = files[idx]
            local bg = colors_view.bg
            local fg = colors_view.file
            
            if idx == selectedFile then
                bg = colors_view.selected
                fg = colors_view.fg
            end
            
            local icon = "BMP"
            if file.type == "BMP" then icon = "📷"
            elseif file.type == "PNT" then icon = "🎨"
            elseif file.type == "NFP" then icon = "🖌️" end
            
            local display = string.format("%s %s", icon, file.name)
            if #display > w - 6 then
                display = display:sub(1, w - 9) .. "..."
            end
            writeAt(display, 4, y, bg, fg)
            writeAt(file.type, w - 6, y, bg, colors_view.status)
        end
    end
    
    -- Footer
    centerText("↑/↓ Navigate  ENTER View  [R] Refresh  [ESC] Exit", h - 1, colors_view.header, colors_view.fg)
    writeAt(" Files: " .. #files, 2, h - 2, colors_view.bg, colors_view.status)
end

-- ========== SAVE COPY ==========

local function saveCopy()
    drawViewer()
    centerText("Save copy as:", h - 2, colors_view.bg, colors_view.fg)
    
    local x = math.floor(w / 2) - 15
    local y = h - 1
    term.setCursorPos(x, y)
    term.setCursorBlink(true)
    local name = read()
    term.setCursorBlink(false)
    
    if name and name ~= "" then
        if not name:match("%.pnt$") then
            name = name .. ".pnt"
        end
        
        if not fs.exists("/saved") then
            fs.makeDir("/saved")
        end
        
        local path = "/saved/" .. name
        local data = {
            width = imageWidth,
            height = imageHeight,
            pixels = imageData
        }
        
        local f = fs.open(path, "w")
        if f then
            f.write(textutils.serialize(data))
            f.close()
            centerText("Saved: " .. name, h - 3, colors_view.bg, colors_view.fg)
            sleep(1)
        end
    end
    
    drawViewer()
end

-- ========== VIEW MODE ==========

local function enterViewMode(path)
    if loadImage(path) then
        currentPath = path
        zoom = 1
        mode = "view"
        redrawNeeded = true
        
        while mode == "view" do
            if redrawNeeded then
                drawViewer()
                redrawNeeded = false
            end
            
            local event, p1 = os.pullEvent()
            
            if event == "key" then
                local key = p1
                
                if key == keys.q then
                    mode = "browse"
                    redrawNeeded = true
                    break
                    
                elseif key == keys.q then
                    mode = "exit"
                    break
                    
                elseif key == keys.equals or key == keys.add then
                    if zoom < zoomMax then
                        zoom = zoom + 1
                        redrawNeeded = true
                    end
                    
                elseif key == keys.minus then
                    if zoom > zoomMin then
                        zoom = zoom - 1
                        redrawNeeded = true
                    end
                    
                elseif key == keys.s then
                    saveCopy()
                    redrawNeeded = true
                end
                
            elseif event == "term_resize" then
                getSize()
                redrawNeeded = true
            end
        end
    else
        mode = "browse"
        redrawNeeded = true
    end
end

-- ========== BROWSE MODE ==========

local function enterBrowseMode()
    mode = "browse"
    scanImages()
    selectedFile = 1
    scrollOffset = 0
    redrawNeeded = true
    
    while mode == "browse" do
        if redrawNeeded then
            drawBrowser()
            redrawNeeded = false
        end
        
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                mode = "exit"
                break
                
            elseif key == keys.up then
                selectedFile = math.max(1, selectedFile - 1)
                if selectedFile <= scrollOffset then
                    scrollOffset = math.max(0, selectedFile - 1)
                end
                redrawNeeded = true
                
            elseif key == keys.down then
                selectedFile = math.min(#files, selectedFile + 1)
                if selectedFile > scrollOffset + (h - 8) then
                    scrollOffset = selectedFile - (h - 8)
                end
                redrawNeeded = true
                
            elseif key == keys.enter then
                if selectedFile <= #files then
                    redrawNeeded = true
                    local file = files[selectedFile]
                    enterViewMode(file.path)
                    redrawNeeded = true
                end
                
            elseif key == keys.r then
                scanImages()
                selectedFile = 1
                scrollOffset = 0
                redrawNeeded = true
            end
            
        elseif event == "term_resize" then
            getSize()
            redrawNeeded = true
        end
    end
end

-- ========== MAIN ==========

local function main(imagePath)
    getSize()
    
    if imagePath and imagePath ~= "" then
        enterViewMode(imagePath)
        if mode == "exit" then
            term.clear()
            return
        end
    end
    
    if mode ~= "exit" then
        enterBrowseMode()
    end
    
    term.clear()
    term.setCursorPos(1, 1)
end

-- Run image viewer
local args = { ... }
local imagePath = args[1]
local ok, err = pcall(main, imagePath)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("ImageView error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

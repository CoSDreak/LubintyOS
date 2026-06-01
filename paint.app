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

-- Quit with Q (ESC disabled)
-- name: Paint
-- icon: [ART]
-- vers: [1.0]

-- paint.app
-- Paint program for Lubinty OS with BMP export

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local canvas = {}
local canvasWidth = 80
local canvasHeight = 50
local currentColor = colors.black
local brushSize = 1
local tool = "brush"
local startX, startY = nil, nil
local drawing = false

local w, h = 0, 0
local offsetX = 16
local offsetY = 4

-- Color names for display
local colorNames = {
    [colors.black] = "BLACK",
    [colors.white] = "WHITE", 
    [colors.red] = "RED",
    [colors.green] = "GREEN",
    [colors.blue] = "BLUE",
    [colors.cyan] = "CYAN",
    [colors.yellow] = "YELLOW",
    [colors.orange] = "ORANGE",
    [colors.purple] = "PURPLE",
    [colors.pink] = "PINK",
    [colors.brown] = "BROWN",
    [colors.lime] = "LIME",
    [colors.gray] = "GRAY",
    [colors.lightGray] = "LIGHT GRAY"
}

local colorList = {
    colors.black, colors.white, colors.red, colors.green, colors.blue,
    colors.cyan, colors.yellow, colors.orange, colors.purple, colors.pink,
    colors.brown, colors.lime, colors.gray, colors.lightGray
}

local tools = {"BRUSH", "LINE", "RECT", "FILL", "PICK", "CLS", "ERASER"}

-- ========== COLORS ==========

local colors_paint = {
    bg = colors.gray,
    fg = colors.black,
    canvasBg = colors.white,
    toolbarBg = colors.lightGray,
    selected = colors.cyan
}

-- ========== UTILITIES ==========

local function getSize()
    w, h = term.getSize()
    if w < 1 then w = 51 end
    if h < 1 then h = 19 end
    return w, h
end

local function writeAt(text, x, y, bg, fg)
    if not text then return end
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.write(text)
end

local function centerText(text, y, bg, fg)
    local width = getSize()
    local x = math.max(1, math.floor((width - #text) / 2))
    writeAt(text, x, y, bg, fg)
end

-- ========== CANVAS ==========

local function initCanvas()
    canvas = {}
    for y = 1, canvasHeight do
        canvas[y] = {}
        for x = 1, canvasWidth do
            canvas[y][x] = colors_paint.canvasBg
        end
    end
end

local function clearCanvas()
    for y = 1, canvasHeight do
        for x = 1, canvasWidth do
            canvas[y][x] = colors_paint.canvasBg
        end
    end
end

local function drawCanvas()
    for y = 1, canvasHeight do
        for x = 1, canvasWidth do
            local screenX = offsetX + (x - 1) * 2
            local screenY = offsetY + y - 1
            if screenX <= w and screenY <= h then
                local color = canvas[y][x] or colors_paint.canvasBg
                writeAt("  ", screenX, screenY, color, color)
            end
        end
    end
end

-- ========== DRAWING TOOLS ==========

local function putPixel(x, y, color)
    if x >= 1 and x <= canvasWidth and y >= 1 and y <= canvasHeight then
        canvas[y][x] = color
        local screenX = offsetX + (x - 1) * 2
        local screenY = offsetY + y - 1
        if screenX <= w and screenY <= h then
            writeAt("  ", screenX, screenY, color, color)
        end
    end
end

local function drawBrush(x, y, color)
    for dx = -brushSize + 1, brushSize - 1 do
        for dy = -brushSize + 1, brushSize - 1 do
            if dx*dx + dy*dy <= brushSize*brushSize then
                putPixel(x + dx, y + dy, color)
            end
        end
    end
end

local function drawLine(x1, y1, x2, y2, color)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    
    while true do
        putPixel(x1, y1, color)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

local function drawRect(x1, y1, x2, y2, color)
    drawLine(x1, y1, x2, y1, color)
    drawLine(x2, y1, x2, y2, color)
    drawLine(x2, y2, x1, y2, color)
    drawLine(x1, y2, x1, y1, color)
end

local function floodFill(x, y, targetColor, newColor)
    if targetColor == newColor then return end
    if x < 1 or x > canvasWidth or y < 1 or y > canvasHeight then return end
    if canvas[y][x] ~= targetColor then return end
    
    putPixel(x, y, newColor)
    
    floodFill(x + 1, y, targetColor, newColor)
    floodFill(x - 1, y, targetColor, newColor)
    floodFill(x, y + 1, targetColor, newColor)
    floodFill(x, y - 1, targetColor, newColor)
end

local function pickColor(x, y)
    if x >= 1 and x <= canvasWidth and y >= 1 and y <= canvasHeight then
        currentColor = canvas[y][x]
    end
end

-- ========== BMP SAVE (FIXED) ==========

local function saveBMP()
    if not fs.exists("/saved") then
        fs.makeDir("/saved")
    end
    
    centerText("Enter file name:", h - 2, colors_paint.bg, colors_paint.fg)
    local x = math.floor(w / 2) - 15
    local y = h - 1
    term.setCursorPos(x, y)
    term.setCursorBlink(true)
    local name = read()
    term.setCursorBlink(false)
    
    if not name or name == "" then
        return
    end
    
    if not name:match("%.bmp$") then
        name = name .. ".bmp"
    end
    
    local width = canvasWidth
    local height = canvasHeight
    local rowSize = math.floor((width * 3 + 3) / 4) * 4
    local imageSize = rowSize * height
    local fileSize = 54 + imageSize
    
    -- Build BMP file
    local bmpData = {}
    
    -- BITMAPFILEHEADER (14 bytes)
    table.insert(bmpData, string.char(0x42, 0x4D))  -- "BM"
    -- File size
    table.insert(bmpData, string.char(
        bit32.band(fileSize, 0xFF),
        bit32.band(bit32.rshift(fileSize, 8), 0xFF),
        bit32.band(bit32.rshift(fileSize, 16), 0xFF),
        bit32.band(bit32.rshift(fileSize, 24), 0xFF)
    ))
    -- Reserved
    table.insert(bmpData, string.char(0x00, 0x00, 0x00, 0x00))
    -- Pixel data offset
    table.insert(bmpData, string.char(0x36, 0x00, 0x00, 0x00))  -- 54
    
    -- BITMAPINFOHEADER (40 bytes)
    table.insert(bmpData, string.char(0x28, 0x00, 0x00, 0x00))  -- header size
    -- Width
    table.insert(bmpData, string.char(
        bit32.band(width, 0xFF),
        bit32.band(bit32.rshift(width, 8), 0xFF),
        0x00, 0x00
    ))
    -- Height (POSITIVE = bottom-up)
    table.insert(bmpData, string.char(
        bit32.band(height, 0xFF),
        bit32.band(bit32.rshift(height, 8), 0xFF),
        0x00, 0x00
    ))
    -- Planes
    table.insert(bmpData, string.char(0x01, 0x00))
    -- Bits per pixel
    table.insert(bmpData, string.char(0x18, 0x00))  -- 24-bit
    -- Compression
    table.insert(bmpData, string.char(0x00, 0x00, 0x00, 0x00))
    -- Image size
    table.insert(bmpData, string.char(
        bit32.band(imageSize, 0xFF),
        bit32.band(bit32.rshift(imageSize, 8), 0xFF),
        bit32.band(bit32.rshift(imageSize, 16), 0xFF),
        bit32.band(bit32.rshift(imageSize, 24), 0xFF)
    ))
    -- X pixels per meter
    table.insert(bmpData, string.char(0x13, 0x0B, 0x00, 0x00))
    -- Y pixels per meter
    table.insert(bmpData, string.char(0x13, 0x0B, 0x00, 0x00))
    -- Colors used
    table.insert(bmpData, string.char(0x00, 0x00, 0x00, 0x00))
    -- Important colors
    table.insert(bmpData, string.char(0x00, 0x00, 0x00, 0x00))
    
    -- Pixel data (BGR format, BOTTOM-UP = row 1 is BOTTOM of image)
    -- So we write from LAST row to FIRST row
    for y = height, 1, -1 do
        local row = {}
        for x = 1, width do
            local color = canvas[y][x] or colors_paint.canvasBg
            local r, g, b
            
            if color == colors.black then r, g, b = 0, 0, 0
            elseif color == colors.white then r, g, b = 255, 255, 255
            elseif color == colors.red then r, g, b = 255, 0, 0
            elseif color == colors.green then r, g, b = 0, 255, 0
            elseif color == colors.blue then r, g, b = 0, 0, 255
            elseif color == colors.cyan then r, g, b = 0, 255, 255
            elseif color == colors.yellow then r, g, b = 255, 255, 0
            elseif color == colors.orange then r, g, b = 255, 165, 0
            elseif color == colors.purple then r, g, b = 128, 0, 128
            elseif color == colors.pink then r, g, b = 255, 192, 203
            elseif color == colors.brown then r, g, b = 165, 42, 42
            elseif color == colors.lime then r, g, b = 0, 255, 0
            elseif color == colors.gray then r, g, b = 128, 128, 128
            elseif color == colors.lightGray then r, g, b = 192, 192, 192
            else r, g, b = 255, 255, 255
            end
            
            table.insert(row, string.char(b, g, r))
        end
        
        -- Pad row to multiple of 4 bytes
        while #row % 4 ~= 0 do
            table.insert(row, string.char(0))
        end
        
        table.insert(bmpData, table.concat(row))
    end
    
    local fullBMP = table.concat(bmpData)
    local path = "/saved/" .. name
    
    local f = fs.open(path, "wb")
    if f then
        f.write(fullBMP)
        f.close()
        centerText("Saved as " .. name, h - 3, colors_paint.bg, colors_paint.fg)
        sleep(1)
    else
        centerText("Save failed!", h - 3, colors_paint.bg, colors_paint.fg)
        sleep(1)
    end
end

-- ========== DRAW UI ==========

local function drawToolbar()
    getSize()
    local toolbarHeight = 22
    local toolbarWidth = 15
    
    -- Toolbar background
    for y = 1, toolbarHeight do
        for x = 1, toolbarWidth do
            writeAt("  ", x, y, colors_paint.toolbarBg, colors_paint.toolbarFg)
        end
    end
    
    -- Border
    for y = 1, toolbarHeight do
        writeAt("│", toolbarWidth, y, colors_paint.toolbarBg, colors_paint.toolbarFg)
    end
    writeAt("┌" .. string.rep("─", toolbarWidth - 1) .. "┐", 1, 1, colors_paint.toolbarBg, colors_paint.toolbarFg)
    writeAt("└" .. string.rep("─", toolbarWidth - 1) .. "┘", 1, toolbarHeight, colors_paint.toolbarBg, colors_paint.toolbarFg)
    
    -- Title
    writeAt("PAINT", 2, 1, colors_paint.selected, colors_paint.toolbarFg)
    
    -- Tools
    writeAt("TOOLS", 2, 3, colors_paint.toolbarBg, colors_paint.toolbarFg)
    for i, toolName in ipairs(tools) do
        local y = 4 + i
        local bg = colors_paint.toolbarBg
        if tool == string.lower(toolName) then
            bg = colors_paint.selected
        end
        writeAt(" " .. i .. "." .. toolName, 2, y, bg, colors_paint.toolbarFg)
    end
    
    -- Brush size
    writeAt("SIZE", 2, 13, colors_paint.toolbarBg, colors_paint.toolbarFg)
    local sizeBar = "["
    for i = 1, 5 do
        if i <= brushSize then
            sizeBar = sizeBar .. "#"
        else
            sizeBar = sizeBar .. "-"
        end
    end
    sizeBar = sizeBar .. "]"
    writeAt(" " .. sizeBar, 2, 14, colors_paint.toolbarBg, colors_paint.toolbarFg)
    writeAt(" +/-", 2, 15, colors_paint.toolbarBg, colors_paint.toolbarFg)
    
    -- Colors title
    writeAt("COLORS", 2, 17, colors_paint.toolbarBg, colors_paint.toolbarFg)
end

local function drawColorPalette()
    for i, color in ipairs(colorList) do
        local row = math.floor((i - 1) / 2)
        local col = (i - 1) % 2
        local x = 2 + col * 7
        local y = 18 + row
        
        local colorName = colorNames[color] or "????"
        local shortName = colorName:sub(1, 5)
        
        if currentColor == color then
            writeAt("[" .. shortName .. "]", x, y, colors_paint.selected, colors_paint.toolbarFg)
        else
            writeAt(" " .. shortName .. " ", x, y, color, colors_paint.toolbarFg)
        end
    end
end

local function drawCanvasArea()
    getSize()
    local canvasBorderY = offsetY - 1
    local canvasBorderX = offsetX - 2
    local canvasEndX = offsetX + canvasWidth * 2
    local canvasEndY = offsetY + canvasHeight
    
    -- Canvas border
    for y = canvasBorderY, canvasEndY do
        writeAt(" ", canvasBorderX, y, colors_paint.canvasBg, colors_paint.canvasBg)
        writeAt(" ", canvasEndX, y, colors_paint.canvasBg, colors_paint.canvasBg)
    end
    for x = canvasBorderX, canvasEndX do
        writeAt(" ", x, canvasBorderY, colors_paint.canvasBg, colors_paint.canvasBg)
        writeAt(" ", x, canvasEndY, colors_paint.canvasBg, colors_paint.canvasBg)
    end
end

local function drawStatus()
    local toolName = string.upper(tool)
    local colorName = colorNames[currentColor] or "UNKNOWN"
    local statusText = string.format(" TOOL: %s  COLOR: %s  SIZE: %d  [S]ave BMP  [C]lear ", toolName, colorName, brushSize)
    writeAt(statusText, offsetX, h, colors_paint.toolbarBg, colors_paint.toolbarFg)
end

local function redraw()
    getSize()
    term.setBackgroundColor(colors_paint.bg)
    term.setCursorPos(1, 1)
    term.clear()
    
    drawToolbar()
    drawColorPalette()
    drawCanvasArea()
    drawCanvas()
    drawStatus()
end

-- ========== MAIN ==========

local function main()
    getSize()
    
    -- Init canvas
    initCanvas()
    clearCanvas()
    
    redraw()
    
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then break
            
            -- Tools by number keys 1-7
            elseif key == keys.one then
                tool = string.lower(tools[1])
                if tool == "cls" then clearCanvas() end
                redraw()
            elseif key == keys.two then
                tool = string.lower(tools[2])
                redraw()
            elseif key == keys.three then
                tool = string.lower(tools[3])
                redraw()
            elseif key == keys.four then
                tool = string.lower(tools[4])
                redraw()
            elseif key == keys.five then
                tool = string.lower(tools[5])
                redraw()
            elseif key == keys.six then
                tool = string.lower(tools[6])
                if tool == "cls" then clearCanvas() end
                redraw()
            elseif key == keys.seven then
                tool = string.lower(tools[7])
                redraw()
            
            -- Brush size
            elseif key == keys.equals or key == keys.add then
                brushSize = math.min(5, brushSize + 1)
                redraw()
            elseif key == keys.minus then
                brushSize = math.max(1, brushSize - 1)
                redraw()
            
            -- Save and Clear
            elseif key == keys.s then
                saveBMP()
                redraw()
            elseif key == keys.c then
                clearCanvas()
                redraw()
            end
            
        elseif event == "mouse_click" or event == "mouse_drag" then
            local button, x, y = p1, p2, p3
            
            -- Toolbar clicks
            if x <= 15 then
                if y >= 4 and y <= 11 then
                    local toolIdx = y - 3
                    if toolIdx >= 1 and toolIdx <= #tools then
                        tool = string.lower(tools[toolIdx])
                        if tool == "cls" then
                            clearCanvas()
                        end
                        redraw()
                    end
                elseif y >= 18 and y <= 24 then
                    local row = y - 18
                    local col = math.floor((x - 2) / 7)
                    local idx = row * 2 + col + 1
                    if idx >= 1 and idx <= #colorList then
                        currentColor = colorList[idx]
                        redraw()
                    end
                end
                drawing = false
                startX, startY = nil, nil
                
            -- Canvas area
            elseif x >= offsetX and x <= offsetX + canvasWidth * 2 - 1 and
                   y >= offsetY and y <= offsetY + canvasHeight - 1 then
                
                local canvasX = math.floor((x - offsetX) / 2) + 1
                local canvasY = y - offsetY + 1
                
                if canvasX >= 1 and canvasX <= canvasWidth and canvasY >= 1 and canvasY <= canvasHeight then
                    
                    if tool == "brush" then
                        drawBrush(canvasX, canvasY, currentColor)
                        
                    elseif tool == "eraser" then
                        drawBrush(canvasX, canvasY, colors_paint.canvasBg)
                        
                    elseif tool == "line" then
                        if not drawing or not startX then
                            startX = canvasX
                            startY = canvasY
                            drawing = true
                        else
                            drawLine(startX, startY, canvasX, canvasY, currentColor)
                            drawing = false
                            startX = nil
                            startY = nil
                        end
                        
                    elseif tool == "rect" then
                        if not drawing or not startX then
                            startX = canvasX
                            startY = canvasY
                            drawing = true
                        else
                            drawRect(startX, startY, canvasX, canvasY, currentColor)
                            drawing = false
                            startX = nil
                            startY = nil
                        end
                        
                    elseif tool == "fill" then
                        floodFill(canvasX, canvasY, canvas[canvasY][canvasX], currentColor)
                        redraw()
                        
                    elseif tool == "pick" then
                        pickColor(canvasX, canvasY)
                        redraw()
                    end
                end
            end
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
end

-- Run paint
local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Paint error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- name: NotePad
-- icon: [TXT]
-- vers: [1.0]

-- notepad.app
-- Simple text editor for Lubinty OS

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local text = ""
local fileName = nil
local cursorX = 1
local cursorY = 1
local scrollX = 0
local scrollY = 0
local modified = false
local insertMode = true

local w, h = 0, 0
local lines = {""}

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

-- ========== TEXT MANAGEMENT ==========

local function rebuildLines()
    lines = {}
    local currentLine = ""
    
    for i = 1, #text do
        local char = text:sub(i, i)
        if char == "\n" then
            table.insert(lines, currentLine)
            currentLine = ""
        else
            currentLine = currentLine .. char
        end
    end
    table.insert(lines, currentLine)
    
    if #lines == 0 then
        lines = {""}
    end
end

local function updateText()
    text = table.concat(lines, "\n")
    modified = true
end

local function insertChar(char)
    local line = lines[cursorY]
    if cursorX > #line then
        line = line .. char
    else
        line = line:sub(1, cursorX - 1) .. char .. line:sub(cursorX)
    end
    lines[cursorY] = line
    cursorX = cursorX + 1
    updateText()
end

local function deleteChar()
    local line = lines[cursorY]
    
    if cursorX > 1 then
        line = line:sub(1, cursorX - 2) .. line:sub(cursorX)
        lines[cursorY] = line
        cursorX = cursorX - 1
        updateText()
    elseif cursorY > 1 then
        local prevLine = lines[cursorY - 1]
        cursorX = #prevLine + 1
        lines[cursorY - 1] = prevLine .. line
        table.remove(lines, cursorY)
        cursorY = cursorY - 1
        updateText()
    end
end

local function newline()
    local line = lines[cursorY]
    local newLine = line:sub(cursorX)
    lines[cursorY] = line:sub(1, cursorX - 1)
    table.insert(lines, cursorY + 1, newLine)
    cursorY = cursorY + 1
    cursorX = 1
    updateText()
end

-- ========== FILE OPERATIONS ==========

local function loadFile(path)
    if fs.exists(path) and not fs.isDir(path) then
        local f = fs.open(path, "r")
        if f then
            text = f.readAll()
            f.close()
            rebuildLines()
            fileName = path
            modified = false
            
            if text:sub(-1) == "\n" then
                text = text:sub(1, -2)
                rebuildLines()
            end
            
            return true
        end
    end
    return false
end

local function saveFile(path)
    local f = fs.open(path, "w")
    if f then
        f.write(text)
        f.close()
        fileName = path
        modified = false
        return true
    end
    return false
end

-- ========== DRAW UI ==========

local function drawTitleBar()
    local title = " NotePad "
    if fileName then
        title = " " .. fs.getName(fileName) .. " "
    end
    
    writeAt(string.rep("=", w), 1, 1, colors.blue, colors.white)
    writeAt(title, 2, 1, colors.blue, colors.yellow)
    
    local status = ""
    if modified then
        status = status .. "[MODIFIED] "
    end
    status = status .. (insertMode and "INSERT" or "OVERWRITE")
    writeAt(status, w - #status - 1, 1, colors.blue, colors.white)
end

local function drawText()
    local maxLines = h - 3
    
    for i = 1, maxLines do
        local lineY = i + 1
        local lineIdx = scrollY + i
        
        if lineIdx <= #lines then
            local line = lines[lineIdx]
            local displayLine = line:sub(scrollX + 1, scrollX + w - 2)
            writeAt(displayLine, 2, lineY, colors.black, colors.white)
            writeAt(string.rep(" ", w - #displayLine - 2), #displayLine + 2, lineY, colors.black, colors.white)
        else
            writeAt(string.rep(" ", w - 2), 2, lineY, colors.black, colors.white)
        end
    end
end

local function drawCursor()
    local screenX = cursorX - scrollX
    local screenY = cursorY - scrollY + 1
    
    if screenX >= 1 and screenX <= w - 2 and screenY >= 2 and screenY <= h - 1 then
        term.setCursorPos(screenX + 1, screenY)
        term.setCursorBlink(true)
    else
        term.setCursorBlink(false)
    end
end

local function drawStatusBar()
    local lineInfo = "Ln " .. cursorY .. ", Col " .. cursorX
    writeAt(lineInfo, 2, h, colors.lightGray, colors.black)
    
    local fileInfo = ""
    if fileName then
        fileInfo = fs.getName(fileName)
    else
        fileInfo = "Untitled"
    end
    writeAt(fileInfo, w - #fileInfo - 1, h, colors.lightGray, colors.black)
end

local function drawFooter()
    writeAt(string.rep("=", w), h - 1, h - 1, colors.lightGray, colors.black)
    writeAt(" Ctrl+S Save   Ctrl+O Open   Ctrl+N New   Q Exit", 2, h - 1, colors.lightGray, colors.black)
end

local function redraw()
    getSize()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    
    for y = 2, h - 2 do
        writeAt(string.rep(" ", w - 2), 2, y, colors.black, colors.white)
    end
    
    drawTitleBar()
    drawText()
    drawStatusBar()
    drawFooter()
    drawCursor()
end

-- ========== SCROLLING ==========

local function updateScroll()
    local maxLines = h - 3
    
    if cursorY < scrollY + 1 then
        scrollY = cursorY - 1
    elseif cursorY > scrollY + maxLines then
        scrollY = cursorY - maxLines
    end
    
    if scrollY < 0 then scrollY = 0 end
    
    local line = lines[cursorY]
    local lineLen = #line
    
    if cursorX < scrollX + 1 then
        scrollX = cursorX - 1
    elseif cursorX > scrollX + w - 3 then
        scrollX = cursorX - (w - 3)
    end
    
    if scrollX < 0 then scrollX = 0 end
    if scrollX > lineLen then scrollX = lineLen end
end

-- ========== COMMANDS ==========

local function newFile()
    text = ""
    lines = {""}
    fileName = nil
    cursorX = 1
    cursorY = 1
    scrollX = 0
    scrollY = 0
    modified = false
    redraw()
end

local function openFile()
    local w_save, h_save = getSize()
    
    for y = math.floor(h_save / 2) - 2, math.floor(h_save / 2) + 2 do
        writeAt(string.rep(" ", 40), math.floor(w_save / 2) - 20, y, colors.gray, colors.black)
    end
    
    centerText(" OPEN FILE ", math.floor(h_save / 2) - 1, colors.blue, colors.yellow)
    centerText("Enter file path:", math.floor(h_save / 2), colors.gray, colors.white)
    centerText("> ", math.floor(h_save / 2) + 1, colors.gray, colors.white)
    
    term.setCursorPos(math.floor(w_save / 2) - 18, math.floor(h_save / 2) + 1)
    term.setCursorBlink(true)
    local path = read()
    term.setCursorBlink(false)
    
    if path and path ~= "" then
        if loadFile(path) then
            centerText("Loaded: " .. fs.getName(path), math.floor(h_save / 2) + 3, colors.black, colors.green)
        else
            centerText("File not found!", math.floor(h_save / 2) + 3, colors.black, colors.red)
        end
        sleep(1)
    end
    
    redraw()
end

local function saveFileDialog()
    local w_save, h_save = getSize()
    
    if fileName then
        saveFile(fileName)
        centerText("Saved: " .. fs.getName(fileName), math.floor(h_save / 2), colors.black, colors.green)
        sleep(1)
        redraw()
        return
    end
    
    for y = math.floor(h_save / 2) - 2, math.floor(h_save / 2) + 2 do
        writeAt(string.rep(" ", 40), math.floor(w_save / 2) - 20, y, colors.gray, colors.black)
    end
    
    centerText(" SAVE FILE ", math.floor(h_save / 2) - 1, colors.blue, colors.yellow)
    centerText("Enter file name:", math.floor(h_save / 2), colors.gray, colors.white)
    centerText("> ", math.floor(h_save / 2) + 1, colors.gray, colors.white)
    
    term.setCursorPos(math.floor(w_save / 2) - 18, math.floor(h_save / 2) + 1)
    term.setCursorBlink(true)
    local name = read()
    term.setCursorBlink(false)
    
    if name and name ~= "" then
        if not name:match("%.txt$") then
            name = name .. ".txt"
        end
        if not fs.exists("/saved") then
            fs.makeDir("/saved")
        end
        if saveFile("/saved/" .. name) then
            centerText("Saved: " .. name, math.floor(h_save / 2) + 3, colors.black, colors.green)
        else
            centerText("Save failed!", math.floor(h_save / 2) + 3, colors.black, colors.red)
        end
        sleep(1)
    end
    
    redraw()
end

-- ========== MAIN ==========

local function main(filePath)
    getSize()
    term.clear()
    term.setCursorBlink(true)
    
    if filePath and filePath ~= "" then
        loadFile(filePath)
    else
        lines = {""}
    end
    
    redraw()
    
    while true do
        updateScroll()
        redraw()
        
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                if modified then
                    local w_save, h_save = getSize()
                    centerText("Save changes?", math.floor(h_save / 2), colors.black, colors.yellow)
                    centerText("Y - Yes   N - No   Q - Cancel", math.floor(h_save / 2) + 1, colors.black, colors.white)
                    
                    local ev, k = os.pullEvent("key")
                    if k == keys.y then
                        saveFileDialog()
                        break
                    elseif k == keys.n then
                        break
                    end
                else
                    break
                end
                
            elseif key == keys.up then
                if cursorY > 1 then
                    cursorY = cursorY - 1
                    local lineLen = #lines[cursorY]
                    if cursorX > lineLen + 1 then
                        cursorX = lineLen + 1
                    end
                end
                
            elseif key == keys.down then
                if cursorY < #lines then
                    cursorY = cursorY + 1
                    local lineLen = #lines[cursorY]
                    if cursorX > lineLen + 1 then
                        cursorX = lineLen + 1
                    end
                end
                
            elseif key == keys.left then
                if cursorX > 1 then
                    cursorX = cursorX - 1
                elseif cursorY > 1 then
                    cursorY = cursorY - 1
                    cursorX = #lines[cursorY] + 1
                end
                
            elseif key == keys.right then
                local lineLen = #lines[cursorY]
                if cursorX <= lineLen then
                    cursorX = cursorX + 1
                elseif cursorY < #lines then
                    cursorY = cursorY + 1
                    cursorX = 1
                end
                
            elseif key == keys.home then
                cursorX = 1
                
            elseif key == keys["end"] then
                cursorX = #lines[cursorY] + 1
                
            elseif key == keys.pageUp then
                cursorY = math.max(1, cursorY - (h - 5))
                
            elseif key == keys.pageDown then
                cursorY = math.min(#lines, cursorY + (h - 5))
                
            elseif key == keys.delete then
                if cursorX <= #lines[cursorY] then
                    local line = lines[cursorY]
                    line = line:sub(1, cursorX - 1) .. line:sub(cursorX + 1)
                    lines[cursorY] = line
                    updateText()
                elseif cursorY < #lines then
                    local line = lines[cursorY]
                    local nextLine = lines[cursorY + 1]
                    lines[cursorY] = line .. nextLine
                    table.remove(lines, cursorY + 1)
                    updateText()
                end
                
            elseif key == keys.backspace then
                deleteChar()
                
            elseif key == keys.enter then
                newline()
                
            elseif key == keys.insert then
                insertMode = not insertMode
                redraw()
                
            elseif key == keys.tab then
                insertChar("    ")
                
            elseif key == 19 then  -- Ctrl+S
                saveFileDialog()
                
            elseif key == 15 then  -- Ctrl+O
                openFile()
                
            elseif key == 14 then  -- Ctrl+N
                if modified then
                    local w_save, h_save = getSize()
                    centerText("Save current file?", math.floor(h_save / 2), colors.black, colors.yellow)
                    local ev, k = os.pullEvent("key")
                    if k == keys.y then
                        saveFileDialog()
                    end
                end
                newFile()
                
            else
                local char = keys.getName(key)
                if char and #char == 1 then
                    if insertMode then
                        insertChar(char)
                    else
                        local line = lines[cursorY]
                        if cursorX <= #line then
                            line = line:sub(1, cursorX - 1) .. char .. line:sub(cursorX + 1)
                        else
                            line = line .. char
                        end
                        lines[cursorY] = line
                        cursorX = cursorX + 1
                        updateText()
                    end
                end
            end
            
        elseif event == "term_resize" then
            redraw()
        end
    end
    
    term.clear()
    term.setCursorBlink(false)
    term.setCursorPos(1, 1)
end

-- Run notepad
local args = { ... }
local filePath = args[1]
local ok, err = pcall(main, filePath)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("NotePad error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

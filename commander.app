-- name: Klinok Commander
-- icon: [KC]
-- vers: [1.0]

-- klinok.app
-- Two-panel file manager for Lubinty OS with UTF-8 support

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys
local textutils = textutils

-- ========== UTF-8 SUPPORT ==========

local utf8 = utf8
local function uLen(str) return utf8.len(str or "") end
local function uSub(str, a, b) return utf8.sub(str or "", a or 1, b or -1) end

-- ========== GLOBALS ==========

local w, h = 0, 0
local activePanel = "left"
local leftPath = "/"
local rightPath = "/saved/"
local leftFiles = {}
local rightFiles = {}
local leftSelected = 1
local rightSelected = 1
local leftScroll = 0
local rightScroll = 0
local cmdLine = ""
local cmdPos = 0
local running = true
local showHelp = false

-- Menu items for F-keys
local menuItems = {"Help", "", "", "Edit", "Copy", "Move", "MkDir", "Del", "", "Exit"}

-- ========== COLORS ==========

local colors_mc = {
    normal = { bg = colors.black, fg = colors.white },
    panel = { bg = colors.blue, fg = colors.white },
    dir = { bg = colors.blue, fg = colors.yellow },
    selected = { bg = colors.orange, fg = colors.black },
    menu = { bg = colors.black, fg = colors.cyan },
    dialog = { bg = colors.gray, fg = colors.black },
    alarm = { bg = colors.red, fg = colors.white }
}

local currentColors = colors_mc.normal

local function setColors(colors)
    currentColors = colors
    term.setBackgroundColor(colors.bg)
    term.setTextColor(colors.fg)
end

local function resetColors()
    setColors(colors_mc.normal)
end

-- ========== UTILITIES ==========

local function getSize()
    local newW, newH = term.getSize()
    if newW < 1 then newW = 51 end
    if newH < 1 then newH = 19 end
    if w ~= newW or h ~= newH then
        w, h = newW, newH
    else
        w, h = newW, newH
    end
    return w, h
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
    local x = math.max(1, math.floor((w - uLen(text)) / 2))
    writeAt(text, x, y, bg, fg)
end

local function drawHLine(y, char, bg, fg)
    for x = 1, w do
        writeAt(char, x, y, bg, fg)
    end
end

-- ========== DIALOG WINDOW ==========

local function dialog(title, lines, inputValue, buttons)
    local maxWidth = uLen(title) + 4
    for _, line in ipairs(lines) do
        maxWidth = math.max(maxWidth, uLen(line) + 4)
    end
    if inputValue then
        maxWidth = math.max(maxWidth, uLen(inputValue) + 8)
    end
    local btnText = ""
    if buttons then
        for i, btn in ipairs(buttons) do
            btnText = btnText .. (i == 1 and "[" .. btn .. "]" or " " .. btn .. " ")
        end
        maxWidth = math.max(maxWidth, uLen(btnText) + 4)
    end
    maxWidth = math.min(maxWidth, w - 4)
    
    local winW = maxWidth + 2
    local winH = #lines + (inputValue and 4 or 3) + (buttons and 2 or 1)
    local winX = math.floor((w - winW) / 2)
    local winY = math.floor((h - winH) / 2)
    
    if winX < 1 then winX = 1 end
    if winY < 1 then winY = 1 end
    
    -- Draw window
    setColors(colors_mc.dialog)
    for y = winY, winY + winH - 1 do
        for x = winX, winX + winW - 1 do
            writeAt(" ", x, y, colors_mc.dialog.bg, colors_mc.dialog.fg)
        end
    end
    
    -- Border
    for y = winY, winY + winH - 1 do
        writeAt("|", winX, y, colors_mc.dialog.bg, colors_mc.dialog.fg)
        writeAt("|", winX + winW - 1, y, colors_mc.dialog.bg, colors_mc.dialog.fg)
    end
    for x = winX, winX + winW - 1 do
        writeAt("-", x, winY, colors_mc.dialog.bg, colors_mc.dialog.fg)
        writeAt("-", x, winY + winH - 1, colors_mc.dialog.bg, colors_mc.dialog.fg)
    end
    writeAt("+", winX, winY, colors_mc.dialog.bg, colors_mc.dialog.fg)
    writeAt("+", winX + winW - 1, winY, colors_mc.dialog.bg, colors_mc.dialog.fg)
    writeAt("+", winX, winY + winH - 1, colors_mc.dialog.bg, colors_mc.dialog.fg)
    writeAt("+", winX + winW - 1, winY + winH - 1, colors_mc.dialog.bg, colors_mc.dialog.fg)
    
    -- Title
    writeAt(" " .. title .. " ", winX + 2, winY, colors_mc.dialog.bg, colors_mc.normal.fg)
    
    -- Lines
    for i, line in ipairs(lines) do
        writeAt(" " .. line, winX + 2, winY + 1 + i, colors_mc.dialog.bg, colors_mc.dialog.fg)
    end
    
    local result = nil
    local input = inputValue or ""
    local cursorPos = uLen(input) + 1
    local selectedButton = 1
    
    while true do
        if inputValue then
            local displayInput = input
            if uLen(displayInput) > winW - 4 then
                displayInput = ".." .. uSub(displayInput, -(winW - 6))
            end
            writeAt(" " .. displayInput, winX + 2, winY + #lines + 2, colors_mc.dialog.bg, colors_mc.selected.fg)
            term.setCursorPos(winX + 2 + math.min(cursorPos - 1, winW - 5), winY + #lines + 2)
            term.setCursorBlink(true)
        end
        
        if buttons then
            local btnDisplay = ""
            for i, btn in ipairs(buttons) do
                if i == selectedButton then
                    btnDisplay = btnDisplay .. "[" .. btn .. "]"
                else
                    btnDisplay = btnDisplay .. " " .. btn .. " "
                end
            end
            writeAt(btnDisplay, winX + math.floor((winW - uLen(btnDisplay)) / 2), winY + winH - 2, colors_mc.dialog.bg, colors_mc.dialog.fg)
        end
        
        local event, p1, p2 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.enter then
                term.setCursorBlink(false)
                if inputValue then
                    return input, buttons[selectedButton]
                else
                    return buttons[selectedButton]
                end
            elseif key == keys.escape then
                term.setCursorBlink(false)
                return nil, "Cancel"
            elseif key == keys.left then
                if inputValue then
                    cursorPos = math.max(1, cursorPos - 1)
                elseif buttons then
                    selectedButton = math.max(1, selectedButton - 1)
                end
            elseif key == keys.right then
                if inputValue then
                    cursorPos = math.min(uLen(input) + 1, cursorPos + 1)
                elseif buttons then
                    selectedButton = math.min(#buttons, selectedButton + 1)
                end
            elseif key == keys.tab and buttons then
                selectedButton = selectedButton % #buttons + 1
            elseif key == keys.backspace and inputValue then
                if cursorPos > 1 then
                    input = uSub(input, 1, cursorPos - 2) .. uSub(input, cursorPos)
                    cursorPos = cursorPos - 1
                end
            elseif inputValue then
                local char = keys.getName(key)
                if char and #char == 1 and char:match("[%w%p%s]") then
                    input = uSub(input, 1, cursorPos - 1) .. char .. uSub(input, cursorPos)
                    cursorPos = cursorPos + 1
                end
            end
        end
    end
end

-- ========== FILE OPERATIONS ==========

local function getFileList(path)
    local files = {}
    if not fs.exists(path) then
        fs.makeDir(path)
    end
    local list = fs.list(path) or {}
    table.sort(list)
    for _, name in ipairs(list) do
        if name ~= "rom" then
            local full = path == "/" and "/" .. name or path .. "/" .. name
            local isDir = fs.isDir(full)
            local size = 0
            if not isDir then size = fs.getSize(full) end
            table.insert(files, {name = name, path = full, isDir = isDir, size = size})
        end
    end
    if path ~= "/" then
        table.insert(files, 1, {name = "..", path = fs.getDir(path), isDir = true, size = 0})
    end
    return files
end

local function formatSize(bytes)
    if bytes >= 1048576 then return string.format("%.1fM", bytes / 1048576)
    elseif bytes >= 1024 then return string.format("%.1fK", bytes / 1024)
    else return bytes .. "B" end
end

local function refreshFiles()
    leftFiles = getFileList(leftPath)
    rightFiles = getFileList(rightPath)
    leftSelected = math.min(leftSelected, #leftFiles)
    if leftSelected < 1 then leftSelected = 1 end
    rightSelected = math.min(rightSelected, #rightFiles)
    if rightSelected < 1 then rightSelected = 1 end
end

-- ========== DRAW ==========

local function drawPanel(x, y, width, height, files, selected, scroll, isActive)
    -- Border
    for i = 1, height do
        writeAt("|", x, y + i - 1, colors_mc.panel.bg, colors_mc.panel.fg)
        writeAt("|", x + width - 1, y + i - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    end
    for i = 1, width do
        writeAt("-", x + i - 1, y - 1, colors_mc.panel.bg, colors_mc.panel.fg)
        writeAt("-", x + i - 1, y + height - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    end
    writeAt("+", x, y - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    writeAt("+", x + width - 1, y - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    writeAt("+", x, y + height - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    writeAt("+", x + width - 1, y + height - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    
    -- Header
    local headerPath = files[1] and files[1].path or "/"
    if uLen(headerPath) > width - 4 then
        headerPath = ".." .. uSub(headerPath, -(width - 6))
    end
    local headerX = x + math.floor((width - uLen(headerPath) - 2) / 2)
    setColors(colors_mc.panel)
    writeAt(" " .. headerPath .. " ", headerX, y - 1, colors_mc.panel.bg, colors_mc.panel.fg)
    
    -- Files
    local maxItems = height
    for i = 1, maxItems do
        local idx = scroll + i
        local lineY = y + i - 1
        local bg = colors_mc.panel.bg
        local fg = colors_mc.panel.fg
        
        if idx <= #files then
            local file = files[idx]
            if idx == selected and isActive then
                bg = colors_mc.selected.bg
                fg = colors_mc.selected.fg
            elseif file.isDir then
                fg = colors_mc.dir.fg
            end
            
            local display = " " .. file.name
            if uLen(display) > width - 12 then
                display = uSub(display, 1, width - 15) .. ".."
            end
            writeAt(display, x + 2, lineY, bg, fg)
            
            if not file.isDir then
                local sizeStr = formatSize(file.size)
                writeAt(sizeStr, x + width - uLen(sizeStr) - 2, lineY, bg, fg)
            else
                writeAt("<DIR>", x + width - 6, lineY, bg, fg)
            end
        else
            writeAt(string.rep(" ", width - 2), x + 1, lineY, bg, fg)
        end
    end
    resetColors()
end

local function drawMenuBar()
    local menuY = h
    for x = 1, w do
        writeAt(" ", x, menuY, colors_mc.menu.bg, colors_mc.menu.fg)
    end
    local totalWidth = 0
    for i = 1, #menuItems do
        if menuItems[i] ~= "" then
            local item = " F" .. i .. menuItems[i] .. " "
            if i == 1 then
                writeAt(item, 2, menuY, colors_mc.menu.bg, colors_mc.menu.fg)
            else
                writeAt(item, totalWidth + 3, menuY, colors_mc.menu.bg, colors_mc.menu.fg)
            end
            totalWidth = totalWidth + uLen(item)
        end
    end
end

local function drawCommandLine()
    local cmdY = h - 1
    for x = 1, w do
        writeAt(" ", x, cmdY, colors_mc.normal.bg, colors_mc.normal.fg)
    end
    local prompt = leftPath .. "> "
    writeAt(prompt, 2, cmdY, colors_mc.normal.bg, colors_mc.normal.fg)
    writeAt(cmdLine, 2 + uLen(prompt), cmdY, colors_mc.normal.bg, colors_mc.normal.fg)
    term.setCursorPos(2 + uLen(prompt) + cmdPos, cmdY)
end

local function drawHelp()
    local lines = {
        "KLINOK COMMANDER HELP",
        "",
        "F1 - This help",
        "F4 - Edit file",
        "F5 - Copy file/dir",
        "F6 - Move file/dir",
        "F7 - Create directory",
        "F8 - Delete file/dir",
        "F10 - Exit",
        "",
        "TAB - Switch panels",
        "ENTER - Open file/dir or execute command",
        "UP/DOWN - Navigate",
        "Ctrl+ENTER - Insert filename into command line",
        "",
        "Press any key to close"
    }
    term.setCursorBlink(false)
    setColors(colors_mc.dialog)
    for y = 1, h do
        for x = 1, w do
            writeAt(" ", x, y, colors_mc.dialog.bg, colors_mc.dialog.fg)
        end
    end
    for i, line in ipairs(lines) do
        local x = math.max(1, math.floor((w - uLen(line)) / 2))
        local color = colors_mc.dialog.fg
        if i == 1 then color = colors_mc.dir.fg end
        writeAt(line, x, 3 + i, colors_mc.dialog.bg, color)
    end
    os.pullEvent("key")
    resetColors()
end

-- ========== COMMANDS ==========

local function executeCommand(cmd)
    if cmd == "" then return end
    local parts = {}
    for part in cmd:gmatch("%S+") do
        table.insert(parts, part)
    end
    local command = table.remove(parts, 1)
    if command == "cd" then
        local newPath = parts[1] or "/"
        if fs.isDir(newPath) then
            if activePanel == "left" then
                leftPath = newPath
                leftSelected = 1
                leftScroll = 0
            else
                rightPath = newPath
                rightSelected = 1
                rightScroll = 0
            end
            refreshFiles()
        end
    elseif command == "ls" or command == "dir" then
        local path = parts[1] or (activePanel == "left" and leftPath or rightPath)
        local files = getFileList(path)
        for _, file in ipairs(files) do
            print(file.name)
        end
        print("Press any key...")
        os.pullEvent("key")
    elseif command == "pwd" then
        print(activePanel == "left" and leftPath or rightPath)
        print("Press any key...")
        os.pullEvent("key")
    elseif command == "clear" or command == "cls" then
        -- handled by redraw
    else
        local fn, err = loadfile("/" .. command .. ".app")
        if fn then
            pcall(fn)
        elseif fs.exists(command) and not fs.isDir(command) then
            local fn, err = loadfile(command)
            if fn then pcall(fn) end
        else
            local fullPath = (activePanel == "left" and leftPath or rightPath) .. "/" .. command
            if fs.exists(fullPath) and not fs.isDir(fullPath) then
                local fn, err = loadfile(fullPath)
                if fn then pcall(fn) end
            end
        end
    end
end

local function copyFile(src, dst)
    if fs.isDir(src) then
        if not fs.exists(dst) then fs.makeDir(dst) end
        local files = fs.list(src)
        for _, file in ipairs(files) do
            copyFile(fs.combine(src, file), fs.combine(dst, file))
        end
    else
        fs.copy(src, dst)
    end
end

local function deleteFile(path)
    if fs.isDir(path) then
        local files = fs.list(path)
        for _, file in ipairs(files) do
            deleteFile(fs.combine(path, file))
        end
        fs.delete(path)
    else
        fs.delete(path)
    end
end

-- ========== PANEL OPERATIONS ==========

local function getCurrentFile()
    if activePanel == "left" then
        return leftFiles[leftSelected]
    else
        return rightFiles[rightSelected]
    end
end

local function getOtherPath()
    return activePanel == "left" and rightPath or leftPath
end

local function copyCurrent()
    local file = getCurrentFile()
    if not file then return end
    local dstPath = getOtherPath()
    local dst = dstPath == "/" and "/" .. file.name or dstPath .. "/" .. file.name
    local result = dialog("Copy", {file.name, "to:"}, dst, {"Ok", "Cancel"})
    if result and result ~= "Cancel" then
        copyFile(file.path, result)
        refreshFiles()
    end
end

local function moveCurrent()
    local file = getCurrentFile()
    if not file then return end
    local dstPath = getOtherPath()
    local dst = dstPath == "/" and "/" .. file.name or dstPath .. "/" .. file.name
    local result = dialog("Move", {file.name, "to:"}, dst, {"Ok", "Cancel"})
    if result and result ~= "Cancel" then
        copyFile(file.path, result)
        deleteFile(file.path)
        refreshFiles()
    end
end

local function deleteCurrent()
    local file = getCurrentFile()
    if not file or file.name == ".." then return end
    local result = dialog("Delete", {file.name, "Confirm delete?"}, nil, {"Yes", "No"})
    if result == "Yes" then
        deleteFile(file.path)
        refreshFiles()
    end
end

local function makeDirectory()
    local result = dialog("New Directory", {"Enter directory name:"}, "", {"Ok", "Cancel"})
    if result and result ~= "Cancel" and result ~= "" then
        local currentPath = activePanel == "left" and leftPath or rightPath
        local newPath = currentPath == "/" and "/" .. result or currentPath .. "/" .. result
        if not fs.exists(newPath) then
            fs.makeDir(newPath)
            refreshFiles()
        end
    end
end

local function editCurrent()
    local file = getCurrentFile()
    if not file or file.isDir then
        dialog("Error", {"Cannot edit directory"}, nil, {"Ok"})
        return
    end
    if fs.exists("notepad.app") then
        local fn, err = loadfile("notepad.app")
        if fn then pcall(fn, file.path) end
    end
end

-- ========== EVENT HANDLING ==========

local function handleKey(key, isCtrl, isAlt, isShift)
    local maxLeft = #leftFiles
    local maxRight = #rightFiles
    local maxItems = h - 4
    
    if showHelp then
        showHelp = false
        return
    end
    
    if key == keys.f1 then
        showHelp = true
        drawHelp()
        return
    end
    
    if key == keys.f4 then
        editCurrent()
        return
    end
    
    if key == keys.f5 then
        copyCurrent()
        return
    end
    
    if key == keys.f6 then
        moveCurrent()
        return
    end
    
    if key == keys.f7 then
        makeDirectory()
        return
    end
    
    if key == keys.f8 then
        deleteCurrent()
        return
    end
    
    if key == keys.f10 or key == keys.q then
        running = false
        return
    end
    
    if key == keys.tab then
        activePanel = (activePanel == "left") and "right" or "left"
        return
    end
    
    if key == keys.up then
        if activePanel == "left" then
            leftSelected = math.max(1, leftSelected - 1)
            if leftSelected <= leftScroll then
                leftScroll = math.max(0, leftSelected - 1)
            end
        else
            rightSelected = math.max(1, rightSelected - 1)
            if rightSelected <= rightScroll then
                rightScroll = math.max(0, rightSelected - 1)
            end
        end
        return
    end
    
    if key == keys.down then
        if activePanel == "left" then
            leftSelected = math.min(maxLeft, leftSelected + 1)
            if leftSelected > leftScroll + maxItems then
                leftScroll = leftSelected - maxItems
            end
        else
            rightSelected = math.min(maxRight, rightSelected + 1)
            if rightSelected > rightScroll + maxItems then
                rightScroll = rightSelected - maxItems
            end
        end
        return
    end
    
    if key == keys.enter then
        if cmdLine ~= "" then
            executeCommand(cmdLine)
            cmdLine = ""
            cmdPos = 0
        else
            local file = getCurrentFile()
            if file then
                if file.isDir then
                    if activePanel == "left" then
                        leftPath = file.path
                        leftSelected = 1
                        leftScroll = 0
                    else
                        rightPath = file.path
                        rightSelected = 1
                        rightScroll = 0
                    end
                    refreshFiles()
                else
                    if file.name:match("%.app$") then
                        local fn, err = loadfile(file.path)
                        if fn then pcall(fn) end
                    elseif file.name:match("%.lua$") then
                        if fs.exists("notepad.app") then
                            local fn, err = loadfile("notepad.app")
                            if fn then pcall(fn, file.path) end
                        end
                    elseif file.name:match("%.txt$") then
                        if fs.exists("notepad.app") then
                            local fn, err = loadfile("notepad.app")
                            if fn then pcall(fn, file.path) end
                        end
                    elseif file.name:match("%.bmp$") then
                        if fs.exists("imageview.app") then
                            local fn, err = loadfile("imageview.app")
                            if fn then pcall(fn, file.path) end
                        end
                    else
                        local fn, err = loadfile(file.path)
                        if fn then pcall(fn) end
                    end
                end
            end
        end
        return
    end
    
    if isCtrl and key == keys.enter then
        local file = getCurrentFile()
        if file then
            cmdLine = file.path
            cmdPos = uLen(cmdLine)
        end
        return
    end
    
    if key == keys.backspace then
        if cmdPos > 0 then
            cmdLine = uSub(cmdLine, 1, cmdPos - 1) .. uSub(cmdLine, cmdPos + 1)
            cmdPos = cmdPos - 1
        end
        return
    end
    
    if key == keys.delete then
        if cmdPos < uLen(cmdLine) then
            cmdLine = uSub(cmdLine, 1, cmdPos) .. uSub(cmdLine, cmdPos + 2)
        end
        return
    end
    
    if key == keys.left then
        if cmdPos > 0 then
            cmdPos = cmdPos - 1
        end
        return
    end
    
    if key == keys.right then
        if cmdPos < uLen(cmdLine) then
            cmdPos = cmdPos + 1
        end
        return
    end
    
    if key == keys.home then
        cmdPos = 0
        return
    end
    
    if key == keys["end"] then
        cmdPos = uLen(cmdLine)
        return
    end
    
    local char = keys.getName(key)
    if char and #char == 1 and char:match("[%w%p%s/%-_]") then
        cmdLine = uSub(cmdLine, 1, cmdPos) .. char .. uSub(cmdLine, cmdPos + 1)
        cmdPos = cmdPos + 1
        return
    end
end

-- ========== DRAW ==========

local function drawPanels()
    getSize()
    setColors(colors_mc.panel)
    term.clear()
    
    local panelWidth = math.floor((w - 3) / 2)
    local panelHeight = h - 4
    
    drawPanel(2, 3, panelWidth, panelHeight, leftFiles, leftSelected, leftScroll, activePanel == "left")
    drawPanel(panelWidth + 4, 3, panelWidth, panelHeight, rightFiles, rightSelected, rightScroll, activePanel == "right")
    
    drawMenuBar()
    drawCommandLine()
    
    resetColors()
end

-- ========== MAIN ==========

local function main()
    getSize()
    refreshFiles()
    
    term.setCursorBlink(true)
    
    while running do
        drawPanels()
        
        local event, p1, p2 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            local isCtrl = false
            local isAlt = false
            local isShift = false
            handleKey(key, isCtrl, isAlt, isShift)
            
        elseif event == "term_resize" then
            getSize()
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    term.setCursorBlink(false)
    resetColors()
    print("Klinok Commander closed.")
    sleep(1)
    term.clear()
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Klinok Commander error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

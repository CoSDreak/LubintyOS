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

-- name: Volkov Commander
-- icon: [VC]

-- commander.app
-- Two-panel file manager for Lubinty OS

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local leftPath = "/"
local rightPath = "/saved/"
local leftFiles = {}
local rightFiles = {}
local leftSelected = 1
local rightSelected = 1
local leftScroll = 0
local rightScroll = 0
local activePane = "left"
local clipboard = nil
local clipPath = nil
local cutMode = false
local showHelp = false
local showConfirm = false
local confirmAction = nil
local confirmTarget = nil

local w, h = 0, 0

-- ========== COLORS ==========

local colors_cmd = {
    bg = colors.black,
    fg = colors.white,
    header = colors.cyan,
    selected = colors.blue,
    dir = colors.yellow,
    file = colors.white,
    exec = colors.green,
    active = colors.cyan,
    status = colors.lightGray,
    help = colors.lime,
    error = colors.red
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
    if x >= 1 and x <= w and y >= 1 and y <= h then
        term.setCursorPos(x, y)
        if bg then term.setBackgroundColor(bg) end
        if fg then term.setTextColor(fg) end
        term.write(text)
    end
end

local function centerText(text, y, bg, fg)
    local width = getSize()
    local x = math.max(1, math.floor((width - #text) / 2))
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
        writeAt(" " .. title .. " ", x1 + 2, y1, border, colors_cmd.header)
    end
end

-- ========== FILE LISTING ==========

local function getFileList(path)
    local files = {}
    
    if not fs.exists(path) then
        fs.makeDir(path)
    end
    
    local list = fs.list(path) or {}
    table.sort(list)
    
    for _, name in ipairs(list) do
        if name ~= "rom" then
            local fullPath = path == "/" and "/" .. name or path .. "/" .. name
            local isDir = fs.isDir(fullPath)
            local size = 0
            local ext = ""
            if not isDir then
                size = fs.getSize(fullPath)
                ext = name:match("%.([^%.]+)$") or ""
            end
            
            local fileType = "file"
            if isDir then
                fileType = "dir"
            elseif ext == "app" then
                fileType = "app"
            elseif ext == "lua" then
                fileType = "lua"
            elseif ext == "txt" then
                fileType = "txt"
            elseif ext == "bmp" then
                fileType = "bmp"
            elseif ext == "cfg" then
                fileType = "cfg"
            end
            
            table.insert(files, {
                name = name,
                path = fullPath,
                isDir = isDir,
                size = size,
                type = fileType,
                ext = ext
            })
        end
    end
    
    -- Add ".." for parent directory (except root)
    if path ~= "/" then
        table.insert(files, 1, {
            name = "..",
            path = fs.getDir(path),
            isDir = true,
            size = 0,
            type = "dir",
            ext = ""
        })
    end
    
    return files
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

local function drawPane(x, y, width, height, files, selected, scroll, isActive)
    local colorBg = isActive and colors_cmd.active or colors_cmd.bg
    
    -- Border
    for i = 1, height do
        writeAt("|", x, y + i - 1, colorBg, colors_cmd.header)
        writeAt("|", x + width - 1, y + i - 1, colorBg, colors_cmd.header)
    end
    for i = 1, width do
        writeAt("-", x + i - 1, y - 1, colorBg, colors_cmd.header)
        writeAt("-", x + i - 1, y + height - 1, colorBg, colors_cmd.header)
    end
    writeAt("+", x, y - 1, colorBg, colors_cmd.header)
    writeAt("+", x + width - 1, y - 1, colorBg, colors_cmd.header)
    writeAt("+", x, y + height - 1, colorBg, colors_cmd.header)
    writeAt("+", x + width - 1, y + height - 1, colorBg, colors_cmd.header)
    
    -- Header
    local header = " " .. fs.getName(files[1] and files[1].path or "/") .. " "
    if #header > width - 2 then
        header = header:sub(1, width - 5) .. ".. "
    end
    writeAt(header, x + 1, y - 1, colors_cmd.header, colors_cmd.fg)
    
    -- Files
    local maxItems = height - 1
    for i = 1, maxItems do
        local idx = scroll + i
        local lineY = y + i - 1
        
        if idx <= #files then
            local file = files[idx]
            local isSelected = (idx == selected)
            
            local bg = colorBg
            local fg = colors_cmd.file
            
            if file.type == "dir" then
                fg = colors_cmd.dir
            elseif file.type == "app" or file.type == "lua" then
                fg = colors_cmd.exec
            elseif file.type == "bmp" then
                fg = colors_cmd.help
            end
            
            if isSelected then
                bg = colors_cmd.selected
                fg = colors_cmd.fg
            end
            
            -- File icon
            local icon = " "
            if file.type == "dir" then icon = "DIR"
            elseif file.type == "app" then icon = "APP"
            elseif file.type == "lua" then icon = "LUA FILE"
            elseif file.type == "txt" then icon = "TEXT"
            elseif file.type == "bmp" then icon = "PIC"
            elseif file.type == "cfg" then icon = "CFG"
            end
            
            -- File name
            local display = icon .. " " .. file.name
            if #display > width - 10 then
                display = display:sub(1, width - 13) .. ".."
            end
            writeAt(display, x + 2, lineY, bg, fg)
            
            -- Size
            if not file.isDir then
                local sizeStr = tostring(file.size)
                if file.size >= 1048576 then
                    sizeStr = string.format("%.1fM", file.size / 1048576)
                elseif file.size >= 1024 then
                    sizeStr = string.format("%.1fK", file.size / 1024)
                end
                writeAt(sizeStr, x + width - #sizeStr - 2, lineY, bg, colors_cmd.status)
            else
                writeAt("<DIR>", x + width - 6, lineY, bg, colors_cmd.status)
            end
        else
            writeAt(string.rep(" ", width - 2), x + 1, lineY, colorBg, colors_cmd.fg)
        end
    end
end

local function drawStatusBar()
    local leftInfo = " " .. leftPath .. " "
    if #leftInfo > 25 then leftInfo = leftInfo:sub(1, 22) .. ".. " end
    writeAt(leftInfo, 2, h, colors_cmd.status, colors_cmd.fg)
    
    local rightInfo = " " .. rightPath .. " "
    if #rightInfo > 25 then rightInfo = rightInfo:sub(1, 22) .. ".. " end
    writeAt(rightInfo, w - #rightInfo - 1, h, colors_cmd.status, colors_cmd.fg)
    
    local totalFiles = #leftFiles + #rightFiles
    writeAt(" Total: " .. totalFiles .. " files ", math.floor(w / 2) - 10, h, colors_cmd.status, colors_cmd.fg)
end

local function drawFooter()
    writeAt(string.rep("=", w), h - 2, h - 2, colors_cmd.header, colors_cmd.fg)
    local footerText = " F1-Help  F3-View  F4-Edit  F5-Copy  F6-Move  F7-MkDir  F8-Delete  Q-Exit "
    centerText(footerText, h - 1, colors_cmd.header, colors_cmd.fg)
end

local function drawCommander()
    getSize()
    term.setBackgroundColor(colors_cmd.bg)
    term.setTextColor(colors_cmd.fg)
    term.clear()
    
    local paneWidth = math.floor((w - 3) / 2)
    local paneHeight = h - 5
    
    drawPane(2, 3, paneWidth, paneHeight, leftFiles, leftSelected, leftScroll, activePane == "left")
    drawPane(paneWidth + 3, 3, paneWidth, paneHeight, rightFiles, rightSelected, rightScroll, activePane == "right")
    
    drawStatusBar()
    drawFooter()
end

-- ========== HELP SCREEN ==========

local function drawHelp()
    local winW = 50
    local winH = 16
    local winX = math.floor((w - winW) / 2)
    local winY = math.floor((h - winH) / 2)
    
    drawBox(winX, winY, winX + winW, winY + winH, colors_cmd.bg, colors_cmd.header, " COMMANDER HELP ")
    
    local helpLines = {
        "F1 - This help screen",
        "F3 - View file content",
        "F4 - Edit file (text/Lua)",
        "F5 - Copy to other panel",
        "F6 - Move to other panel",
        "F7 - Create new directory",
        "F8 - Delete file/directory",
        "ENTER - Open file/directory",
        "TAB - Switch panels",
        "↑/↓ - Navigate",
        "Q - Exit Commander",
        "",
        "File associations:",
        ".bmp → Image Viewer",
        ".lua → Editor",
        ".txt → NotePad",
        ".app → Run application"
    }
    
    for i, line in ipairs(helpLines) do
        local color = colors_cmd.help
        if line:match("File associations") then
            color = colors_cmd.header
        elseif line:match("%.bmp") or line:match("%.lua") or line:match("%.txt") or line:match("%.app") then
            color = colors_cmd.exec
        end
        writeAt(line, winX + 3, winY + 1 + i, colors_cmd.bg, color)
    end
    
    writeAt("Press any key to close", winX + 3, winY + winH - 2, colors_cmd.bg, colors_cmd.status)
end

-- ========== CONFIRM DIALOG ==========

local function drawConfirm()
    local winW = 40
    local winH = 6
    local winX = math.floor((w - winW) / 2)
    local winY = math.floor((h - winH) / 2)
    
    drawBox(winX, winY, winX + winW, winY + winH, colors_cmd.bg, colors_cmd.header, " CONFIRM ")
    
    writeAt("Delete " .. confirmTarget .. "?", winX + 3, winY + 2, colors_cmd.bg, colors_cmd.fg)
    writeAt("[Y] Yes  [N] No", winX + 3, winY + 4, colors_cmd.bg, colors_cmd.header)
end

-- ========== FILE OPERATIONS ==========

local function openFile(file)
    if file.name == ".." then
        if activePane == "left" then
            leftPath = file.path
            leftSelected = 1
            leftScroll = 0
        else
            rightPath = file.path
            rightSelected = 1
            rightScroll = 0
        end
        refreshFiles()
        drawCommander()
        return
    end
    
    if file.isDir then
        if activePane == "left" then
            leftPath = file.path
            leftSelected = 1
            leftScroll = 0
        else
            rightPath = file.path
            rightSelected = 1
            rightScroll = 0
        end
        refreshFiles()
        drawCommander()
        return
    end
    
    -- Open by extension
    local ext = file.ext:lower()
    
    if ext == "app" then
        local fn, err = loadfile(file.path)
        if fn then
            pcall(fn)
        else
            drawCommander()
            centerText("Error: " .. tostring(err), h - 3, colors_cmd.bg, colors_cmd.error)
            sleep(1.5)
        end
    elseif ext == "bmp" then
        if fs.exists("imageview.app") then
            local fn, err = loadfile("imageview.app")
            if fn then
                pcall(fn, file.path)
            end
        end
    elseif ext == "lua" then
        if fs.exists("notepad.app") then
            local fn, err = loadfile("notepad.app")
            if fn then
                pcall(fn, file.path)
            end
        end
    elseif ext == "txt" then
        if fs.exists("notepad.app") then
            local fn, err = loadfile("notepad.app")
            if fn then
                pcall(fn, file.path)
            end
        end
    else
        -- Try to view as text
        local f = fs.open(file.path, "r")
        if f then
            drawCommander()
            local y = 5
            writeAt("=== " .. file.name .. " ===", 2, y, colors_cmd.bg, colors_cmd.header)
            y = y + 1
            for i = 1, 20 do
                local line = f.readLine()
                if not line then break end
                if y + i < h - 2 then
                    writeAt(line, 4, y + i, colors_cmd.bg, colors_cmd.fg)
                end
            end
            f.close()
            writeAt("Press any key...", 2, h - 3, colors_cmd.bg, colors_cmd.status)
            os.pullEvent("key")
            drawCommander()
        end
    end
    
    drawCommander()
end

local function copyFile(src, dst)
    if fs.isDir(src) then
        if not fs.exists(dst) then
            fs.makeDir(dst)
        end
        local files = fs.list(src)
        for _, file in ipairs(files) do
            if file ~= "rom" then
                copyFile(fs.combine(src, file), fs.combine(dst, file))
            end
        end
    else
        fs.copy(src, dst)
    end
end

local function deleteFile(path)
    if fs.isDir(path) then
        local files = fs.list(path)
        for _, file in ipairs(files) do
            if file ~= "rom" then
                deleteFile(fs.combine(path, file))
            end
        end
        fs.delete(path)
    else
        fs.delete(path)
    end
end

local function viewFile(file)
    local f = fs.open(file.path, "r")
    if f then
        drawCommander()
        local y = 5
        writeAt("=== " .. file.name .. " ===", 2, y, colors_cmd.bg, colors_cmd.header)
        y = y + 1
        local lineNum = 0
        while true do
            local line = f.readLine()
            if not line or lineNum > 30 then break end
            if y + lineNum < h - 2 then
                writeAt(line, 4, y + lineNum, colors_cmd.bg, colors_cmd.fg)
            end
            lineNum = lineNum + 1
        end
        f.close()
        writeAt("Press any key...", 2, h - 3, colors_cmd.bg, colors_cmd.status)
        os.pullEvent("key")
        drawCommander()
    end
end

local function editFile(file)
    if fs.exists("notepad.app") then
        local fn, err = loadfile("notepad.app")
        if fn then
            pcall(fn, file.path)
            drawCommander()
        end
    end
end

local function getCurrentFiles()
    if activePane == "left" then
        return leftFiles, leftSelected, leftPath
    else
        return rightFiles, rightSelected, rightPath
    end
end

local function getOtherPath()
    if activePane == "left" then
        return rightPath
    else
        return leftPath
    end
end

local function copySelected()
    local files, selected = getCurrentFiles()
    if selected <= #files then
        local src = files[selected].path
        local dstPath = getOtherPath()
        local dst = dstPath == "/" and "/" .. files[selected].name or dstPath .. "/" .. files[selected].name
        
        copyFile(src, dst)
        refreshFiles()
        drawCommander()
    end
end

local function moveSelected()
    local files, selected = getCurrentFiles()
    if selected <= #files then
        local src = files[selected].path
        local dstPath = getOtherPath()
        local dst = dstPath == "/" and "/" .. files[selected].name or dstPath .. "/" .. files[selected].name
        
        copyFile(src, dst)
        deleteFile(src)
        refreshFiles()
        drawCommander()
    end
end

local function deleteSelected()
    local files, selected = getCurrentFiles()
    if selected <= #files and files[selected].name ~= ".." then
        confirmAction = "delete"
        confirmTarget = files[selected].name
        showConfirm = true
        drawConfirm()
    end
end

local function newDirectory()
    drawCommander()
    centerText("New directory name:", h - 3, colors_cmd.bg, colors_cmd.header)
    
    local x = math.floor(w / 2) - 15
    local y = h - 2
    term.setCursorPos(x, y)
    term.setCursorBlink(true)
    local name = read()
    term.setCursorBlink(false)
    
    if name and name ~= "" then
        local currentPath = (activePane == "left") and leftPath or rightPath
        local newPath = currentPath == "/" and "/" .. name or currentPath .. "/" .. name
        if not fs.exists(newPath) then
            fs.makeDir(newPath)
            refreshFiles()
        end
    end
    drawCommander()
end

-- ========== MAIN ==========

local function main()
    refreshFiles()
    drawCommander()
    
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            local maxLeft = #leftFiles
            local maxRight = #rightFiles
            local maxItems = h - 6
            
            if showConfirm then
                if key == keys.y then
                    if confirmAction == "delete" then
                        local files, selected = getCurrentFiles()
                        if selected <= #files then
                            deleteFile(files[selected].path)
                            refreshFiles()
                        end
                    end
                    showConfirm = false
                    confirmAction = nil
                    confirmTarget = nil
                    drawCommander()
                elseif key == keys.n or key == keys.escape then
                    showConfirm = false
                    confirmAction = nil
                    confirmTarget = nil
                    drawCommander()
                end
                
            elseif showHelp then
                showHelp = false
                drawCommander()
                
            elseif key == keys.q then
                break
                
            elseif key == keys.tab then
                activePane = (activePane == "left") and "right" or "left"
                drawCommander()
                
            elseif key == keys.f1 then
                showHelp = true
                drawHelp()
                os.pullEvent("key")
                showHelp = false
                drawCommander()
                
            elseif key == keys.f3 then
                local files, selected = getCurrentFiles()
                if selected <= #files and not files[selected].isDir then
                    viewFile(files[selected])
                end
                
            elseif key == keys.f4 then
                local files, selected = getCurrentFiles()
                if selected <= #files and not files[selected].isDir then
                    editFile(files[selected])
                end
                
            elseif key == keys.f5 then
                copySelected()
                
            elseif key == keys.f6 then
                moveSelected()
                
            elseif key == keys.f7 then
                newDirectory()
                
            elseif key == keys.f8 then
                deleteSelected()
                
            elseif key == keys.up then
                if activePane == "left" then
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
                drawCommander()
                
            elseif key == keys.down then
                if activePane == "left" then
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
                drawCommander()
                
            elseif key == keys.enter then
                local files, selected = getCurrentFiles()
                if selected <= #files then
                    openFile(files[selected])
                end
                
            elseif key == keys.home then
                if activePane == "left" then
                    leftSelected = 1
                    leftScroll = 0
                else
                    rightSelected = 1
                    rightScroll = 0
                end
                drawCommander()
                
            elseif key == keys["end"] then
                if activePane == "left" then
                    leftSelected = maxLeft
                    leftScroll = math.max(0, maxLeft - maxItems)
                else
                    rightSelected = maxRight
                    rightScroll = math.max(0, maxRight - maxItems)
                end
                drawCommander()
                
            elseif key == keys.pageUp then
                if activePane == "left" then
                    leftSelected = math.max(1, leftSelected - maxItems)
                    leftScroll = math.max(0, leftSelected - 1)
                else
                    rightSelected = math.max(1, rightSelected - maxItems)
                    rightScroll = math.max(0, rightSelected - 1)
                end
                drawCommander()
                
            elseif key == keys.pageDown then
                if activePane == "left" then
                    leftSelected = math.min(maxLeft, leftSelected + maxItems)
                    leftScroll = math.max(0, leftSelected - maxItems)
                else
                    rightSelected = math.min(maxRight, rightSelected + maxItems)
                    rightScroll = math.max(0, rightSelected - maxItems)
                end
                drawCommander()
            end
            
        elseif event == "mouse_click" then
            local button, x, y = p1, p2, p3
            local paneWidth = math.floor((w - 3) / 2)
            
            -- Check which pane was clicked
            if y >= 3 and y <= h - 2 then
                if x >= 2 and x <= paneWidth + 1 then
                    activePane = "left"
                    local idx = y - 3 + leftScroll + 1
                    if idx >= 1 and idx <= #leftFiles then
                        leftSelected = idx
                        drawCommander()
                        if button == 1 then
                            openFile(leftFiles[idx])
                        end
                    end
                elseif x >= paneWidth + 4 and x <= w - 2 then
                    activePane = "right"
                    local idx = y - 3 + rightScroll + 1
                    if idx >= 1 and idx <= #rightFiles then
                        rightSelected = idx
                        drawCommander()
                        if button == 1 then
                            openFile(rightFiles[idx])
                        end
                    end
                end
            end
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Commander error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end
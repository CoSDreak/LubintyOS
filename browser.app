-- name: Web Browser
-- icon: [WEB]

-- browser.app
-- Simple web browser for Lubinty OS using HTTP API

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys
local http = http
local paintutils = paintutils

-- ========== GLOBALS ==========

local currentUrl = "https://example.com"
local pageContent = ""
local pageTitle = "Welcome"
local status = "Ready"
local isLoading = false
local inputUrl = ""
local cursorPos = 1
local scrollY = 0
local maxScroll = 0
local history = {}
local historyIndex = 0

local w, h = 0, 0
local urlInputX = 4
local urlInputY = 2
local contentStartY = 4

-- ========== COLORS ==========

local colors_browser = {
    bg = colors.black,
    fg = colors.white,
    header = colors.cyan,
    urlBar = colors.lightGray,
    urlText = colors.black,
    link = colors.blue,
    visited = colors.purple,
    error = colors.red,
    loading = colors.yellow,
    button = colors.gray,
    buttonText = colors.white
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
        writeAt(" " .. title .. " ", x1 + 2, y1, border, colors_browser.header)
    end
end

-- ========== URL HANDLING ==========

local function stripHtml(content)
    local text = content
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&amp;", "&")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    return text
end

local function getPageTitle(content)
    local title = content:match("<title>(.-)</title>")
    if title then
        return stripHtml(title)
    end
    return "Untitled"
end

local function loadPage(url)
    if not url:match("^https?://") then
        url = "http://" .. url
    end
    
    isLoading = true
    status = "Loading " .. url .. "..."
    currentUrl = url
    pageContent = ""
    pageTitle = "Loading..."
    scrollY = 0
    
    local response = http.get(url)
    
    if response then
        pageContent = response.readAll()
        response.close()
        pageTitle = getPageTitle(pageContent)
        status = "Loaded: " .. pageTitle
        maxScroll = math.max(0, #pageContent / (w - 4) - (h - contentStartY - 2))
    else
        pageContent = ""
        pageTitle = "Error"
        status = "Failed to load: " .. url
    end
    
    isLoading = false
    
    if historyIndex < #history then
        for i = #history, historyIndex + 1, -1 do
            table.remove(history, i)
        end
    end
    table.insert(history, currentUrl)
    historyIndex = #history
end

local function goBack()
    if historyIndex > 1 then
        historyIndex = historyIndex - 1
        loadPage(history[historyIndex])
    end
end

local function goForward()
    if historyIndex < #history then
        historyIndex = historyIndex + 1
        loadPage(history[historyIndex])
    end
end

local function reloadPage()
    if currentUrl then
        loadPage(currentUrl)
    end
end

-- ========== DRAW UI ==========

local function drawHeader()
    for x = 1, w do
        writeAt(" ", x, 1, colors_browser.header, colors_browser.fg)
    end
    
    writeAt(" LUBINTY BROWSER ", 2, 1, colors_browser.header, colors_browser.fg)
    writeAt("[<]", 18, 1, colors_browser.button, colors_browser.buttonText)
    writeAt("[>]", 22, 1, colors_browser.button, colors_browser.buttonText)
    writeAt("[R]", 26, 1, colors_browser.button, colors_browser.buttonText)
    
    for x = urlInputX, w - 2 do
        writeAt(" ", x, urlInputY, colors_browser.urlBar, colors_browser.urlText)
    end
    
    local displayUrl = inputUrl ~= "" and inputUrl or currentUrl
    if #displayUrl > w - 6 then
        displayUrl = "..." .. displayUrl:sub(-(w - 9))
    end
    writeAt(" " .. displayUrl, urlInputX, urlInputY, colors_browser.urlBar, colors_browser.urlText)
    
    writeAt(" " .. pageTitle .. " ", 2, urlInputY, colors_browser.header, colors_browser.fg)
    
    local statusColor = isLoading and colors_browser.loading or colors_browser.fg
    writeAt(status, 2, h, colors_browser.bg, statusColor)
end

local function drawContent()
    for y = contentStartY, h - 1 do
        for x = 2, w - 1 do
            writeAt(" ", x, y, colors_browser.bg, colors_browser.fg)
        end
    end
    
    if pageContent == "" then
        if isLoading then
            centerText("Loading...", math.floor((h - contentStartY) / 2) + contentStartY, colors_browser.bg, colors_browser.loading)
        else
            centerText("No content loaded", math.floor((h - contentStartY) / 2) + contentStartY, colors_browser.bg, colors_browser.fg)
            centerText("Enter a URL above and press ENTER", math.floor((h - contentStartY) / 2) + contentStartY + 2, colors_browser.bg, colors_browser.header)
        end
        return
    end
    
    local text = stripHtml(pageContent)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        while #line > w - 4 do
            table.insert(lines, line:sub(1, w - 4))
            line = line:sub(w - 3)
        end
        table.insert(lines, line)
    end
    
    local maxLines = h - contentStartY - 1
    for i = 1, maxLines do
        local lineIdx = scrollY + i
        if lineIdx <= #lines then
            writeAt(lines[lineIdx], 3, contentStartY + i - 1, colors_browser.bg, colors_browser.fg)
        end
    end
    
    if maxScroll > 0 then
        local scrollPercent = scrollY / maxScroll
        local scrollBarHeight = math.max(3, maxLines - 2)
        local scrollBarPos = math.floor(scrollPercent * scrollBarHeight) + contentStartY
        writeAt("█", w - 1, scrollBarPos, colors_browser.header, colors_browser.header)
    end
end

local function drawBrowser()
    getSize()
    term.clear()
    term.setBackgroundColor(colors_browser.bg)
    
    drawHeader()
    drawContent()
    
    writeAt(" [Back] [Forward] [Reload]  [Q] Exit ", 2, h, colors_browser.bg, colors_browser.header)
end

-- ========== URL INPUT ==========

local function editUrl()
    inputUrl = currentUrl
    cursorPos = #inputUrl + 1
    drawBrowser()
    term.setCursorPos(urlInputX + 1 + #inputUrl, urlInputY)
    term.setCursorBlink(true)
    
    while true do
        local event, key = os.pullEvent("key")
        
        if key == keys.enter then
            term.setCursorBlink(false)
            if inputUrl ~= "" then
                loadPage(inputUrl)
            end
            inputUrl = ""
            break
            
        elseif key == keys.escape then
            term.setCursorBlink(false)
            inputUrl = ""
            break
            
        elseif key == keys.backspace then
            if cursorPos > 1 then
                inputUrl = inputUrl:sub(1, cursorPos - 2) .. inputUrl:sub(cursorPos)
                cursorPos = cursorPos - 1
                drawBrowser()
                term.setCursorPos(urlInputX + cursorPos - 1, urlInputY)
            end
            
        elseif key == keys.left then
            if cursorPos > 1 then
                cursorPos = cursorPos - 1
                term.setCursorPos(urlInputX + cursorPos - 1, urlInputY)
            end
            
        elseif key == keys.right then
            if cursorPos <= #inputUrl then
                cursorPos = cursorPos + 1
                term.setCursorPos(urlInputX + cursorPos - 1, urlInputY)
            end
            
        else
            local char = keys.getName(key)
            if char and #char == 1 and char:match("[%w%p]") then
                inputUrl = inputUrl:sub(1, cursorPos - 1) .. char .. inputUrl:sub(cursorPos)
                cursorPos = cursorPos + 1
                drawBrowser()
                term.setCursorPos(urlInputX + cursorPos - 1, urlInputY)
            end
        end
    end
    
    drawBrowser()
end

-- ========== MAIN ==========

local function main()
    getSize()
    term.clear()
    term.setCursorBlink(false)
    
    loadPage("https://example.com")
    
    while true do
        drawBrowser()
        
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                break
                
            elseif key == keys.enter then
                editUrl()
                
            elseif key == keys.up then
                if scrollY > 0 then
                    scrollY = math.max(0, scrollY - 3)
                    drawBrowser()
                end
                
            elseif key == keys.down then
                if scrollY < maxScroll then
                    scrollY = math.min(maxScroll, scrollY + 3)
                    drawBrowser()
                end
                
            elseif key == keys.pageUp then
                scrollY = math.max(0, scrollY - (h - contentStartY - 2))
                drawBrowser()
                
            elseif key == keys.pageDown then
                scrollY = math.min(maxScroll, scrollY + (h - contentStartY - 2))
                drawBrowser()
                
            elseif key == keys.home then
                scrollY = 0
                drawBrowser()
                
            elseif key == keys["end"] then
                scrollY = maxScroll
                drawBrowser()
                
            elseif key == keys.r then
                reloadPage()
                
            elseif key == keys.left then
                goBack()
                
            elseif key == keys.right then
                goForward()
            end
            
        elseif event == "mouse_click" then
            local button, x, y = p1, p2, p3
            
            if y == 1 then
                if x >= 18 and x <= 20 then
                    goBack()
                elseif x >= 22 and x <= 24 then
                    goForward()
                elseif x >= 26 and x <= 28 then
                    reloadPage()
                end
            elseif y == urlInputY and x >= urlInputX and x <= w - 2 then
                editUrl()
            end
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    print("Browser closed.")
    sleep(1)
    term.clear()
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Browser error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

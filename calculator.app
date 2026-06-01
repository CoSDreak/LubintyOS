-- Load tween animation library
local tween
local ok, err = pcall(loadfile, "tween.lua")
if ok and err then
    tween = err
end

-- name: Calculator
-- icon: [CALC]
-- vers: [1.0]

-- calculator.app
-- Simple calculator for Lubinty OS

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local display = "0"
local accumulator = 0
local operation = nil
local newNumber = true
local selectedRow = 1
local selectedCol = 1

local w, h = 0, 0
local startX, startY = 0, 0

-- Button layout (4 rows, 5 columns)
local buttons = {
    {"7", "8", "9", "/", "C"},
    {"4", "5", "6", "*", "CE"},
    {"1", "2", "3", "-", "%"},
    {"0", "00", ".", "+", "="}
}

-- ========== COLORS ==========

local colors_calc = {
    bg = colors.lightGray,      -- Фон калькулятора (светло-серый)
    screenBg = colors.gray,     -- Фон экрана
    screenFg = colors.black,    -- Текст на экране
    border = colors.blue,       -- Рамка
    number = colors.lightGray,  -- Кнопки с цифрами
    operator = colors.cyan,     -- Кнопки операций
    clear = colors.red,         -- Кнопки C и CE
    equal = colors.green        -- Кнопка =
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

-- ========== CALCULATOR LOGIC ==========

local function executeOperation()
    local num = tonumber(display) or 0
    
    if operation == "+" then
        accumulator = accumulator + num
    elseif operation == "-" then
        accumulator = accumulator - num
    elseif operation == "*" then
        accumulator = accumulator * num
    elseif operation == "/" then
        if num ~= 0 then
            accumulator = accumulator / num
        else
            display = "ERROR"
            operation = nil
            newNumber = true
            return
        end
    elseif operation == "%" then
        accumulator = accumulator * num / 100
    else
        accumulator = num
    end
    
    display = tostring(accumulator)
    if display:find("%.") then
        display = string.format("%.10g", accumulator)
    end
    if #display > 15 then
        display = display:sub(1, 15)
    end
    
    operation = nil
    newNumber = true
end

local function pressKey(key)
    if key == "C" then
        display = "0"
        accumulator = 0
        operation = nil
        newNumber = true
        
    elseif key == "CE" then
        display = "0"
        newNumber = true
        
    elseif key == "=" then
        executeOperation()
        
    elseif key == "+" or key == "-" or key == "*" or key == "/" or key == "%" then
        if not newNumber and operation then
            local num = tonumber(display) or 0
            if operation == "+" then accumulator = accumulator + num
            elseif operation == "-" then accumulator = accumulator - num
            elseif operation == "*" then accumulator = accumulator * num
            elseif operation == "/" and num ~= 0 then accumulator = accumulator / num
            elseif operation == "%" then accumulator = accumulator * num / 100
            end
            display = tostring(accumulator)
            if #display > 15 then display = display:sub(1, 15) end
        elseif not operation then
            accumulator = tonumber(display) or 0
        end
        operation = key
        newNumber = true
        
    elseif key == "." then
        if newNumber then
            display = "0."
            newNumber = false
        elseif not display:find("%.") then
            display = display .. "."
        end
        
    elseif key == "00" then
        if newNumber then
            display = "0"
            newNumber = false
        else
            display = display .. "00"
        end
        if #display > 15 then display = display:sub(1, 15) end
        
    elseif key:match("%d") then
        if newNumber then
            display = key
            newNumber = false
        else
            if display == "0" then
                display = key
            else
                display = display .. key
            end
        end
        if #display > 15 then display = display:sub(1, 15) end
    end
end

-- ========== DRAW ==========

local function drawCalculator()
    getSize()
    
    -- Центрируем калькулятор
    local winW = 33
    local winH = 13
    startX = math.max(1, math.floor((w - winW) / 2))
    startY = math.max(1, math.floor((h - winH) / 2))
    
    -- Рисуем фон калькулятора (светло-серый прямоугольник)
    for y = startY, startY + winH do
        for x = startX, startX + winW do
            writeAt(" ", x, y, colors_calc.bg, colors_calc.screenFg)
        end
    end
    
    -- Рамка
    for x = startX, startX + winW do
        writeAt("-", x, startY, colors_calc.border, colors_calc.border)
        writeAt("-", x, startY + winH, colors_calc.border, colors_calc.border)
    end
    for y = startY, startY + winH do
        writeAt("|", startX, y, colors_calc.border, colors_calc.border)
        writeAt("|", startX + winW, y, colors_calc.border, colors_calc.border)
    end
    writeAt("+", startX, startY, colors_calc.border, colors_calc.border)
    writeAt("+", startX + winW, startY, colors_calc.border, colors_calc.border)
    writeAt("+", startX, startY + winH, colors_calc.border, colors_calc.border)
    writeAt("+", startX + winW, startY + winH, colors_calc.border, colors_calc.border)
    
    -- Заголовок
    writeAt(" CALCULATOR ", startX + 11, startY, colors_calc.border, colors_calc.screenFg)
    
    -- Экран
    local screenX = startX + 2
    local screenY = startY + 2
    local screenW = winW - 4
    
    for x = screenX, screenX + screenW - 1 do
        writeAt(" ", x, screenY, colors_calc.screenBg, colors_calc.screenFg)
    end
    
    -- Вывод числа (выравнивание вправо)
    local displayText = display
    if #displayText > screenW - 2 then
        displayText = displayText:sub(1, screenW - 5) .. "..."
    end
    local textX = screenX + screenW - #displayText - 1
    writeAt(displayText, textX, screenY, colors_calc.screenBg, colors_calc.screenFg)
    
    -- Кнопки
    local btnW = 5
    local btnH = 2
    local btnStartX = startX + 2
    local btnStartY = startY + 4
    
    for i = 1, 4 do
        for j = 1, 5 do
            local x = btnStartX + (j - 1) * btnW
            local y = btnStartY + (i - 1) * btnH
            
            local btn = buttons[i][j]
            local isSelected = (selectedRow == i and selectedCol == j)
            
            -- Цвет кнопки
            local bg, fg
            if btn:match("%d") or btn == "00" or btn == "." then
                bg = colors_calc.number
                fg = colors.black
            elseif btn == "C" or btn == "CE" then
                bg = colors_calc.clear
                fg = colors.white
            elseif btn == "=" then
                bg = colors_calc.equal
                fg = colors.black
            else
                bg = colors_calc.operator
                fg = colors.white
            end
            
            if isSelected then
                bg = colors.yellow
                fg = colors.black
            end
            
            -- Рисуем кнопку
            writeAt("[", x, y, bg, fg)
            writeAt(btn, x + 1, y, bg, fg)
            if #btn == 1 then
                writeAt("]", x + 2, y, bg, fg)
            else
                writeAt("]", x + 3, y, bg, fg)
            end
        end
    end
    
    -- Подсказки
    local footerY = startY + winH - 1
    writeAt(" Arrows: move   ENTER: press   Backspace: delete   Q: exit ", startX + 1, footerY, colors_calc.bg, colors.black)
end

-- ========== MAIN ==========

local function main()
    getSize()
    drawCalculator()
    
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                break
                
            elseif key == keys.up then
                selectedRow = math.max(1, selectedRow - 1)
                drawCalculator()
                
            elseif key == keys.down then
                selectedRow = math.min(4, selectedRow + 1)
                drawCalculator()
                
            elseif key == keys.left then
                selectedCol = math.max(1, selectedCol - 1)
                drawCalculator()
                
            elseif key == keys.right then
                selectedCol = math.min(5, selectedCol + 1)
                drawCalculator()
                
            elseif key == keys.enter then
                pressKey(buttons[selectedRow][selectedCol])
                drawCalculator()
                
            elseif key == keys.backspace then
                if #display > 1 then
                    display = display:sub(1, -2)
                else
                    display = "0"
                    newNumber = true
                end
                drawCalculator()
            end
            
        elseif event == "mouse_click" then
            local button, x, y = p1, p2, p3
            
            -- Проверяем, что клик внутри области калькулятора
            if x >= startX and x <= startX + 33 and y >= startY and y <= startY + 13 then
                local btnW = 5
                local btnH = 2
                local btnStartX = startX + 2
                local btnStartY = startY + 4
                
                for i = 1, 4 do
                    for j = 1, 5 do
                        local btnX = btnStartX + (j - 1) * btnW
                        local btnY = btnStartY + (i - 1) * btnH
                        
                        if x >= btnX and x <= btnX + 4 and y == btnY then
                            selectedRow = i
                            selectedCol = j
                            pressKey(buttons[i][j])
                            drawCalculator()
                            break
                        end
                    end
                end
            end
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
end

-- Run calculator
local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Calculator error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

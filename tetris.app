-- name: Tetris
-- icon: [TET]

-- tetris.app
-- Classic Tetris game for Lubinty OS

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local field = {}
local fieldWidth = 10
local fieldHeight = 20
local currentPiece = nil
local nextPiece = nil
local pieceX = 0
local pieceY = 0
local score = 0
local level = 1
local lines = 0
local gameOver = false
local paused = false
local fallTimer = nil
local fallDelay = 0.5

local w, h = 0, 0
local startX, startY = 0, 0

-- Tetromino shapes
local pieces = {
    -- I
    {
        shape = {{1,1,1,1}},
        color = colors.cyan
    },
    -- O
    {
        shape = {{1,1},{1,1}},
        color = colors.yellow
    },
    -- T
    {
        shape = {{0,1,0},{1,1,1}},
        color = colors.purple
    },
    -- S
    {
        shape = {{0,1,1},{1,1,0}},
        color = colors.green
    },
    -- Z
    {
        shape = {{1,1,0},{0,1,1}},
        color = colors.red
    },
    -- J
    {
        shape = {{1,0,0},{1,1,1}},
        color = colors.blue
    },
    -- L
    {
        shape = {{0,0,1},{1,1,1}},
        color = colors.orange
    }
}

-- ========== COLORS ==========

local colors_tetris = {
    bg = colors.black,
    fg = colors.white,
    border = colors.cyan,
    fieldBg = colors.gray,
    score = colors.yellow,
    next = colors.lightGray,
    gameOver = colors.red
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
        writeAt(" " .. title .. " ", x1 + 2, y1, border, colors_tetris.fg)
    end
end

-- ========== GAME LOGIC ==========

local function initField()
    for y = 1, fieldHeight do
        field[y] = {}
        for x = 1, fieldWidth do
            field[y][x] = 0
        end
    end
end

local function randomPiece()
    return pieces[math.random(#pieces)]
end

local function checkCollision()
    for y = 1, #currentPiece.shape do
        for x = 1, #currentPiece.shape[y] do
            if currentPiece.shape[y][x] ~= 0 then
                local fieldX = pieceX + x - 1
                local fieldY = pieceY + y - 1
                
                if fieldX < 1 or fieldX > fieldWidth or fieldY > fieldHeight then
                    return false
                end
                
                if fieldY >= 1 and field[fieldY][fieldX] ~= 0 then
                    return false
                end
            end
        end
    end
    return true
end

local function mergePiece()
    for y = 1, #currentPiece.shape do
        for x = 1, #currentPiece.shape[y] do
            if currentPiece.shape[y][x] ~= 0 then
                local fieldX = pieceX + x - 1
                local fieldY = pieceY + y - 1
                
                if fieldY >= 1 and fieldY <= fieldHeight then
                    field[fieldY][fieldX] = currentPiece.color
                end
            end
        end
    end
    
    local linesCleared = 0
    for y = fieldHeight, 1, -1 do
        local full = true
        for x = 1, fieldWidth do
            if field[y][x] == 0 then
                full = false
                break
            end
        end
        
        if full then
            for y2 = y, 2, -1 do
                for x = 1, fieldWidth do
                    field[y2][x] = field[y2 - 1][x]
                end
            end
            for x = 1, fieldWidth do
                field[1][x] = 0
            end
            linesCleared = linesCleared + 1
            y = y + 1
        end
    end
    
    if linesCleared > 0 then
        local points = {0, 100, 300, 500, 800}
        local addScore = points[math.min(linesCleared + 1, #points)] * level
        score = score + addScore
        lines = lines + linesCleared
        level = math.floor(lines / 10) + 1
        fallDelay = 0.5 / level
        if fallDelay < 0.1 then fallDelay = 0.1 end
    end
    
    -- Создаём новую фигуру
    if not nextPiece then
        nextPiece = randomPiece()
    end
    
    currentPiece = nextPiece
    nextPiece = randomPiece()
    
    pieceX = math.floor((fieldWidth - #currentPiece.shape[1]) / 2) + 1
    pieceY = 1
    
    if not checkCollision() then
        gameOver = true
    end
end

local function movePiece(dx, dy)
    pieceX = pieceX + dx
    pieceY = pieceY + dy
    
    if not checkCollision() then
        pieceX = pieceX - dx
        pieceY = pieceY - dy
        
        if dy > 0 then
            mergePiece()
        end
        return false
    end
    return true
end

local function rotatePiece()
    local oldShape = currentPiece.shape
    local newShape = {}
    
    for y = 1, #oldShape[1] do
        newShape[y] = {}
        for x = 1, #oldShape do
            newShape[y][x] = oldShape[#oldShape - x + 1][y]
        end
    end
    
    local oldPiece = currentPiece.shape
    currentPiece.shape = newShape
    
    if not checkCollision() then
        currentPiece.shape = oldPiece
    end
end

local function dropPiece()
    while movePiece(0, 1) do end
end

local function startNewGame()
    initField()
    score = 0
    lines = 0
    level = 1
    fallDelay = 0.5
    gameOver = false
    paused = false
    nextPiece = randomPiece()
    
    -- Создаём первую фигуру
    currentPiece = nextPiece
    nextPiece = randomPiece()
    pieceX = math.floor((fieldWidth - #currentPiece.shape[1]) / 2) + 1
    pieceY = 1
end

-- ========== DRAW (НЕ НА ВЕСЬ ЭКРАН) ==========

local function drawGame()
    getSize()
    
    local gameW = fieldWidth * 2 + 25
    local gameH = fieldHeight + 8
    startX = math.max(1, math.floor((w - gameW) / 2))
    startY = math.max(1, math.floor((h - gameH) / 2))
    
    -- Clear area behind game
    for y = startY, startY + gameH do
        for x = startX, startX + gameW do
            writeAt(" ", x, y, colors_tetris.bg, colors_tetris.bg)
        end
    end
    
    drawBox(startX, startY, startX + gameW, startY + gameH, colors_tetris.bg, colors_tetris.border, " TETRIS ")
    
    -- Field
    local fieldStartX = startX + 3
    local fieldStartY = startY + 3
    
    for y = 1, fieldHeight do
        for x = 1, fieldWidth do
            local screenX = fieldStartX + (x - 1) * 2
            local screenY = fieldStartY + y - 1
            local color = field[y][x]
            
            if color ~= 0 then
                writeAt("[]", screenX, screenY, color, color)
            else
                writeAt("..", screenX, screenY, colors_tetris.fieldBg, colors_tetris.fieldBg)
            end
        end
    end
    
    -- Current piece
    if currentPiece and not gameOver then
        for y = 1, #currentPiece.shape do
            for x = 1, #currentPiece.shape[y] do
                if currentPiece.shape[y][x] ~= 0 then
                    local fieldX = pieceX + x - 1
                    local fieldY = pieceY + y - 1
                    if fieldY >= 1 and fieldY <= fieldHeight then
                        local screenX = fieldStartX + (fieldX - 1) * 2
                        local screenY = fieldStartY + fieldY - 1
                        writeAt("[]", screenX, screenY, currentPiece.color, currentPiece.color)
                    end
                end
            end
        end
    end
    
    -- Next piece
    local nextX = startX + gameW - 12
    local nextY = startY + 4
    writeAt("NEXT:", nextX, nextY, colors_tetris.bg, colors_tetris.next)
    
    if nextPiece then
        for y = 1, #nextPiece.shape do
            for x = 1, #nextPiece.shape[y] do
                if nextPiece.shape[y][x] ~= 0 then
                    local screenX = nextX + x * 2
                    local screenY = nextY + y + 1
                    writeAt("[]", screenX, screenY, nextPiece.color, nextPiece.color)
                end
            end
        end
    end
    
    -- Info
    local infoX = startX + gameW - 12
    local infoY = startY + 12
    writeAt("SCORE:", infoX, infoY, colors_tetris.bg, colors_tetris.score)
    writeAt(score, infoX, infoY + 1, colors_tetris.bg, colors_tetris.fg)
    writeAt("LINES:", infoX, infoY + 3, colors_tetris.bg, colors_tetris.score)
    writeAt(lines, infoX, infoY + 4, colors_tetris.bg, colors_tetris.fg)
    writeAt("LEVEL:", infoX, infoY + 6, colors_tetris.bg, colors_tetris.score)
    writeAt(level, infoX, infoY + 7, colors_tetris.bg, colors_tetris.fg)
    
    -- Game over / Pause
    if gameOver then
        centerText("GAME OVER", startY + gameH - 4, colors_tetris.bg, colors_tetris.gameOver)
        centerText("Press R to restart, Q to exit", startY + gameH - 2, colors_tetris.bg, colors_tetris.fg)
    elseif paused then
        centerText("PAUSED", startY + gameH - 3, colors_tetris.bg, colors_tetris.gameOver)
    end
    
    -- Controls hint
    local controlsY = startY + gameH - 1
    writeAt("L/R Move  UP Rotate  DOWN Soft  SPACE Hard  P Pause  Q Exit", startX + 2, controlsY, colors_tetris.bg, colors_tetris.fg)
end

-- ========== GAME LOOP ==========

local function gameLoop()
    fallTimer = os.startTimer(fallDelay)
    
    while true do
        drawGame()
        
        if gameOver then
            local ev, key = os.pullEvent()
            if ev == "key" then
                if key == keys.q then
                    break
                elseif key == keys.r then
                    startNewGame()
                    fallTimer = os.startTimer(fallDelay)
                end
            end
        else
            local event, p1 = os.pullEvent()
            
            if event == "key" then
                local key = p1
                
                if key == keys.q then
                    break
                elseif key == keys.p then
                    paused = not paused
                elseif not paused then
                    if key == keys.left then
                        movePiece(-1, 0)
                    elseif key == keys.right then
                        movePiece(1, 0)
                    elseif key == keys.down then
                        movePiece(0, 1)
                    elseif key == keys.up then
                        rotatePiece()
                    elseif key == keys.space then
                        dropPiece()
                    end
                end
                
            elseif event == "timer" and p1 == fallTimer then
                if not paused and not gameOver then
                    movePiece(0, 1)
                end
                fallTimer = os.startTimer(fallDelay)
            end
        end
    end
end

-- ========== MAIN ==========

local function main()
    term.clear()
    math.randomseed(os.time())
    
    startNewGame()
    gameLoop()
    
    term.clear()
    centerText("Thanks for playing!", 5, colors_tetris.bg, colors_tetris.fg)
    centerText("Press any key to exit...", 7, colors_tetris.bg, colors_tetris.fg)
    os.pullEvent("key")
    term.clear()
end

-- Run tetris
local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Tetris error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end
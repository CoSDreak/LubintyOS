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

-- name: Snake
-- icon: [SNAKE]

-- snake.app
-- Classic Snake game for Lubinty OS

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys

-- ========== GLOBALS ==========

local width = 30
local height = 15
local snake = {{x = 15, y = 8}}
local direction = {x = 1, y = 0}
local nextDirection = {x = 1, y = 0}
local food = {x = 10, y = 8}
local score = 0
local gameOver = false
local paused = false
local speed = 0.15
local gameTimer = nil

local w, h = 0, 0
local offsetX = 0
local offsetY = 0

-- ========== COLORS ==========

local colors_snake = {
    bg = colors.black,
    fg = colors.white,
    snake = colors.green,
    food = colors.red,
    border = colors.cyan,
    score = colors.yellow
}

-- ========== UTILITIES ==========

local function getSize()
    w, h = term.getSize()
    if w < 1 then w = 51 end
    if h < 1 then h = 19 end
    offsetX = math.floor((w - width - 4) / 2)
    offsetY = math.floor((h - height - 4) / 2)
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

-- ========== GAME LOGIC ==========

local function generateFood()
    repeat
        food.x = math.random(1, width)
        food.y = math.random(1, height)
        local onSnake = false
        for _, segment in ipairs(snake) do
            if segment.x == food.x and segment.y == food.y then
                onSnake = true
                break
            end
        end
        if not onSnake then break end
    until false
end

local function updateGame()
    if gameOver or paused then return end
    
    direction = nextDirection
    
    local newHead = {
        x = snake[1].x + direction.x,
        y = snake[1].y + direction.y
    }
    
    -- Check wall collision
    if newHead.x < 1 or newHead.x > width or newHead.y < 1 or newHead.y > height then
        gameOver = true
        return
    end
    
    -- Check self collision
    for i, segment in ipairs(snake) do
        if segment.x == newHead.x and segment.y == newHead.y then
            gameOver = true
            return
        end
    end
    
    table.insert(snake, 1, newHead)
    
    -- Check food collision
    if newHead.x == food.x and newHead.y == food.y then
        score = score + 10
        generateFood()
        if score % 50 == 0 then
            speed = math.max(0.05, speed - 0.01)
        end
    else
        table.remove(snake)
    end
end

-- ========== DRAW ==========

local function drawGame()
    getSize()
    term.setBackgroundColor(colors_snake.bg)
    term.clear()
    
    -- Score
    centerText("SCORE: " .. score, 1, colors_snake.bg, colors_snake.score)
    
    -- Border
    for i = 1, width + 2 do
        writeAt("#", offsetX + i - 1, offsetY - 1, colors_snake.border, colors_snake.border)
        writeAt("#", offsetX + i - 1, offsetY + height, colors_snake.border, colors_snake.border)
    end
    for i = 1, height do
        writeAt("#", offsetX - 1, offsetY + i - 1, colors_snake.border, colors_snake.border)
        writeAt("#", offsetX + width, offsetY + i - 1, colors_snake.border, colors_snake.border)
    end
    
    -- Food
    writeAt("●", offsetX + food.x - 1, offsetY + food.y - 1, colors_snake.food, colors_snake.food)
    
    -- Snake
    for i, segment in ipairs(snake) do
        local char = "■"
        if i == 1 then char = "◆" end
        writeAt(char, offsetX + segment.x - 1, offsetY + segment.y - 1, colors_snake.snake, colors_snake.snake)
    end
    
    -- Game over
    if gameOver then
        centerText("GAME OVER", math.floor(h / 2), colors_snake.bg, colors_snake.fg)
        centerText("Press R to restart, Q to quit", math.floor(h / 2) + 2, colors_snake.bg, colors_snake.fg)
    elseif paused then
        centerText("PAUSED", math.floor(h / 2), colors_snake.bg, colors_snake.fg)
        centerText("Press P to resume", math.floor(h / 2) + 2, colors_snake.bg, colors_snake.fg)
    end
    
    -- Controls
    writeAt("WASD or Arrows", offsetX, offsetY + height + 1, colors_snake.bg, colors_snake.fg)
    writeAt("P-Pause  Q-Quit", offsetX + width - 15, offsetY + height + 1, colors_snake.bg, colors_snake.fg)
end

-- ========== MAIN GAME LOOP ==========

local function gameLoop()
    gameTimer = os.startTimer(speed)
    
    while true do
        drawGame()
        
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                break
            elseif key == keys.r and gameOver then
                -- Restart
                snake = {{x = 15, y = 8}}
                direction = {x = 1, y = 0}
                nextDirection = {x = 1, y = 0}
                score = 0
                speed = 0.15
                gameOver = false
                generateFood()
            elseif not gameOver then
                if key == keys.p then
                    paused = not paused
                elseif not paused then
                    if key == keys.up or key == keys.w then
                        if direction.y ~= 1 then
                            nextDirection = {x = 0, y = -1}
                        end
                    elseif key == keys.down or key == keys.s then
                        if direction.y ~= -1 then
                            nextDirection = {x = 0, y = 1}
                        end
                    elseif key == keys.left or key == keys.a then
                        if direction.x ~= 1 then
                            nextDirection = {x = -1, y = 0}
                        end
                    elseif key == keys.right or key == keys.d then
                        if direction.x ~= -1 then
                            nextDirection = {x = 1, y = 0}
                        end
                    end
                end
            end
            
        elseif event == "timer" and p1 == gameTimer then
            if not gameOver and not paused then
                updateGame()
            end
            gameTimer = os.startTimer(speed)
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
end

-- Run game
local function main()
    term.clear()
    generateFood()
    gameLoop()
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Snake error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

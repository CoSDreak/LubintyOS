-- name: Flappy Block
-- icon: [FLY]
-- vers: [1.0]

-- flappy.app
-- Flappy Bird style game for Lubinty OS

WIDTH, HEIGHT = term.getSize()

GRAVITY = 0.15
PIPE_SPEED = 0.5
JUMP_STRENGTH = 0.9
VELOCITY_MAX = 0.9
PIPE_WIDTH = 3 -- In both directions. is actually opening size.
GAME_OVER_TIMER = 1 -- How much time must pass before you can reset after a game over

PIPE_HOZWIDTH = 3 -- actual pipe width.

ALLOWED_KEYS = {keys.w, keys.up, keys.space, keys.b}

dbg = false -- debug 

local pipes = {}

local playerY = HEIGHT/2
local playerX = 5
local playerVelocity = 0

local gameOver = false
local paused = false
local justStarted = true
local canReset = false
local gameOverTimer = 1

local score = 0
local highscore = 0

local darkmode = false
local forceBasic = false
local gameRunning = true

function writeAt(str,x,y)
    term.setCursorPos(x,y)
    write(tostring(str))
end

function tablehas(tble,value)
    has = false
    for i,v in ipairs(tble) do
        if v == value then
            has = true
            break
        end
    end
    return has
end

function isColorless()
    return (not term.isColor()) or forceBasic
end

function reset()
    gameOver = false
    paused = false
    playerY = HEIGHT/2
    playerVelocity = 0
    pipes = {}
    score = 0
    gameOverTimer = 1
    canReset = false
    justStarted = true
end

function drawBG()
    paintutils.drawFilledBox(1,1,WIDTH,HEIGHT,(darkmode or isColorless()) and colors.black or colors.cyan)
end

function drawPlayer()
    if playerY < 0 or playerY > HEIGHT then return end
    paintutils.drawPixel(playerX,playerY,not isColorless() and colors.red or colors.white)
end

function drawGround()
    paintutils.drawLine(1,HEIGHT-2,WIDTH, HEIGHT-2,colors.green)
    paintutils.drawFilledBox(1,HEIGHT-1,WIDTH,HEIGHT,colors.yellow)
end

function drawPipes()
    for i,v in ipairs(pipes) do
        paintutils.drawFilledBox(v.x,v.y-PIPE_WIDTH,v.x+PIPE_HOZWIDTH,0,colors.lime)
        paintutils.drawFilledBox(v.x,v.y+PIPE_WIDTH,v.x+PIPE_HOZWIDTH,HEIGHT,colors.lime)
    end
end

function drawText()
    term.setBackgroundColor(colors.black)
    writeAt(score,WIDTH/2,2)
    
    if gameOver then
        writeAt("GAME   OVER!",WIDTH/2-5,HEIGHT/2-1)
        writeAt("Score: "..tostring(score),WIDTH/2-4,HEIGHT/2)
    end
    if canReset and gameOver then
        writeAt("Tap to restart.", WIDTH/2-7,HEIGHT/2+2)
    end

    if justStarted then
        writeAt("FLAPPY BLOCK(taked from https://github.com/bartek18887, thank you,bartek18887)",WIDTH/2-5,HEIGHT/2-1)
        writeAt("Lubinty Edition",WIDTH/2-7,HEIGHT/2)
        writeAt("Tap anywhere to start.",WIDTH/2-11,HEIGHT/2+2)
        writeAt("Press Q to exit",WIDTH/2-7,HEIGHT/2+4)
    end
end

function onGameOver()
    gameOver = true
    playerVelocity = 0
end

function pipeCreator()
    while gameRunning do
        sleep(2)
        local newPipe = {x=WIDTH+(PIPE_HOZWIDTH/2),y=HEIGHT/2,counted=false}
        newPipe.y = math.random(5,HEIGHT-7)
        if not justStarted and not gameOver and not paused then
            table.insert(pipes,newPipe)
        end
    end
end

function collision()
    for i,v in ipairs(pipes) do
        if playerX >= v.x and playerX <= v.x+PIPE_HOZWIDTH then
            if playerY >= v.y + PIPE_WIDTH or playerY <= v.y - PIPE_WIDTH+1 then
                if not gameOver then onGameOver() end
            end
            if not v.counted then
                score = score + 1 
                v.counted = true
            end
        end
        if dbg then
            paintutils.drawBox(v.x,v.y+PIPE_WIDTH,v.x+PIPE_HOZWIDTH,HEIGHT)
            paintutils.drawBox(v.x,v.y-PIPE_WIDTH,v.x+PIPE_HOZWIDTH,0)
        end
    end
end

function inputMouse()
    while gameRunning do
        local event, button, x, y = os.pullEvent("mouse_click")
        if event == "mouse_click" then
            if not paused and not gameOver then
                playerVelocity = JUMP_STRENGTH*-1
            end
            justStarted = false
            if gameOver and canReset then
                reset()
            end
            if dbg then
                paintutils.drawPixel(x,y,colors.white)
            end
        end
    end
end

function inputKeyboard()
    while gameRunning do
        local event, key, isHeld = os.pullEvent("key")
        
        -- ВЫХОД НА Q
        if key == keys.q then
            gameRunning = false
            term.clear()
            term.setCursorPos(1,1)
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.black)
            print("Thanks for playing Flappy Block!")
            sleep(1)
            term.clear()
            break
        end
        
        if tablehas(ALLOWED_KEYS,key) and not isHeld then
            if not paused and not gameOver then
                playerVelocity = JUMP_STRENGTH*-1
            end
            justStarted = false
            if gameOver and canReset then
                reset()
            end
        end
    end
end

function physics()
    for i,v in ipairs(pipes) do
        if not gameOver then
            v.x = v.x - PIPE_SPEED
        end
        if v.x < PIPE_HOZWIDTH*-1 then
            table.remove(pipes,i)
        end
    end
    playerVelocity = playerVelocity + GRAVITY
    playerY = playerY + playerVelocity
    if playerY > HEIGHT-3 then
        playerY = HEIGHT-3
        playerVelocity = GRAVITY * -1
        onGameOver()
    end
    if playerVelocity > VELOCITY_MAX then
        playerVelocity = VELOCITY_MAX
    end
end

function update()
    while gameRunning do
        if justStarted and playerY > HEIGHT/2+2 then
            playerVelocity = JUMP_STRENGTH*-1
        end
        if not paused then physics() end
        if not dbg then collision() end
        drawBG()
        drawPipes()
        drawPlayer()
        drawGround()
        drawText()
        if dbg then collision() end

        if gameOver and not canReset then
            gameOverTimer = gameOverTimer - (1/20)
            if gameOverTimer < 0 then
                canReset = true
            end
        end

        sleep(1/20)
    end    
end

-- Запуск игры
parallel.waitForAny(update, inputMouse, inputKeyboard, pipeCreator)

-- name: Music Player
-- icon: [MUS]
-- vers: [1.0]

-- music.app
-- Simple music player for Lubinty OS with speaker support

local term = term
local colors = colors
local fs = fs
local os = os
local keys = keys
local peripheral = peripheral

-- ========== GLOBALS ==========

local speaker = nil
local speakerSide = nil
local isPlaying = false
local currentNote = nil
local currentOctave = 4
local currentDuration = 0.5
local volume = 1.0
local melody = {}
local melodyIndex = 1
local melodyPlaying = false
local melodyTimer = nil

local w, h = 0, 0
local mode = "notes" -- notes, melody, compose
local composeText = ""
local selectedNote = "C"
local selectedOctave = 4
local selectedDuration = 0.5

local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local durations = {0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 1.0, 1.5, 2.0}
local durationNames = {"1/10","1/5","1/4","1/3","2/5","1/2","3/5","3/4","1","1.5","2"}

local frequencyMap = {
    C = 261.63, C_ = 277.18, D = 293.66, D_ = 311.13, E = 329.63, F = 349.23,
    F_ = 369.99, G = 392.00, G_ = 415.30, A = 440.00, A_ = 466.16, B = 493.88
}

-- ========== COLORS ==========

local colors_music = {
    bg = colors.black,
    fg = colors.white,
    header = colors.cyan,
    selected = colors.blue,
    playing = colors.green,
    accent = colors.lime,
    border = colors.gray,
    note = colors.yellow
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
        writeAt(" " .. title .. " ", x1 + 2, y1, border, colors_music.header)
    end
end

-- ========== SPEAKER DETECTION ==========

local function findSpeaker()
    local sides = {"left", "right", "back", "front", "top", "bottom"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "speaker" then
            speakerSide = side
            speaker = peripheral.wrap(side)
            return true
        end
    end
    local devices = peripheral.getNames()
    for _, name in ipairs(devices) do
        if peripheral.getType(name) == "speaker" then
            speakerSide = name
            speaker = peripheral.wrap(name)
            return true
        end
    end
    return false
end

local function playTone(freq, duration)
    if not speaker then return false end
    speaker.playTone(freq, duration)
    return true
end

local function getFrequency(note, octave)
    local baseFreq = frequencyMap[note]
    if not baseFreq then return 440 end
    return baseFreq * (2 ^ (octave - 4))
end

-- ========== NOTE PLAYING ==========

local function playSelectedNote()
    local freq = getFrequency(selectedNote, selectedOctave)
    playTone(freq, currentDuration)
end

local function playMelody()
    if melodyPlaying then return end
    melodyPlaying = true
    melodyIndex = 1
    
    local function playNext()
        if not melodyPlaying or melodyIndex > #melody then
            melodyPlaying = false
            return
        end
        local note = melody[melodyIndex]
        local freq = getFrequency(note.note, note.octave)
        playTone(freq, note.duration)
        melodyIndex = melodyIndex + 1
        melodyTimer = os.startTimer(note.duration)
    end
    
    playNext()
end

local function stopMelody()
    melodyPlaying = false
    if melodyTimer then
        os.cancelTimer(melodyTimer)
        melodyTimer = nil
    end
end

local function addToMelody()
    table.insert(melody, {
        note = selectedNote,
        octave = selectedOctave,
        duration = selectedDuration
    })
end

local function clearMelody()
    melody = {}
    melodyIndex = 1
    stopMelody()
end

-- ========== PARSE COMPOSE TEXT ==========

local function parseCompose()
    local notesList = {}
    for token in composeText:gmatch("%S+") do
        local note = token:sub(1,1)
        local octave = 4
        local duration = 0.5
        
        if token:match("^[CDEFGAB][#b]?%d+") then
            note = token:sub(1,1)
            local rest = token:sub(2)
            if rest:sub(1,1) == "#" or rest:sub(1,1) == "b" then
                note = note .. rest:sub(1,1)
                rest = rest:sub(2)
            end
            octave = tonumber(rest:match("%d+")) or 4
            duration = 0.5
        elseif token:match("^[CDEFGAB][#b]?$") then
            note = token
            octave = 4
            duration = 0.5
        end
        
        if note == "R" then
            notesList[#notesList + 1] = {note = "C", octave = 4, duration = 0.5, rest = true}
        else
            notesList[#notesList + 1] = {note = note, octave = octave, duration = duration}
        end
    end
    return notesList
end

local function playCompose()
    local notesList = parseCompose()
    if #notesList == 0 then return end
    
    stopMelody()
    melody = notesList
    melodyPlaying = true
    melodyIndex = 1
    
    local function playNext()
        if not melodyPlaying or melodyIndex > #melody then
            melodyPlaying = false
            return
        end
        local note = melody[melodyIndex]
        if not note.rest then
            local freq = getFrequency(note.note, note.octave)
            playTone(freq, note.duration)
        end
        melodyIndex = melodyIndex + 1
        melodyTimer = os.startTimer(note.duration)
    end
    
    playNext()
end

-- ========== DRAW UI ==========

local function drawNoteMode()
    drawBox(2, 2, w - 2, h - 2, colors_music.bg, colors_music.border, " MUSIC PLAYER ")
    
    writeAt("SPEAKER: " .. (speakerSide and speakerSide:upper() or "NOT FOUND"), 4, 4, colors_music.bg, speaker and colors_music.playing or colors_music.selected)
    
    writeAt("NOTE:", 4, 6, colors_music.bg, colors_music.header)
    local noteX = 12
    for i, n in ipairs(notes) do
        local bg = (selectedNote == n) and colors_music.selected or colors_music.bg
        writeAt(n, noteX + (i-1)*4, 6, bg, colors_music.fg)
    end
    
    writeAt("OCTAVE:", 4, 8, colors_music.bg, colors_music.header)
    for i = 1, 6 do
        local bg = (selectedOctave == i) and colors_music.selected or colors_music.bg
        writeAt(" " .. i .. " ", 14 + (i-1)*4, 8, bg, colors_music.fg)
    end
    
    writeAt("DURATION:", 4, 10, colors_music.bg, colors_music.header)
    for i, d in ipairs(durations) do
        local bg = (selectedDuration == d) and colors_music.selected or colors_music.bg
        writeAt(" " .. durationNames[i] .. " ", 14 + (i-1)*6, 10, bg, colors_music.fg)
        if i == 6 then break end
    end
    
    writeAt("VOLUME: " .. string.rep("█", volume*10) .. string.rep("░", 10-volume*10), 4, 12, colors_music.bg, colors_music.accent)
    
    writeAt("[SPACE] Play Note  [M] Melody Mode  [C] Compose Mode  [+/-] Volume  [Q] Exit", 4, h - 2, colors_music.bg, colors_music.header)
end

local function drawMelodyMode()
    drawBox(2, 2, w - 2, h - 2, colors_music.bg, colors_music.border, " MELODY EDITOR ")
    
    writeAt("MELODY (" .. #melody .. " notes)", 4, 4, colors_music.bg, colors_music.header)
    
    local melodyStr = ""
    for i, m in ipairs(melody) do
        if i > 20 then
            melodyStr = melodyStr .. "..."
            break
        end
        melodyStr = melodyStr .. m.note .. m.octave .. " "
    end
    writeAt(melodyStr, 4, 6, colors_music.bg, colors_music.note)
    
    writeAt("NOTE: " .. selectedNote, 4, 8, colors_music.bg, colors_music.header)
    writeAt("OCTAVE: " .. selectedOctave, 4, 9, colors_music.bg, colors_music.header)
    writeAt("DURATION: " .. selectedDuration .. "s", 4, 10, colors_music.bg, colors_music.header)
    
    local status = melodyPlaying and "PLAYING" or "STOPPED"
    writeAt("STATUS: " .. status, 4, 12, colors_music.bg, melodyPlaying and colors_music.playing or colors_music.fg)
    
    writeAt("[SPACE] Play Note  [A] Add to Melody  [P] Play Melody  [S] Stop  [C] Clear", 4, h - 3, colors_music.bg, colors_music.header)
    writeAt("[N] Note Mode  [V] Compose Mode  [+/-] Volume  [Q] Exit", 4, h - 2, colors_music.bg, colors_music.header)
end

local function drawComposeMode()
    drawBox(2, 2, w - 2, h - 2, colors_music.bg, colors_music.border, " COMPOSE MODE ")
    
    writeAt("Enter notes (C4 D4 E4 F4 G4 A4 B4 R for rest):", 4, 4, colors_music.bg, colors_music.header)
    
    local displayText = composeText
    if #displayText > 40 then displayText = displayText:sub(1, 37) .. "..." end
    writeAt("> " .. displayText .. "_", 4, 6, colors_music.bg, colors_music.accent)
    
    writeAt("Examples:", 4, 8, colors_music.bg, colors_music.header)
    writeAt("  C4 D4 E4 F4 G4 A4 B4 C5 - Happy Birthday intro", 4, 9, colors_music.bg, colors_music.fg)
    writeAt("  C4 E4 G4 - C major chord", 4, 10, colors_music.bg, colors_music.fg)
    writeAt("  A4 A4 E4 E4 F4 F4 E4 - Beethoven Fur Elise", 4, 11, colors_music.bg, colors_music.fg)
    
    writeAt("[ENTER] Play  [C] Clear  [N] Note Mode  [M] Melody Mode  [Q] Exit", 4, h - 2, colors_music.bg, colors_music.header)
end

local function drawNoSpeaker()
    term.clear()
    term.setBackgroundColor(colors_music.bg)
    centerText("╔════════════════════════════════════════╗", 5, colors_music.bg, colors_music.selected)
    centerText("║         NO SPEAKER FOUND!             ║", 6, colors_music.bg, colors_music.selected)
    centerText("╚════════════════════════════════════════╝", 7, colors_music.bg, colors_music.selected)
    centerText("Please attach a speaker to your computer", 9, colors_music.bg, colors_music.fg)
    centerText("and run: attach left speaker", 11, colors_music.bg, colors_music.fg)
    centerText("Press Q to exit", 13, colors_music.bg, colors_music.header)
end

-- ========== MAIN ==========

local function main()
    getSize()
    
    if not findSpeaker() then
        while true do
            drawNoSpeaker()
            local event, key = os.pullEvent("key")
            if key == keys.q then break end
            if key == keys.r then
                if findSpeaker() then break end
            end
        end
        if not speaker then
            term.clear()
            return
        end
    end
    
    term.clear()
    term.setCursorBlink(false)
    
    while true do
        if mode == "notes" then
            drawNoteMode()
        elseif mode == "melody" then
            drawMelodyMode()
        elseif mode == "compose" then
            drawComposeMode()
        end
        
        local event, p1, p2, p3 = os.pullEvent()
        
        if event == "timer" and p1 == melodyTimer then
            if melodyPlaying then
                if melodyIndex <= #melody then
                    local note = melody[melodyIndex]
                    if not note.rest then
                        local freq = getFrequency(note.note, note.octave)
                        playTone(freq, note.duration)
                    end
                    melodyIndex = melodyIndex + 1
                    melodyTimer = os.startTimer(melody[melodyIndex - 1].duration)
                else
                    melodyPlaying = false
                    melodyTimer = nil
                end
            end
            continue
        end
        
        if event == "key" then
            local key = p1
            
            if key == keys.q then
                break
                
            elseif mode == "notes" then
                if key == keys.space then
                    playSelectedNote()
                elseif key == keys.m then
                    mode = "melody"
                elseif key == keys.c then
                    mode = "compose"
                elseif key == keys.equals or key == keys.add then
                    volume = math.min(1.5, volume + 0.1)
                elseif key == keys.minus then
                    volume = math.max(0, volume - 0.1)
                elseif key == keys.up then
                    selectedOctave = math.min(6, selectedOctave + 1)
                elseif key == keys.down then
                    selectedOctave = math.max(1, selectedOctave - 1)
                elseif key == keys.left then
                    for i = 1, #notes do
                        if notes[i] == selectedNote then
                            local newIndex = i - 1
                            if newIndex < 1 then newIndex = #notes end
                            selectedNote = notes[newIndex]
                            break
                        end
                    end
                elseif key == keys.right then
                    for i = 1, #notes do
                        if notes[i] == selectedNote then
                            local newIndex = i + 1
                            if newIndex > #notes then newIndex = 1 end
                            selectedNote = notes[newIndex]
                            break
                        end
                    end
                end
                
            elseif mode == "melody" then
                if key == keys.space then
                    playSelectedNote()
                elseif key == keys.a then
                    addToMelody()
                elseif key == keys.p then
                    playMelody()
                elseif key == keys.s then
                    stopMelody()
                elseif key == keys.c then
                    clearMelody()
                elseif key == keys.n then
                    mode = "notes"
                elseif key == keys.v then
                    mode = "compose"
                elseif key == keys.equals or key == keys.add then
                    volume = math.min(1.5, volume + 0.1)
                elseif key == keys.minus then
                    volume = math.max(0, volume - 0.1)
                elseif key == keys.up then
                    selectedOctave = math.min(6, selectedOctave + 1)
                elseif key == keys.down then
                    selectedOctave = math.max(1, selectedOctave - 1)
                elseif key == keys.left then
                    for i = 1, #notes do
                        if notes[i] == selectedNote then
                            local newIndex = i - 1
                            if newIndex < 1 then newIndex = #notes end
                            selectedNote = notes[newIndex]
                            break
                        end
                    end
                elseif key == keys.right then
                    for i = 1, #notes do
                        if notes[i] == selectedNote then
                            local newIndex = i + 1
                            if newIndex > #notes then newIndex = 1 end
                            selectedNote = notes[newIndex]
                            break
                        end
                    end
                end
                
            elseif mode == "compose" then
                if key == keys.enter then
                    playCompose()
                elseif key == keys.c then
                    composeText = ""
                elseif key == keys.n then
                    mode = "notes"
                elseif key == keys.m then
                    mode = "melody"
                elseif key == keys.backspace then
                    composeText = composeText:sub(1, -2)
                else
                    local char = keys.getName(key)
                    if char and #char == 1 and char:match("[CDEFGABRcd efgabr12345678#b]") then
                        composeText = composeText .. char
                    end
                end
            end
        end
    end
    
    stopMelody()
    term.clear()
    term.setCursorPos(1, 1)
    print("Music Player closed.")
    sleep(1)
    term.clear()
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("Music Player error: " .. tostring(err))
    print("Press any key to close...")
    os.pullEvent("key")
end

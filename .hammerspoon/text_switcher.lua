local M = {}
local eventtap = require("hs.eventtap")
local timer = require("hs.timer")
local keycodes = require("hs.keycodes")
local event = eventtap.event

-- Configuration
local OPTION_MIN_TIMEOUT = 0.4 -- Minimum time (seconds) to hold Option for trigger
local OPTION_MAX_TIMEOUT = 0.8 -- Maximum time (seconds) to hold Option for trigger

-- Layout Strings (Use [[]] for raw strings to handle backslashes and quotes easier)
-- Standard QWERTY
local en_layout = [[`1234567890-=qwertyuiop[]\asdfghjkl;'zxcvbnm,./~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?]]
-- Standard Russian (PC/Windows compatible usually works best for Mac layout matching too on chars)
local ru_layout = [[ё1234567890-=йцукенгшщзхъ\фывапролджэячсмитьбю.Ё!"№;%:?*()_+ЙЦУКЕНГШЩЗХЪ/ФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,]]

-- Helper: Split utf8 string to table
local function to_table(str)
    local t = {}
    for char in str:gmatch(utf8.charpattern) do
        table.insert(t, char)
    end
    return t
end

local en_chars = to_table(en_layout)
local ru_chars = to_table(ru_layout)

local en2ru = {}
local ru2en = {}

-- Build mapping tables
for i = 1, #en_chars do
    local e = en_chars[i]
    local r = ru_chars[i]
    if e and r then
        en2ru[e] = r
        ru2en[r] = e
    end
end

-- Detect dominant language
local function is_russian(text)
    local ru_count = 0
    local en_count = 0
    for char in text:gmatch(utf8.charpattern) do
        if ru2en[char] and not en2ru[char] then -- Unique to RU (simplification, fails for shared punctuation)
             ru_count = ru_count + 1
        elseif char:match("[а-яА-ЯёЁ]") then
             ru_count = ru_count + 1
        elseif char:match("[a-zA-Z]") then
             en_count = en_count + 1
        end
    end
    return ru_count > en_count
end

function M.convert_text(text)
    if not text or text == "" then return text end
    
    local is_ru = is_russian(text)
    local map = is_ru and ru2en or en2ru
    
    local result = {}
    for char in text:gmatch(utf8.charpattern) do
        table.insert(result, map[char] or char)
    end
    return table.concat(result)
end

function M.cycle_selection()
    -- Preserve original clipboard content to restore later
    local old_clipboard = hs.pasteboard.getContents()
    -- Get current change count to detect if a copy actually happens
    local initial_count = hs.pasteboard.changeCount()
    
    -- Copy selection
    hs.eventtap.keyStroke({"cmd"}, "c")
    
    -- Wait a bit for clipboard to update
    hs.timer.doAfter(0.05, function()
        local current_count = hs.pasteboard.changeCount()
        
        -- Only proceed if the clipboard actually changed (something was copied)
        -- If not changed, we assume no text was selected, so we exit without "touching" the buffer further
        if current_count > initial_count then
            local selected_text = hs.pasteboard.getContents()
            
            if selected_text and selected_text ~= "" then
                local converted = M.convert_text(selected_text)
                if converted ~= selected_text then
                    hs.pasteboard.setContents(converted)
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    
                    -- Restore original clipboard (delayed to allow paste)
                    hs.timer.doAfter(0.2, function()
                         if old_clipboard then
                             hs.pasteboard.setContents(old_clipboard)
                         end
                    end)
                    return
                end
            end
            
            -- If we land here, we copied text but didn't convert/paste.
            -- We must restore the user's original clipboard immediately since we overwrote it.
            if old_clipboard then
                hs.pasteboard.setContents(old_clipboard)
            end
        end
    end)
end

-- Event Tap Logic
local flags_watcher = nil
local key_watcher = nil
local option_start_time = 0
local tracking_option = false
local invalid_press = false

local function stop_tracking()
    tracking_option = false
    invalid_press = false
end

local function on_flags_changed(evt)
    local flags = evt:getFlags()
    
    -- Check if ONLY alt is pressed
    -- getFlags returns table like {alt=true, cmd=true}
    -- We want only alt=true and nothing else.
    
    local only_alt = flags.alt and not (flags.cmd or flags.ctrl or flags.shift or flags.fn)
    
    if only_alt and not tracking_option then
        -- Option pressed down
        tracking_option = true
        option_start_time = timer.secondsSinceEpoch()
        invalid_press = false
    elseif not flags.alt and tracking_option then
        -- Option released
        local duration = timer.secondsSinceEpoch() - option_start_time
        if not invalid_press and duration >= OPTION_MIN_TIMEOUT and duration <= OPTION_MAX_TIMEOUT then
            M.cycle_selection()
        end
        stop_tracking()
    elseif tracking_option and not only_alt then
        -- User added another modifier (e.g. Alt+Cmd)
        invalid_press = true
    end
    
    return false
end

local function on_key_down(evt)
    if tracking_option then
        invalid_press = true
    end
    return false
end

function M.start()
    flags_watcher = eventtap.new({event.types.flagsChanged}, on_flags_changed)
    key_watcher = eventtap.new({event.types.keyDown}, on_key_down)
    flags_watcher:start()
    key_watcher:start()
end

function M.stop()
    if flags_watcher then flags_watcher:stop() end
    if key_watcher then key_watcher:stop() end
end

return M


local obj = {}
obj.__index = obj

-- Metadata
obj.name = "SpeechToText"
obj.version = "1.0"
obj.author = "Onetiger"
obj.license = "MIT"

-- Configuration
obj.apiKey = nil
obj.language = nil -- "uk" or nil (auto/en)

-- Internal Storage for Watchers/Taps to prevent GC
obj.receivers = {}

-- Constants
local home = os.getenv("HOME")
local recBin  = home .. "/coreaudio-rec/ptt_rec"
local ffmpeg  = "/usr/local/bin/ffmpeg"
local curlBin = "/usr/bin/curl"
local wavFile  = "/tmp/voice.wav"
local opusFile = "/tmp/voice.opus"
local halFile  = home .. "/projects/n8n/speech-to-text/hammerspoon/hallucinations.txt"

-- Default prompts for Whisper (used to set Language/Context bias)
local PROMPT_UK = "Ну, е-е-е, коротше, ось так. Умм, mhm, okay, well. Це текст з правильною пунктуацією."
local PROMPT_MIXED = "Ну, эээ, шо, короче, вот так. Umm, hmm, well, you know, like. This text can be both English and Russian with proper punctuation."
-- local PROMPT_MIXED = "Umm, hmm, well, you know, like. Ну, эээ, шо, короче, вот так. Это текст с правильной пунктуацией."
-- local PROMPT_MIXED = "This is a raw transcription that must preserve ALL spoken words including filler words, hesitations, and dysfluencies. Keep words like: umm, hmm, mm, mhm, uh, um, ah, ehm, well, like, you know. It might be English text. Это может быть русский текст. Add proper punctuation. Never remove any words. Mix of Russian and English is possible and expected. Сохраняй, блядь, язык ввода. Не вздумай ничего не переводить, дебил, блядь."

-- State
local recTask, encTask, sendTask = nil, nil, nil
local recording = false
local fnDown = false
local recStartTime = 0

-- Target Application/Window for Pasting
local targetApp = nil
local targetWin = nil

-- Helper Functions
local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function extractText(resp)
  resp = trim(resp)
  if resp == "" then return "" end

  local first = resp:sub(1,1)
  if first ~= "{" and first ~= "[" then
    return resp
  end

  local ok, jsonObj = pcall(hs.json.decode, resp)
  if not ok or jsonObj == nil then
    return resp
  end
  if type(jsonObj) == "table" and jsonObj[1] and type(jsonObj[1]) == "table" then
    if jsonObj[1].data ~= nil then return tostring(jsonObj[1].data) end
    if jsonObj[1].text ~= nil then return tostring(jsonObj[1].text) end
  end
  if type(jsonObj) == "table" then
    if jsonObj.data ~= nil and type(jsonObj.data) ~= "table" then return tostring(jsonObj.data) end
    if jsonObj.text ~= nil then return tostring(jsonObj.text) end
    if type(jsonObj.data) == "table" and jsonObj.data.text ~= nil then return tostring(jsonObj.data.text) end
  end
  return resp
end

local function focusTarget()
  if targetWin and targetWin.focus then
    targetWin:focus()
    return
  end
  if targetApp and targetApp.activate then
    targetApp:activate()
  end
end

local hallucinationsList = {}

local function loadHallucinations()
  local f = io.open(halFile, "r")
  if f then
    for line in f:lines() do
      line = trim(line)
      if #line > 0 then
        table.insert(hallucinationsList, line:lower())
      end
    end
    f:close()
  end
end
loadHallucinations()

local function removeHallucinations(text)
  local changed = true
  while changed do
    changed = false
    local lowStr = text:lower()
    for _, hal in ipairs(hallucinationsList) do
      local startIdx, endIdx = lowStr:find(hal, 1, true)
      if startIdx then
        local prefix = text:sub(1, startIdx - 1)
        local isAtStart = prefix:match("^[%s%p]*$") ~= nil
        local suffix = text:sub(endIdx + 1)
        local isAtEnd = suffix:match("^[%s%p]*$") ~= nil
        
        if isAtStart then
            text = text:sub(endIdx + 1)
            text = text:gsub("^[%s%p]+", "")
            changed = true
            break
        elseif isAtEnd then
            text = text:sub(1, startIdx - 1)
            text = text:gsub("[%s,;%-]+$", "")
            changed = true
            break
        end
      end
    end
  end
  text = trim(text)
  if #text < 2 then return "" end
  return text
end

local function pasteWithRestore(text)
  text = trim(text)
  if text == "" then return end

  -- Remove combining breve character (U+0306) to prevent hallucinated chars like 'й̆' or 'я̆'
  text = text:gsub("\xcc\x86", "")

  local originalText = text
  text = removeHallucinations(text)
  
  if text == "" then
    print("Ignored hallucination: " .. originalText)
    return
  end

  -- Add a space after the text
  text = text .. " "

  focusTarget()
  local old = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v", 0)
  hs.timer.doAfter(0.25, function()
    if old ~= nil then hs.pasteboard.setContents(old) end
  end)
end

local function getPrompt(lang)
  if lang == "uk" then
        return PROMPT_UK
  else
        return PROMPT_MIXED
  end
end

local function encodeAndSend()
  hs.timer.doAfter(0.10, function()
    os.remove(opusFile)
    encTask = hs.task.new(ffmpeg, function(code, out, err)
      encTask = nil
      if code ~= 0 then
        hs.alert.show("Encode failed")
        return
      end

      -- Send to Groq API directly
      local lang = obj.language
      local model = (lang == "uk") and "whisper-large-v3" or "whisper-large-v3"
      local prompt = getPrompt(lang)
      
      if not obj.apiKey then
        hs.alert.show("API Key missing")
        return
      end

      local args = {
        "-sS", "-f", "-X", "POST",
        "https://api.groq.com/openai/v1/audio/transcriptions",
        "-H", "Authorization: Bearer " .. obj.apiKey,
        "-F", "file=@" .. opusFile .. ";type=audio/opus",
        "-F", "model=" .. model,
        "-F", "response_format=text",
        "-F", "prompt=" .. prompt
      }

      if lang == "uk" then
        table.insert(args, "-F")
        table.insert(args, "language=uk")
      else
        table.insert(args, "-F")
        table.insert(args, "temperature=0")
      end

      sendTask = hs.task.new(curlBin, function(code2, out2, err2)
        sendTask = nil
        if code2 ~= 0 then
          hs.alert.show("Transcription failed")
          print("Groq API error: " .. err2)
          return
        end
        local text = extractText(out2)
        pasteWithRestore(text)
      end, args)
      sendTask:start()
    end, {
      "-y", "-i", wavFile, "-vn", "-ac", "1", "-ar", "16000",
      "-c:a", "libopus", "-b:a", "16k", "-application", "voip", opusFile
    })
    encTask:start()
  end)
end

function obj:startRecording()
  if recording then return end
  if recTask or encTask or sendTask then
    print("Tasks busy, skipping")
    return
  end

  recording = true
  recStartTime = hs.timer.secondsSinceEpoch()

  -- Check for Ukrainian toggle (Fn + Shift)
  local mods = hs.eventtap.checkKeyboardModifiers()
  if mods.shift then
    obj.language = "uk"
  else
    obj.language = nil
  end

  targetApp = hs.application.frontmostApplication()
  targetWin = hs.window.frontmostWindow()

  os.remove(wavFile)
  recTask = hs.task.new(recBin, function()
    recTask = nil
  end, {"--out", wavFile})

  recTask:start()
  if obj.language == "uk" then
    hs.alert.show("Listening (UK)...")
  else
    hs.alert.show("Listening...")
  end
end

function obj:stopRecording(shouldProcess)
  if not recording then return end
  recording = false
  local duration = hs.timer.secondsSinceEpoch() - recStartTime

  if recTask then
    recTask:terminate()
    recTask = nil
  end

  if not shouldProcess then
    hs.alert.show("Cancelled")
    return
  end

  if duration < 0.6 then
    hs.alert.show(string.format("Too short (%.1fs < 0.6s)", duration))
    return
  end

  hs.alert.show(string.format("Processing (%.1fs)...", duration))
  encodeAndSend()
end

-- Event Handling Definitions
local function onActivity()
  if obj.delayTimer then
    obj.delayTimer:stop()
    obj.delayTimer = nil
  end
  if recording then
    obj:stopRecording(false) -- discard
  end
end

local function onFlagsChanged(e)
  local flags = e:getFlags()
  local isFn = flags.fn

  if isFn and not fnDown then
    fnDown = true
    obj.delayTimer = hs.timer.doAfter(0.3, function()
      obj.delayTimer = nil
      obj:startRecording()
    end)
  elseif (not isFn) and fnDown then
    fnDown = false
    if obj.delayTimer then
      obj.delayTimer:stop()
      obj.delayTimer = nil
    elseif recording then
      obj:stopRecording(true)
    end
  end
end

function obj:restartTaps()
  print("[PTT] Refreshing EventTaps...")
  if obj.receivers.modTap then obj.receivers.modTap:stop() end
  if obj.receivers.activityTap then obj.receivers.activityTap:stop() end

  obj.receivers.modTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
    onFlagsChanged(e)
    return false
  end)

  obj.receivers.activityTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.otherMouseDown,
    hs.eventtap.event.types.scrollWheel
  }, function(e)
    onActivity()
    return false
  end)
  
  obj.receivers.modTap:start()
  obj.receivers.activityTap:start()
  print("[PTT] EventTaps (re)started.")
end

function obj:start()
  print("[PTT] Starting SpeechToText module...")
  
  -- Cleanup existing if needed
  if obj.receivers.modTap then obj.receivers.modTap:stop() end
  if obj.receivers.activityTap then obj.receivers.activityTap:stop() end
  if obj.receivers.caffeinateWatcher then obj.receivers.caffeinateWatcher:stop() end
  if obj.receivers.healthCheckTimer then obj.receivers.healthCheckTimer:stop() end

  -- Initial taps start
  obj:restartTaps()

  -- Caffeinate Watcher (Restart taps on wake)
  obj.receivers.caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidUnlock or
       event == hs.caffeinate.watcher.systemDidWake then
      print("[PTT] Wake event detected.")
      hs.timer.doAfter(1.0, function() obj:restartTaps() end)
    end
  end)
  obj.receivers.caffeinateWatcher:start()

  -- Watchdog (Health Check)
  obj.receivers.healthCheckTimer = hs.timer.doEvery(30, function()
     if (not obj.receivers.modTap) or (not obj.receivers.modTap:isEnabled()) then
       print("[PTT] Watchdog: modTap died! Restarting...")
       obj:restartTaps()
     elseif (not obj.receivers.activityTap) or (not obj.receivers.activityTap:isEnabled()) then
       print("[PTT] Watchdog: activityTap died! Restarting...")
       obj:restartTaps()
     end
  end)

  print("[PTT] SpeechToText module started.")
end

return obj


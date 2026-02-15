-- PTT Fn key (Delayed) -> record -> encode -> transcribe with Groq -> paste
-- Features:
-- 1. Anti-Hallucination (Empty/Garbage filter)
-- 2. Multi-language Prompt (EN/RU/UK)
-- 3. Robust EventTap Watchdog with Global Persistence
-- 4. Direct Groq API integration (no HTTP server, no Python needed)

-- ====== CONFIGURATION ======
local GROQ_API_KEY = "YOUR_GROQ_API_KEY_HERE"  -- Put your Groq API key here
-- ===========================

-- GLOBAL TABLE to prevent Garbage Collection (The #1 cause of "stopping after a while")
_G.pttVoice = _G.pttVoice or {}

local home = os.getenv("HOME")
local recBin  = "/usr/local/bin/sox"
local ffmpeg  = "/usr/local/bin/ffmpeg"
local curlBin = "/usr/bin/curl"

local wavFile  = "/tmp/voice.wav"
local opusFile = "/tmp/voice.opus"

local recTask, encTask, sendTask = nil, nil, nil
local recording = false
local fnDown = false

-- Remember where to paste
local targetApp = nil
local targetWin = nil

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

  local ok, obj = pcall(hs.json.decode, resp)
  if not ok or obj == nil then
    return resp
  end
  if type(obj) == "table" and obj[1] and type(obj[1]) == "table" then
    if obj[1].data ~= nil then return tostring(obj[1].data) end
    if obj[1].text ~= nil then return tostring(obj[1].text) end
  end
  if type(obj) == "table" then
    if obj.data ~= nil and type(obj.data) ~= "table" then return tostring(obj.data) end
    if obj.text ~= nil then return tostring(obj.text) end
    if type(obj.data) == "table" and obj.data.text ~= nil then return tostring(obj.data.text) end
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

local function pasteWithRestore(text)
  text = trim(text)
  if text == "" then return end

  -- Anti-Hallucination Filter
  local lowText = text:lower():gsub("[%s%p]", "") -- remove spaces/punctuation
  local hallucinations = {
    ["subtitlesbytheamaraorgcommunity"] = true,
    ["здаєтьсясистемныйконфигподтянулсякорректно"] = true,
    ["Этоможетбытьрусскийтекст"] = true,
    ["Субтитрысоздавалdimatorzok"] = true,
    ["thankyouforwatching"] = true,
    ["thanksforwatching"] = true,
    ["Продолжениеследует"] = true,
    ["Дякуюзаперегляд"] = true,
    ["Сохраняй"] = true,
    ["Дякую"] = true,
    ["thankyou"] = true,
    ["yes"] = true,
    ["you"] = true,
    ["bye"] = true,
    ["subscribetomychannel"] = true,
    ["подпишитесь"] = true
  }

  if hallucinations[lowText] or #text < 2 then
    print("Ignored hallucination: " .. text)
    return
  end

  -- Add a space after the text to separate it from the next dictation
  text = text .. " "

  focusTarget()
  local old = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v", 0)
  hs.timer.doAfter(0.25, function()
    if old ~= nil then hs.pasteboard.setContents(old) end
  end)
end

local function getPrompt(language)
  if language == "uk" then
    return "It might be English text. Це може бути український текст."
  else
    return "This is a raw transcription that must preserve ALL spoken words including filler words, hesitations, and dysfluencies. Keep words like: umm, hmm, mm, mhm, uh, um, ah, ehm, well, like, you know. It might be English text. Это может быть русский текст. Add proper punctuation. Never remove any words. Mix of Russian and English is possible and expected. Сохраняй, блядь, язык ввода. Не вздумай ничего не переводить, дебил, блядь. Сохраняй слова в том виде, в котором я отдал. Не вздумай ничего менять или вырезать. Дебил, блядь."
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
      local language = _G.pttVoice.language
      local model = (language == "uk") and "whisper-large-v3" or "whisper-large-v3-turbo"
      local prompt = getPrompt(language)
      
      local args = {
        "-sS", "-f", "-X", "POST",
        "https://api.groq.com/openai/v1/audio/transcriptions",
        "-H", "Authorization: Bearer " .. GROQ_API_KEY,
        "-F", "file=@" .. opusFile .. ";type=audio/opus",
        "-F", "model=" .. model,
        "-F", "response_format=text",
        "-F", "prompt=" .. prompt
      }
      
      -- Add language or temperature parameter
      if language == "uk" then
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

local recStartTime = 0

local function startRecording()
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
    _G.pttVoice.language = "uk"
  else
    _G.pttVoice.language = nil
  end

  targetApp = hs.application.frontmostApplication()
  targetWin = hs.window.frontmostWindow()

  os.remove(wavFile)
  recTask = hs.task.new(recBin, function()
    recTask = nil
  end, {"-d", wavFile})
  
  recTask:start()
  if _G.pttVoice.language == "uk" then
    hs.alert.show("Listening (UK)...")
  else
    hs.alert.show("Listening...")
  end
end

local function stopRecording(shouldProcess)
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

local function onActivity()
  if _G.pttVoice.delayTimer then
    _G.pttVoice.delayTimer:stop()
    _G.pttVoice.delayTimer = nil
  end
  if recording then
    stopRecording(false) -- discard
  end
end

local function onFlagsChanged(e)
  local flags = e:getFlags()
  local isFn = flags.fn

  if isFn and not fnDown then
    fnDown = true
    _G.pttVoice.delayTimer = hs.timer.doAfter(0.3, function()
      _G.pttVoice.delayTimer = nil
      startRecording()
    end)
  elseif (not isFn) and fnDown then
    fnDown = false
    if _G.pttVoice.delayTimer then
      _G.pttVoice.delayTimer:stop()
      _G.pttVoice.delayTimer = nil
    elseif recording then
      stopRecording(true)
    end
  end
end

-- Robust Restart Function
local function restartTaps()
  print("[PTT] Refreshing EventTaps...")
  if _G.pttVoice.modTap then _G.pttVoice.modTap:stop() end
  if _G.pttVoice.activityTap then _G.pttVoice.activityTap:stop() end
  
  -- Create global instances
  _G.pttVoice.modTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
    onFlagsChanged(e)
    return false
  end)
  
  _G.pttVoice.activityTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.otherMouseDown,
    hs.eventtap.event.types.scrollWheel
  }, function(e)
    onActivity()
    return false
  end)

  _G.pttVoice.modTap:start()
  _G.pttVoice.activityTap:start()
  print("[PTT] EventTaps (re)started.")
end

-- Watchers
if _G.pttVoice.caffeinateWatcher then _G.pttVoice.caffeinateWatcher:stop() end
_G.pttVoice.caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
  if event == hs.caffeinate.watcher.screensDidUnlock or 
     event == hs.caffeinate.watcher.systemDidWake then
    print("[PTT] Wake event detected.")
    hs.timer.doAfter(1.0, restartTaps) -- wait a bit after wake
  end
end)
_G.pttVoice.caffeinateWatcher:start()

-- Health Check (30s)
if _G.pttVoice.healthCheckTimer then _G.pttVoice.healthCheckTimer:stop() end
_G.pttVoice.healthCheckTimer = hs.timer.doEvery(30, function()
  local mt = _G.pttVoice.modTap
  local at = _G.pttVoice.activityTap
  
  if (not mt) or (not mt:isEnabled()) then
    print("[PTT] Watchdog: modTap died! Restarting...")
    restartTaps()
  elseif (not at) or (not at:isEnabled()) then
    print("[PTT] Watchdog: activityTap died! Restarting...")
    restartTaps()
  end
end)

-- Initial Start
restartTaps()

hs.alert.show("Voice PTT Reloaded (Direct Groq API)")
print("[PTT] Script loaded fully (Direct Groq API mode).")

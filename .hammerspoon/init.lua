-- Hammerspoon Configuration
-- Speech to Text optimized with Groq API

-- Global configuration
-- Put your Groq API key here
local secrets = require("secrets")
local GROQ_API_KEY = secrets.GROQ_API_KEY

-- Load Speech to Text Module
local speechToText = require("speech_to_text")
speechToText.apiKey = GROQ_API_KEY
speechToText:start()
hs.alert.show("Speech to text module loaded")

-- Load Text Switcher Module
local textSwitcher = require("text_switcher")
textSwitcher.start()
hs.alert.show("Transliteration module loaded")

-- Load Audio Switcher Module
local audioSwitcher = require("audio_switcher")
audioSwitcher.start()
hs.alert.show("Audio Switcher module loaded")

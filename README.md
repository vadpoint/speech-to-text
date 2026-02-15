# Voice-to-Text PTT Automation (macOS)

A high-performance, low-latency Push-to-Talk (PTT) voice typing solution for macOS using **Hammerspoon**, **n8n**, and the **Groq API** (Whisper).

## 🚀 How it works
1. **Hold `Fn` key**: Activates recording (after a 0.4s delay to prevent accidental triggers). 
2. **Speak**: The script records your audio while the key is held.
3. **Release `Fn` key**: Audio is encoded to Opus and sent to an **n8n** webhook.
4. **Processing**: n8n sends the file to **Groq's Whisper API** for ultra-fast transcription.
5. **Auto-Paste**: The result is sent back to Hammerspoon and automatically pasted into your active application.

## ✨ Features
- **Anti-Hallucination**: High-precision filtering to ignore common Whisper "silence" hallucinations (e.g., "Thank you", "Subscribe").
- **Smart Watchdog**: Automatically restarts event listeners if they are killed by the system (e.g., after sleep/wake).
- **Zero Configuration for Apps**: Works in any text field across the entire OS.
- **Micro-Optimization**: Uses Opus encoding (16k) for fast uploads and minimal bandwidth.

## 📦 Requirements
- **macOS**
- [Hammerspoon](https://www.hammerspoon.org/)
- [FFmpeg](https://ffmpeg.org/) (installed via `brew install ffmpeg`)
- [Groq API Key](https://console.groq.com/)
- **SoX** (Recommended/Default): Install via `brew install sox`.
  - *Note: The script is pre-configured for SoX. You can use other CLI tools (like `coreaudio-rec`) by editing the `recBin` path in `init.lua`.*

## 🛠 Installation

### Simple Lua Script (Recommended - No Dependencies!)

This is the simplest approach: just one Lua file that talks directly to Groq API.

1. **Get your Groq API key** from [console.groq.com](https://console.groq.com/)

2. **Configure the script:**
   - Open `init.lua` in this project
   - Find the line: `local GROQ_API_KEY = "YOUR_GROQ_API_KEY_HERE"`
   - Replace with your actual API key

3. **Copy to Hammerspoon:**
   
   **Option A: Direct Copy** (Easiest)
   ```bash
   cp /path/to/your/project/speech-to-text/init.lua ~/.hammerspoon/init.lua
   ```

   **Option B: Symbolic Link** (Recommended for developers)
   This keeps your Hammerspoon config in sync with the repository.
   ```bash
   ln -s /path/to/your/project/speech-to-text/init.lua ~/.hammerspoon/init.lua
   ```
   *Make sure to backup your existing `init.lua` first if you have one.*

4. **Reload Hammerspoon** configuration.

**That's it!** No Python, no n8n, no HTTP servers — just pure Lua + curl.

---

### Alternative: n8n Workflow (Legacy)

If you prefer using n8n as a middleware:

1. Import `n8n_voice_to_text.json` into your n8n instance.
2. Configure the **HTTP Request** node with your Groq API credentials.
3. Activate the workflow and copy the webhook URL.
4. Use `init-production.lua` instead of `init.lua`, updating the `webhook` variable.

## ⌨️ Usage
- **Hold `Fn`**: Start recording.
- **Hold `Fn + Shift`**: Start recording in Ukrainian mode.
- **Key + other key**: If you press any other key while holding `Fn`, recording is cancelled.
- **Release `Fn`**: Finish and transcribe.
- **Short press**: If held for less than 0.6s, recording is ignored.

## ⚙️ Customization

### Adjusting the Transcription Prompt
You can customize how Whisper processes your speech by editing the `getPrompt()` function in `init.lua`:

```lua
local function getPrompt(language)
  if language == "uk" then
    return "It might be English text. Це може бути український текст."
  else
    return "Your custom prompt here..."
  end
end
```

### Recording Configuration
The script uses `sox` by default. You can change the recording arguments in the `startRecording` function inside `init.lua`:

```lua
-- current default (sox with default device)
recTask = hs.task.new(recBin, function() ... end, {"-d", wavFile}) 
```

If you need to change input devices or audio format, modify the arguments `{ "-d", wavFile }` here.

**Why change it?**
- **Languages**: Add text in the languages you use most to "guide" Whisper.
- **Technical Terms**: Add specific jargon (e.g., "Kubernetes", "React") to ensure correct spelling.
- **Punctuation**: Whisper often mirrors the style of the prompt.

## 🔍 Debugging

If the transcription is not working as expected or contains "hallucinations", follow these steps to troubleshoot and fine-tune the system.

### 1. Filtering Hallucinations (Blocked Words)
Whisper sometimes "hallucinates" common phrases (like "Thank you for watching") when there is silence or background noise. You can block these specific strings:
1. Open `init.lua`.
2. Locate the `hallucinations` table (around line 73).
3. Add the unwanted phrase as a key with `true` as the value:
   ```lua
   ["newhallucination"] = true,
   ```
   *Note: The script removes spaces and converts text to lowercase before checking this table. Somehow Cyrillic capital letters don't convert. *

### 2. Fine-Tuning the Prompt
The `prompt` parameter significantly influences Whisper's accuracy, language detection, and formatting.
1. Open `init.lua`.
2. Locate the `getPrompt()` function (around line 117).
3. Adjust the returned text to include examples of technical terms, languages, or punctuation styles you want Whisper to follow.

### 3. Debugging with Saved Audio
If you encounter a specific recording that Whisper transcribes poorly:
1. Every recording is temporarily stored at `/tmp/voice.opus`.
2. Copy this file to test it:
   ```bash
   cp /tmp/voice.opus ~/Desktop/test.opus
   ```
3. Test directly with curl to experiment with different prompts:
   ```bash
   curl -X POST https://api.groq.com/openai/v1/audio/transcriptions \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -F "file=@test.opus;type=audio/opus" \
     -F "model=whisper-large-v3-turbo" \
     -F "response_format=text" \
     -F "prompt=Your test prompt here"
   ```


## 🤝 Attribution
Created for a personalized voice-typing workflow that bridges local macOS automation with cloud-based LLM transcription.

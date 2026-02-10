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
- [n8n](https://n8n.io/)
- [FFmpeg](https://ffmpeg.org/) (installed via `brew install ffmpeg`)
- [Groq API Key](https://console.groq.com/)
- A CLI recording utility (e.g., `coreaudio-rec` or similar).

## 🛠 Installation

### 1. n8n Workflow
1. Import `n8n_voice_to_text.json` into your n8n instance.
2. Configure the **HTTP Request** node:
   - Use your Groq API credentials.
   - The workflow uses `whisper-large-v3-turbo`.
3. Activate the workflow and copy the **Production Webhook URL**.

### 2. Hammerspoon Script
1. The script is located in `.hammerspoon/init.lua`.
2. Open it and update the following variables:
   - `webhook`: Paste your n8n webhook URL here.
   - `recBin`: Path to your recording CLI tool (default: `~/coreaudio-rec/ptt_rec`).
   - `ffmpeg`: Path to your ffmpeg binary (default: `/usr/local/bin/ffmpeg`).
3. Copy the content to your `~/.hammerspoon/init.lua` or simply link the folder.
4. Reload Hammerspoon configuration.

## ⚙️ Customization

### 1. Adjusting the Transcription Prompt
You can customize how Whisper processes your speech (e.g., adding preferred languages, technical terms, or formatting rules) by editing the **HTTP Request** node in n8n:
1. Open your workflow in n8n.
2. Double-click the **HTTP Request** node.
3. Find the `prompt` parameter in the **Body Parameters** section.
4. Update the value to include your own context.

**Example prompt:**
> "Привет, это технический апдейт. Сьогоднi ми задеплоїли нову версию в production. Check logs for details. Здається, системный конфиг подтянулся корректно."

**Why change it?**
- **Languages**: Add text in the languages you use most (e.g., Russian, Ukrainian) to "guide" Whisper.
- **Technical Terms**: Add specific jargon (e.g., "Kubernetes", "React") to ensure they are spelled correctly.
- **Punctuation**: Whisper often mirrors the style of the prompt.

### 2. Editing JSON directly
If you prefer editing the configuration file before importing:
1. Open `n8n_voice_to_text.json` in a text editor.
2. Search for the `prompt` key.
3. Update the `value` string.
4. Save and import the file into n8n.

## ⌨️ Usage
- **Hold `Fn`**: Start recording.
- **Key + other key**: If you press any other key while holding `Fn`, recording is cancelled (useful for avoidance).
- **Release `Fn`**: Finish and transcribe.
- **Short press**: If held for less than 0.6s, recording is ignored.

## 🔍 Debugging

If the transcription is not working as expected or contains "hallucinations", follow these steps to troubleshoot and fine-tune the system.

### 1. Filtering Hallucinations (Blocked Words)
Whisper sometimes "hallucinates" common phrases (like "Thank you for watching") when there is silence or background noise. You can block these specific strings:
1. Open `init-production.lua`.
2. Locate the `hallucinations` table (around line 73).
3. Add the unwanted phrase as a key with `true` as the value:
   ```lua
   ["newhallucination"] = true,
   ```
   *Note: The script removes spaces and converts text to lowercase before checking this table.*

### 2. Fine-Tuning the Prompt (n8n)
The `prompt` parameter in n8n significantly influences Whisper's accuracy, language detection, and formatting.
1. Open your workflow in **n8n**.
2. Double-click the **HTTP Request** node.
3. Locate the `prompt` field in the **Body Parameters**.
4. Adjust the text to include examples of the technical terms, languages, or punctuation styles you want Whisper to follow.

### 3. Debugging with `debug_n8n.py`
If you encounter a specific recording that Whisper transcribes poorly, you can debug it locally:
1. Every recording is temporarily stored at `/tmp/voice.opus`.
2. Copy this file to the project's `res/` directory:
   ```bash
   cp /tmp/voice.opus /Users/onetiger/projects/n8n/speech-to-text/res/voice.opus
   ```
3. Use the `debug_n8n.py` script to send this specific file to n8n repeatedly while you experiment with different prompts:
   ```bash
   python3 debug_n8n.py
   ```
4. Adjust the `prompt` in `debug_n8n.py` or directly in n8n until the output meets your expectations.

## 🤝 Attribution
Created for a personalized voice-typing workflow that bridges local macOS automation with cloud-based LLM transcription.

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

## ⌨️ Usage
- **Hold `Fn`**: Start recording.
- **Key + other key**: If you press any other key while holding `Fn`, recording is cancelled (useful for avoidance).
- **Release `Fn`**: Finish and transcribe.
- **Short press**: If held for less than 0.6s, recording is ignored.

## 🤝 Attribution
Created for a personalized voice-typing workflow that bridges local macOS automation with cloud-based LLM transcription.

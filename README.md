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
1. Import `n8n_voice_to_text.json`.
2. Configure **Groq API** credentials in the HTTP Request node.
3. Copy your **Production Webhook URL**.

### 2. Hammerspoon
1. Copy `.hammerspoon/init.lua` to your `~/.hammerspoon/` directory.
2. Update `webhook`, `recBin`, and `ffmpeg` variables at the top of the file.
3. Reload Hammerspoon config.

## ⌨️ Usage
- **Hold `Fn`**: Start recording.
- **Key + other key**: If you press any other key while holding `Fn`, recording is cancelled (useful for avoidance).
- **Release `Fn`**: Finish and transcribe.
- **Short press**: If held for less than 0.6s, recording is ignored.

## 🤝 Attribution
Created for a personalized voice-typing workflow that bridges local macOS automation with cloud-based LLM transcription.

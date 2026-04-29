import requests
import os
import sys

# Configuration
API_KEY = "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"
API_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
AUDIO_FILE = "/tmp/voice.opus"
LANGUAGE = "en" # "en" or "uk"

PROMPT_UK = "Ну, е-е-е, коротше, ось так. Умм, mhm, okay, well. Це текст з правильною пунктуацією."
# PROMPT_MIXED = "Umm, hmm, well, you know, like. Ну, эээ, шо, короче, вот так. Это текст с правильной пунктуацией."
PROMPT_MIXED = "Ну, эээ, шо, короче, вот так. Umm, hmm, well, you know, like. This text can be both English and Russian with proper punctuation."
# PROMPT_MIXED = "This is a raw transcription that must preserve ALL spoken words including filler words, hesitations, and dysfluencies. Keep words like: umm, hmm, mm, mhm, uh, um, ah, ehm, well, like, you know. It might be English text. Это может быть русский текст. Add proper punctuation. Never remove any words. Mix of Russian and English is possible and expected. Сохраняй, блядь, язык ввода. Не вздумай ничего не переводить, дебил, блядь."


def get_prompt(lang):
    if lang == "uk":
        return PROMPT_UK
    else:
        return PROMPT_MIXED

def main():
    if not os.path.exists(AUDIO_FILE):
        print(f"Error: {AUDIO_FILE} not found.")
        sys.exit(1)

    print(f"Sending {AUDIO_FILE} to Groq API...")
    
    # Determine model based on language
    model = "whisper-large-v3" if LANGUAGE == "uk" else "whisper-large-v3"
    prompt = get_prompt(LANGUAGE)
    
    try:
        with open(AUDIO_FILE, 'rb') as f:
            files = {
                'file': (os.path.basename(AUDIO_FILE), f, 'audio/opus')
            }
            data = {
                'model': model,
                'prompt': prompt,
                'response_format': 'text' # Using text response format as per lua script
            }
            
            # Additional params based on language logic in lua
            if LANGUAGE == "uk":
                data['language'] = 'uk'
            else:
                data['temperature'] = 0

            headers = {
                "Authorization": f"Bearer {API_KEY}"
            }

            response = requests.post(API_URL, headers=headers, files=files, data=data)

            if response.status_code == 200:
                print("Success!")
                print("Response:")
                print(response.text)
            else:
                print(f"Error: {response.status_code}")
                print(response.text)

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()

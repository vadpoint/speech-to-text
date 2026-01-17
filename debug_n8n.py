import requests
import os
import sys

# Configuration from init.lua
WEBHOOK_URL = "http://localhost:5678/webhook/824c2fd9-a2a6-41c4-8578-48dfa63601ea"
# WEBHOOK_URL = "http://localhost:5678/webhook-test/824c2fd9-a2a6-41c4-8578-48dfa63601ea"
AUDIO_FILE = "res/voice.opus"

def main():
    if not os.path.exists(AUDIO_FILE):
        print(f"Error: {AUDIO_FILE} not found.")
        sys.exit(1)

    print(f"Sending {AUDIO_FILE} to n8n...")
    
    try:
        with open(AUDIO_FILE, 'rb') as f:
            files = {
                'file': (os.path.basename(AUDIO_FILE), f, 'audio/opus')
            }
            data = {
                'format': 'opus'
            }
            
            response = requests.post(WEBHOOK_URL, files=files, data=data)
            
            print(f"Status Code: {response.status_code}")
            print("Response:")
            print(response.text)
            
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()

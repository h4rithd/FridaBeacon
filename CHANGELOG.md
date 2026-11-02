# Changelog

## 1.0 — Initial Release

- Start the official Frida server automatically after Android boots.
- Detect Android ARM, ARM64, x86, or x86_64 and fetch the latest official server during installation.
- Show running state, server version, and localhost port in the module card and status command.
- Use Magisk's Action control to start or stop the server.
- Check and install newer official Frida releases from the module using Android's HTTPS stack and GitHub SHA-256 digests.

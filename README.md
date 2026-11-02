# FridaBeacon

**FridaBeacon is an Android Frida server Magisk module** that starts Frida after
boot, shows its running state in Magisk, and downloads official Frida updates.
It works with Android ARM, ARM64, x86, and x86_64 devices and emulators.

Developed by **Harith Dilshan** ([h4rithd.com](https://h4rithd.com)).
FridaBeacon is independent of the Frida and Magisk projects.

**[Download FridaBeacon v1.0](https://github.com/h4rithd/FridaBeacon/releases/tag/v1.0)**
· [Installation](#installation) · [Controls](#controls-and-status)
· [Troubleshooting](#troubleshooting)

## What FridaBeacon does

| Feature | Details |
| --- | --- |
| Automatic startup | Starts the official Frida server after Android finishes booting. |
| Architecture detection | Installs the matching Android ARM, ARM64, x86, or x86_64 server. |
| Magisk Action | One tap stops a running server or starts a stopped server. |
| Status indicator | 🟢 or 🔴 on the module card; the console shows state, version, architecture, PID, and port. |
| Built-in updater | Fetches the latest stable official release over Android HTTPS, verifies GitHub's SHA-256 digest, and can roll back if a replacement fails to start. |
| Local connection | Binds to `127.0.0.1:27042` by default. |

The release ZIP contains **no Frida server binary**. During installation,
FridaBeacon downloads the newest official Android server for the detected CPU
architecture. Its Android HTTPS helper needs no `curl`, Termux, or other module.

## Installation

1. Download **`FridaBeacon-v1.0.zip`** from the
   [v1.0 release](https://github.com/h4rithd/FridaBeacon/releases/tag/v1.0).
2. Keep the Android device or emulator connected to the internet. In Magisk,
   open **Modules → Install from storage**, select the ZIP, and wait for the
   official Frida download and SHA-256 verification to finish.
3. Reboot Android. Open Magisk's Modules screen. 🟢 **FridaBeacon** means its
   server is running.

FridaBeacon requires working Magisk root. Zygisk is optional. If another Frida
server already occupies port `27042`, stop that server before starting
FridaBeacon. Installing this module does not alter that manual installation or
other Magisk modules.

## Controls and status

Tap **Action** on the FridaBeacon card to stop or start the server. The Action
console prints the result. **Close the console to refresh the card's status
dot**; Magisk can keep the title cached while the console is open. The native
button remains labelled **Action** because Magisk controls its text.

From a rooted Android shell, the same controls are available directly:

```sh
su -c '/data/adb/modules/fridabeacon/frida-ctl.sh status'
su -c '/data/adb/modules/fridabeacon/frida-ctl.sh start'
su -c '/data/adb/modules/fridabeacon/frida-ctl.sh stop'
```

To update the Frida server **using the installed module**:

```sh
su -c '/data/adb/modules/fridabeacon/frida-ctl.sh update'
```

The updater checks the latest stable Frida release, downloads the asset for
the installed architecture, verifies the official SHA-256 digest and server
version, and replaces the binary. If Frida was running, it restarts it. A
failed restart restores the previous executable. The Action button is reserved
for quick start and stop; run `update` when you want a new Frida version.

With ADB on a computer, use:

```sh
adb shell su -c '/data/adb/modules/fridabeacon/frida-ctl.sh update'
adb forward tcp:27042 tcp:27042
frida-ps -H 127.0.0.1:27042
```

Matching the host Frida client to the server version is recommended.

## Why the Action control changed

An early private test build opened Magisk's Action console but could fail to
toggle Frida. Magisk invoked the script as `./action.sh`; the old controller
compared a relative executable path with Android's absolute process path and
mistook a running server for a stopped one. The v1.0 initial release resolves
the module path before checking the process. Start and stop were verified by
tapping **Action in Magisk**, then checking the server and status dot.

If you installed an early test ZIP, install the v1.0 release ZIP over it and
reboot. If you also installed a separate earlier Frida boot module, remove or
disable that module first so both services do not compete for port `27042`.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Installation cannot download Frida | Confirm internet access to GitHub on the Android device, then retry installation. |
| Action opens but Frida does not start | Read the Action console error. A manual server may already be using port `27042`. |
| Card dot looks unchanged | Close the Action console, then reopen or refresh the Modules screen. Check the root-shell `status` command for the live state. |
| No Action button appears | Use the root-shell `start` and `stop` commands above; Action support depends on the Magisk app. |
| Host cannot connect | Check that status says `RUNNING`, then run the `adb forward` and `frida-ps` commands above. |

## Build from source

The module ZIP builder needs Python 3:

```sh
python3 build.py
```

It creates `dist/FridaBeacon-v1.0.zip`. Set `FRIDABEACON_OUTPUT_DIR` to choose
a different output folder. The ZIP has no architecture-specific server binary;
installation fetches the latest official release on the device.

`module/fetcher.jar` is a small, architecture-independent Android DEX helper.
Its source is in `android/src/`. To rebuild the helper, install an Android SDK
and JDK, set `ANDROID_HOME` and `JAVA_HOME`, then run:

```sh
python3 android/build.py
```

## Security and licensing

FridaBeacon keeps its executable and state inside its own Magisk module folder
and does not modify system partitions or other modules. The executable gets a
per-install filename, which can avoid simple filename checks but does not make
Frida undetectable. Use Frida only on systems you own or are authorized to test.

FridaBeacon's source is under the [MIT license](LICENSE). The downloaded Frida
server remains under [Frida's license](https://github.com/frida/frida/blob/main/COPYING).
See [CHANGELOG.md](CHANGELOG.md) for the initial-release feature list.

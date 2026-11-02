# Magisk sources this file after extracting the module.
ui_print "========================================"
ui_print "             FRIDA BEACON"
ui_print "        Magisk Frida server manager"
ui_print "  by Harith Dilshan (h4rithd.com)"
ui_print "         v1.0 | Initial Release"
ui_print "========================================"

case "$ARCH" in
  arm|arm64|x86) FRIDA_ARCH="$ARCH" ;;
  x64) FRIDA_ARCH=x86_64 ;;
  *) abort "Unsupported Android architecture: $ARCH" ;;
esac

mkdir -p "$MODPATH/bin" "$MODPATH/state" || abort "Could not create module directories"
set_perm "$MODPATH/bin" 0 0 0700
set_perm "$MODPATH/state" 0 0 0700
set_perm "$MODPATH/frida-ctl.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/fetcher.jar" 0 0 0644

# A per-install name avoids the obvious frida-server filename. This is not a
# promise that Frida cannot be detected by an app inspecting its own process.
RANDOM_SUFFIX=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
[ -n "$RANDOM_SUFFIX" ] || abort "Could not generate a binary name"
FRIDA_NAME="svc_$RANDOM_SUFFIX"
FRIDA_PATH="$MODPATH/bin/$FRIDA_NAME"
ui_print "Checking the latest official Frida release for $FRIDA_ARCH..."
METADATA=$(CLASSPATH="$MODPATH/fetcher.jar" /system/bin/app_process /system/bin com.h4rithd.fridabeacon.Fetcher metadata "$FRIDA_ARCH") || abort "Could not read official Frida release metadata; check internet access"
set -- $METADATA
[ "$#" -eq 2 ] || abort "Invalid Frida release metadata"
FRIDA_VERSION=$1
FRIDA_DIGEST=$2
echo "$FRIDA_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || abort "Invalid Frida version"
echo "$FRIDA_DIGEST" | grep -Eq '^[0-9a-f]{64}$' || abort "Invalid Frida SHA-256 digest"
ui_print "Downloading Frida $FRIDA_VERSION..."
CLASSPATH="$MODPATH/fetcher.jar" /system/bin/app_process /system/bin com.h4rithd.fridabeacon.Fetcher fetch "$FRIDA_ARCH" "$FRIDA_VERSION" "$FRIDA_DIGEST" "$MODPATH/state/server.xz" || abort "Frida download or SHA-256 verification failed"
/data/adb/magisk/busybox unxz -c "$MODPATH/state/server.xz" > "$FRIDA_PATH" || abort "Could not decompress Frida server"
[ -s "$FRIDA_PATH" ] || abort "Decompressed Frida asset is empty"
set_perm "$FRIDA_PATH" 0 0 0700 u:object_r:system_file:s0
[ "$("$FRIDA_PATH" --version 2>/dev/null)" = "$FRIDA_VERSION" ] || abort "Downloaded Frida server version mismatch"
printf '%s\n' "$FRIDA_NAME" > "$MODPATH/state/name"
printf '%s\n' "$FRIDA_VERSION" > "$MODPATH/state/version"
printf '%s\n' "$FRIDA_ARCH" > "$MODPATH/state/arch"
chmod 0600 "$MODPATH/state/name" "$MODPATH/state/version" "$MODPATH/state/arch"
rm "$MODPATH/state/server.xz"
ui_print "Frida $(cat "$MODPATH/state/version") selected for $FRIDA_ARCH"
ui_print "Executable stored under a per-install name"
ui_print "Install complete. Reboot, then tap Action to start or stop."

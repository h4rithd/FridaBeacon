#!/system/bin/sh
MODDIR=$(cd "${0%/*}" 2>/dev/null && pwd -P) || exit 1
echo "FridaBeacon • by Harith Dilshan (h4rithd.com)"
"$MODDIR/frida-ctl.sh" toggle 2>&1

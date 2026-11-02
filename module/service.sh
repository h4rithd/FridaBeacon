#!/system/bin/sh
MODDIR=$(cd "${0%/*}" 2>/dev/null && pwd -P) || exit 1
count=0
while [ "$(getprop sys.boot_completed)" != 1 ] && [ "$count" -lt 90 ]; do
  sleep 2
  count=$((count + 1))
done
"$MODDIR/frida-ctl.sh" start >/dev/null 2>&1
while true; do
  "$MODDIR/frida-ctl.sh" refresh-label >/dev/null 2>&1
  sleep 15
done

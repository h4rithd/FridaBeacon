#!/system/bin/sh
MODDIR=$(cd "${0%/*}" 2>/dev/null && pwd -P) || exit 1
STATE="$MODDIR/state"
LISTEN=127.0.0.1:27042
FETCHER=com.h4rithd.fridabeacon.Fetcher

binary_name=$(cat "$STATE/name" 2>/dev/null) || exit 1
echo "$binary_name" | grep -Eq '^svc_[0-9a-f]{16}$' || {
  echo "Invalid FridaBeacon executable name" >&2
  exit 1
}
BIN="$MODDIR/bin/$binary_name"
[ -f "$BIN" ] || { echo "FridaBeacon executable is missing" >&2; exit 1; }

running_pid() {
  for pid in $(pidof "$binary_name" 2>/dev/null); do
    [ "$(readlink "/proc/$pid/exe" 2>/dev/null)" = "$BIN" ] && {
      echo "$pid"
      return 0
    }
  done
  return 1
}

refresh_label() {
  version=$(cat "$STATE/version" 2>/dev/null)
  arch=$(cat "$STATE/arch" 2>/dev/null)
  if running_pid >/dev/null; then
    display="🟢 FridaBeacon"
    description="Running • Frida $version on Android $arch at $LISTEN. Tap Action to stop; update from the module controller."
  else
    display="🔴 FridaBeacon"
    description="Stopped • Frida $version for Android $arch. Tap Action to start; update from the module controller."
  fi
  old_name=$(sed -n 's/^name=//p' "$MODDIR/module.prop" | head -n 1)
  old_description=$(sed -n 's/^description=//p' "$MODDIR/module.prop" | head -n 1)
  [ "$old_name" = "$display" ] && [ "$old_description" = "$description" ] && return 0
  temporary="$MODDIR/module.prop.$$"
  awk -v display="$display" -v description="$description" '
    /^name=/ { print "name=" display; next }
    /^description=/ { print "description=" description; next }
    { print }
  ' "$MODDIR/module.prop" > "$temporary" || return 1
  chmod 0644 "$temporary"
  mv "$temporary" "$MODDIR/module.prop"
}

status() {
  version=$(cat "$STATE/version" 2>/dev/null)
  arch=$(cat "$STATE/arch" 2>/dev/null)
  if pid=$(running_pid); then
    echo "RUNNING  pid=$pid  version=$version  arch=$arch  listen=$LISTEN"
  else
    echo "STOPPED  version=$version  arch=$arch  configured_listen=$LISTEN"
  fi
  refresh_label
}

start() {
  if running_pid >/dev/null; then
    status
    return 0
  fi
  if ! "$BIN" -D -l "$LISTEN" </dev/null >/dev/null 2>&1; then
    echo "FridaBeacon could not start; check whether port 27042 is already in use" >&2
    refresh_label
    return 1
  fi
  sleep 1
  if ! running_pid >/dev/null; then
    echo "FridaBeacon exited after startup" >&2
    refresh_label
    return 1
  fi
  status
}

stop() {
  pid=$(running_pid) || { status; return 0; }
  kill "$pid" || return 1
  count=0
  while running_pid >/dev/null && [ "$count" -lt 10 ]; do
    sleep 1
    count=$((count + 1))
  done
  if running_pid >/dev/null; then
    echo "FridaBeacon did not stop" >&2
    return 1
  fi
  status
}

update() {
  arch=$(cat "$STATE/arch" 2>/dev/null)
  case "$arch" in arm|arm64|x86|x86_64) ;; *) echo "Unsupported architecture" >&2; return 1 ;; esac
  echo "Checking the latest official Frida release..."
  metadata=$(CLASSPATH="$MODDIR/fetcher.jar" /system/bin/app_process /system/bin "$FETCHER" metadata "$arch") || return 1
  set -- $metadata
  [ "$#" -eq 2 ] || { echo "Invalid release metadata" >&2; return 1; }
  latest_version=$1
  latest_digest=$2
  echo "$latest_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || return 1
  echo "$latest_digest" | grep -Eq '^[0-9a-f]{64}$' || return 1
  previous_version=$(cat "$STATE/version" 2>/dev/null)
  if [ "$latest_version" = "$previous_version" ]; then
    echo "Already current: Frida $latest_version"
    refresh_label
    return 0
  fi

  work="$STATE/update.$$"
  mkdir -m 0700 "$work" || return 1
  if ! CLASSPATH="$MODDIR/fetcher.jar" /system/bin/app_process /system/bin "$FETCHER" fetch "$arch" "$latest_version" "$latest_digest" "$work/server.xz"; then
    rmdir "$work" 2>/dev/null
    return 1
  fi
  if ! /data/adb/magisk/busybox unxz -c "$work/server.xz" > "$work/server"; then
    echo "Could not decompress the verified Frida release" >&2
    rm "$work/server.xz" "$work/server"
    rmdir "$work"
    return 1
  fi
  chmod 0700 "$work/server"
  chcon u:object_r:system_file:s0 "$work/server" 2>/dev/null || true
  if [ "$("$work/server" --version 2>/dev/null)" != "$latest_version" ]; then
    echo "Downloaded server did not report the expected version" >&2
    rm "$work/server.xz" "$work/server"
    rmdir "$work"
    return 1
  fi

  was_running=0
  if running_pid >/dev/null; then
    was_running=1
    stop || { rm "$work/server.xz" "$work/server"; rmdir "$work"; return 1; }
  fi
  if ! mv "$BIN" "$work/previous"; then
    rm "$work/server.xz" "$work/server"
    rmdir "$work"
    return 1
  fi
  if ! mv "$work/server" "$BIN"; then
    mv "$work/previous" "$BIN"
    [ "$was_running" -eq 1 ] && start
    rm "$work/server.xz"
    rmdir "$work"
    return 1
  fi
  chmod 0700 "$BIN"
  if [ "$was_running" -eq 1 ] && ! start; then
    mv "$BIN" "$work/failed"
    mv "$work/previous" "$BIN"
    start
    rm "$work/server.xz" "$work/failed"
    rmdir "$work"
    return 1
  fi
  printf '%s\n' "$latest_version" > "$STATE/version"
  chmod 0600 "$STATE/version"
  rm "$work/server.xz" "$work/previous"
  rmdir "$work"
  refresh_label
  echo "Updated Frida: $previous_version -> $latest_version"
}

case "$1" in
  status) status ;;
  refresh-label) refresh_label ;;
  start|stop|toggle|restart|update)
    mkdir "$STATE/control.lock" 2>/dev/null || { echo "FridaBeacon is busy" >&2; exit 1; }
    trap 'rmdir "$STATE/control.lock" 2>/dev/null' EXIT HUP INT TERM
    case "$1" in
      start) start ;;
      stop) stop ;;
      toggle) if running_pid >/dev/null; then stop; else start; fi ;;
      restart) stop && start ;;
      update) update ;;
    esac
    ;;
  *) echo "Usage: $0 {status|start|stop|toggle|restart|update}" >&2; exit 2 ;;
esac

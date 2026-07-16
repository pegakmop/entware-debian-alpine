## systemctl debian chroot
``` 
cat > /usr/local/sbin/systemctl << 'SCRIPTEOF'
#!/bin/bash
UNIT_DIR="/etc/systemd/system"
WANTS_DIR="/etc/systemd/system/multi-user.target.wants"
RUN_DIR="/run/fake-systemd"
mkdir -p "$RUN_DIR" "$WANTS_DIR"

find_unit() {
  local name="$1"
  for d in "$UNIT_DIR" /lib/systemd/system /usr/lib/systemd/system; do
    [ -f "$d/$name" ] && { echo "$d/$name"; return 0; }
  done
  return 1
}
get_field() {
  local file="$1" field="$2"
  grep -E "^${field}=" "$file" | head -1 | cut -d= -f2- | tr -d '\r'
}
get_all_fields() {
  local file="$1" field="$2"
  grep -E "^${field}=" "$file" | cut -d= -f2- | tr -d '\r'
}
pidfile() { echo "$RUN_DIR/$1.pid"; }

do_start() {
  local name="$1"
  local svc="$name.service"
  local unit; unit="$(find_unit "$svc")" || { echo "Unit $svc not found"; return 1; }
  local pf; pf="$(pidfile "$name")"
  if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then
    echo "$name already running"; return 0
  fi

  local ef
  for ef in $(get_all_fields "$unit" EnvironmentFile); do
    ef="${ef#-}"
    if [ -f "$ef" ]; then
      set -a
      . "$ef"
      set +a
    fi
  done

  local pre rc
  while IFS= read -r pre; do
    [ -n "$pre" ] || continue
    eval "$pre" >> "$RUN_DIR/$name.log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "ExecStartPre failed (rc=$rc): $pre" >> "$RUN_DIR/$name.log"
      echo "ExecStartPre failed (rc=$rc): $pre"
      return 1
    fi
  done <<< "$(get_all_fields "$unit" ExecStartPre)"

  local execstart; execstart="$(get_field "$unit" ExecStart)"
  [ -n "$execstart" ] || { echo "No ExecStart in $unit"; return 1; }

  eval "nohup $execstart >> \"$RUN_DIR/$name.log\" 2>&1 &"
  local pid=$!
  echo "$pid" > "$pf"
  sleep 0.3
  if kill -0 "$pid" 2>/dev/null; then
    echo "Started $name (pid $pid)"
  else
    echo "Failed to start $name, see $RUN_DIR/$name.log"
    rm -f "$pf"
    return 1
  fi
}
do_stop() {
  local pf; pf="$(pidfile "$1")"
  if [ -f "$pf" ]; then
    kill "$(cat "$pf")" 2>/dev/null
    rm -f "$pf"
    echo "Stopped $1"
  else
    echo "$1 not running"
  fi
}
do_status() {
  local pf; pf="$(pidfile "$1")"
  if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then
    echo "● $1 - active (running), pid $(cat "$pf")"
  else
    echo "○ $1 - inactive (dead)"
  fi
}
do_list() {
  local found=0
  for f in "$UNIT_DIR"/*.service; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .service)"
    pf="$(pidfile "$name")"
    local en="disabled"
    [ -L "$WANTS_DIR/$name.service" ] && en="enabled"
    if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then
      echo "🟢 $name  running  ($en)"
    else
      echo "🔴 $name  stopped  ($en)"
    fi
    found=1
  done
  [ "$found" -eq 0 ] && echo "No units found in $UNIT_DIR"
}
do_enable() {
  local name="$1"
  local svc="$name.service"
  local unit; unit="$(find_unit "$svc")" || { echo "Unit $svc not found"; return 1; }
  ln -sf "$unit" "$WANTS_DIR/$svc"
  echo "Enabled $name (will autostart on chroot entry)"
}
do_disable() {
  local name="$1"
  rm -f "$WANTS_DIR/$name.service"
  echo "Disabled $name"
}
do_autostart() {
  # вызывается извне, например из скрипта входа в chroot
  for f in "$WANTS_DIR"/*.service; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .service)"
    do_start "$name"
  done
}

cmd="$1"; shift
case "$cmd" in
  start)   for s in "$@"; do do_start "${s%.service}"; done ;;
  stop)    for s in "$@"; do do_stop "${s%.service}"; done ;;
  restart) for s in "$@"; do do_stop "${s%.service}"; sleep 1; do_start "${s%.service}"; done ;;
  status)  for s in "$@"; do do_status "${s%.service}"; done ;;
  list)    do_list ;;
  enable)  for s in "$@"; do do_enable "${s%.service}"; done ;;
  disable) for s in "$@"; do do_disable "${s%.service}"; done ;;
  autostart) do_autostart ;;
  is-active)
    pf="$(pidfile "${1%.service}")"
    if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then echo active; exit 0
    else echo inactive; exit 3; fi ;;
  daemon-reload|daemon-reexec|reset-failed|mask|unmask)
    echo "Running in chroot, ignoring command '$cmd'"; exit 0 ;;
  list-unit-files|list-units)
    ls "$UNIT_DIR" 2>/dev/null ;;
  *) echo "systemctl-shim: unsupported command '$cmd'"; exit 0 ;;
esac
SCRIPTEOF
chmod +x /usr/local/sbin/systemctl
echo 'systemctl autostart' >> /root/.bashrc
``` 
systemctl list|start|stop|disable|enable

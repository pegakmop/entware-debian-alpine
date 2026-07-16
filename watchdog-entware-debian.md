## watchdog
``` 
cat > /usr/local/sbin/fake-systemd-watchdog.sh << 'EOF'
#!/bin/bash
WANTS_DIR="/etc/systemd/system/multi-user.target.wants"
RUN_DIR="/run/fake-systemd"
LOG="$RUN_DIR/watchdog.log"
EXCLUDE="watchdog ssh sshd"

mkdir -p "$RUN_DIR"

is_excluded() {
  local name="$1"
  for ex in $EXCLUDE; do
    [ "$name" = "$ex" ] && return 0
  done
  return 1
}

while true; do
  for f in "$WANTS_DIR"/*.service; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .service)"
    is_excluded "$name" && continue
    pf="$RUN_DIR/$name.pid"
    if [ ! -f "$pf" ] || ! kill -0 "$(cat "$pf" 2>/dev/null)" 2>/dev/null; then
      echo "$(date '+%Y-%m-%d %H:%M:%S'): $name is down, restarting" >> "$LOG"
      /usr/local/sbin/systemctl start "$name" >> "$LOG" 2>&1
    fi
  done
  sleep 15
done
EOF
chmod +x /usr/local/sbin/fake-systemd-watchdog.sh
cat > /etc/systemd/system/watchdog.service << 'EOF'
[Unit]
Description=Fake-systemd watchdog (auto-restart enabled services)

[Service]
ExecStart=/usr/local/sbin/fake-systemd-watchdog.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable watchdog
systemctl start watchdog
systemctl status watchdog
``` 

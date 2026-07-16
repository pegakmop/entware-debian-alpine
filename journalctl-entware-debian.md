## journalctl debian chroot
```
cat > /usr/local/sbin/journalctl << 'SCRIPTEOF'
#!/bin/bash
RUN_DIR="/run/fake-systemd"

show_help() {
  echo "journalctl-shim (chroot fake): reads logs from $RUN_DIR"
  echo "Usage:"
  echo "  journalctl -u <service>       show full log for service"
  echo "  journalctl -u <service> -f    follow (tail -f) log for service"
  echo "  journalctl -u <service> -n N  show last N lines"
  echo "  journalctl --list             list available service logs"
}

unit=""
follow=0
lines=""

while [ $# -gt 0 ]; do
  case "$1" in
    -u)
      unit="$2"; shift 2 ;;
    -f)
      follow=1; shift ;;
    -n)
      lines="$2"; shift 2 ;;
    --list)
      ls "$RUN_DIR"/*.log 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.log$//'
      exit 0 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      shift ;;
  esac
done

if [ -z "$unit" ]; then
  show_help
  exit 1
fi

logfile="$RUN_DIR/${unit%.service}.log"

if [ ! -f "$logfile" ]; then
  echo "No log found for unit '$unit' (expected $logfile)"
  exit 1
fi

if [ "$follow" -eq 1 ]; then
  tail -f "$logfile"
elif [ -n "$lines" ]; then
  tail -n "$lines" "$logfile"
else
  cat "$logfile"
fi
SCRIPTEOF
chmod +x /usr/local/sbin/journalctl

``` 

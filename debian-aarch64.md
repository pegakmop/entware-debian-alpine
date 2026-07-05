# entware-debian aarch64

для запуска и работы дебиана внутри ентвара
```
opkg update && opkg install ca-certificates wget-ssl curl tar
```
ну и приступим к самой установке
``` 
# Скачиваем архив Debian
cd /opt/root
wget http://ndm.zyxmon.org/binaries/debian/debian-trixie-13.5-aarch64.tar.gz
# Создаем директорию и распаковываем Debian
mkdir -p /opt/debian
tar -xzf /opt/root/debian-trixie-13.5-aarch64.tar.gz -C /opt/debian
# Создаем временный каталог, используемый Debian-пакетами
mkdir -p /opt/tmp
chmod 1777 /opt/tmp
# Создаем скрипт для входа в chroot
cat > /opt/bin/debian << 'EOF'
#!/bin/sh
LANG=C LC_ALL=C \
chroot /opt/debian/debian /bin/bash -l -c "cd /root && exec /bin/bash -l"
EOF
chmod +x /opt/bin/debian

# Создаем скрипт инициализации сервисов
cat > /opt/etc/init.d/S99debian << 'EOF'
#!/bin/sh

PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin

# Debian folder
CHROOT_DIR=/opt/debian/debian

# Some folder outside of sandbox, will be mounted to /mnt folder in Debian
# Leave commented if not needed
#EXT_DIR=/media

CHROOT_SERVICES_LIST=$CHROOT_DIR/chroot-services.list
if [ ! -e "$CHROOT_SERVICES_LIST" ]; then
	echo "Please, define Debian services to start in $CHROOT_SERVICES_LIST first!"
	echo 'One service per line. Hint: this is a script names from Debian /etc/init.d/'
	exit 1
fi

MountedDirCount="$(mount | grep $CHROOT_DIR | wc -l)"

start() {
	if [ $MountedDirCount -gt 0 ]; then
		logger 'Debian services seems to be already started, exiting...'
		exit 1
	fi
	logger 'Starting Debian services...'
	for dir in dev dev/pts proc sys opt/etc; do
		mount -o bind /$dir $CHROOT_DIR/$dir
	done

	# Создаем /dev/fd, если отсутствует (нужно для bash <(...))
	[ -e /dev/fd ] || ln -s /proc/self/fd /dev/fd

	[ -z "$EXT_DIR" ] || mount -o bind $EXT_DIR $CHROOT_DIR/media
	for item in $(cat $CHROOT_SERVICES_LIST); do
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/sbin \
		LC_ALL=C \
		LANGUAGE=C \
		LANG=C \
		chroot $CHROOT_DIR /etc/init.d/$item start
	done
}

stop() {
	if [ $MountedDirCount -eq 0 ]; then
		logger 'Debian services seems to be already stopped, exiting...'
		exit 1
	fi
	logger 'Stopping Debian services...'
	for item in $(cat $CHROOT_SERVICES_LIST); do
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/sbin \
		LC_ALL=C \
		LANGUAGE=C \
		LANG=C \
		chroot $CHROOT_DIR /etc/init.d/$item stop
	done
	umount $CHROOT_DIR/dev/pts
	mount | grep $CHROOT_DIR | awk "{print \$3}" | xargs umount
}

status() {
	if [ $MountedDirCount -gt 0 ]; then
		echo 'Debian services is running'
	else
		echo 'Debian services is stopped'
	fi
}

case "$1" in
	start)
		start
	;;
	stop)
		stop
	;;
	restart)
		stop
		sleep 5
		start
	;;
	status)
		status
	;;
	*)
		echo "Usage: $0 (start|stop|restart|status)"
		exit 1
	;;
esac

echo 'Done.'
exit 0
EOF

chmod +x /opt/etc/init.d/S99debian
/opt/etc/init.d/S99debian start

# Создаем файл со списком сервисов (пример)
# cat > /opt/debian/debian/chroot-services.list << 'EOF'
# Примеры сервисов (раскомментируйте нужные)
# ssh
# cron
# nginx
# EOF

echo "Установка завершена!"
echo "Для входа в Debian используйте: debian"
echo "Для управления сервисом Debian: /opt/etc/init.d/S99debian {start|stop|restart|status}"
```
входим и обновляем ресурсы
``` 
debian
apt update
apt install -y wget curl
```
добавить шим systemctl вместо заглушки
```
mkdir -p /usr/local/sbin
cat > /usr/local/sbin/systemctl << 'SCRIPTEOF'
#!/bin/bash
UNIT_DIR="/etc/systemd/system"
RUN_DIR="/run/fake-systemd"
mkdir -p "$RUN_DIR"

find_unit() {
  local name="$1"
  for d in "$UNIT_DIR" /lib/systemd/system /usr/lib/systemd/system; do
    [ -f "$d/$name" ] && { echo "$d/$name"; return 0; }
  done
  return 1
}
get_field() {
  local file="$1" field="$2"
  grep -E "^${field}=" "$file" | head -1 | cut -d= -f2-
}
pidfile() { echo "$RUN_DIR/$1.pid"; }

do_start() {
  local svc="$1.service"
  local unit; unit="$(find_unit "$svc")" || { echo "Unit $svc not found"; return 1; }
  local pf; pf="$(pidfile "$1")"
  if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then
    echo "$1 already running"; return 0
  fi
  local execstart; execstart="$(get_field "$unit" ExecStart)"
  [ -n "$execstart" ] || { echo "No ExecStart in $unit"; return 1; }
  nohup $execstart >> "$RUN_DIR/$1.log" 2>&1 &
  echo $! > "$pf"
  echo "Started $1 (pid $(cat "$pf"))"
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

cmd="$1"; shift
case "$cmd" in
  start)   for s in "$@"; do do_start "${s%.service}"; done ;;
  stop)    for s in "$@"; do do_stop "${s%.service}"; done ;;
  restart) for s in "$@"; do do_stop "${s%.service}"; sleep 1; do_start "${s%.service}"; done ;;
  status)  for s in "$@"; do do_status "${s%.service}"; done ;;
  is-active)
    pf="$(pidfile "${1%.service}")"
    if [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then echo active; exit 0
    else echo inactive; exit 3; fi ;;
  enable|disable|daemon-reload|daemon-reexec|reset-failed|mask|unmask)
    echo "Running in chroot, ignoring command '$cmd'"; exit 0 ;;
  list-unit-files|list-units)
    ls "$UNIT_DIR" 2>/dev/null ;;
  *) echo "systemctl-shim: unsupported command '$cmd'"; exit 0 ;;
esac
SCRIPTEOF
chmod +x /usr/local/sbin/systemctl

```
ставим по желанию ndmq и подмену на привычный ndmc
``` 
debian
cd /root
wget https://raw.githubusercontent.com/The-BB/debian-keenetic/refs/heads/master/EOL/ndmq-aarch64_bullseye.tgz
tar -xzf ndmq-aarch64_bullseye.tgz -C /
ls -l /usr/local/bin/ndmq
ls -l /usr/local/lib/libndm.so
ldconfig
ldd /usr/local/bin/ndmq
ndmq -v
ndmq -help
cat > /usr/local/bin/ndmc << 'EOF'
#!/bin/sh

# /usr/local/bin/ndmc
# chmod +x /usr/local/bin/ndmc

if [ "$1" = "-c" ]; then
    shift
    ndmq -p "$*" -x | sed \
        -e 's/<response>//' \
        -e 's#</response>##' \
        -e 's#<prompt>.*</prompt>##'
else
    ndmq -x
fi
EOF
chmod +x /usr/local/bin/ndmc
ndmc -c show version
```
запускаем дебиан и входим такой командой
```
debian
```
выход такой командой
```
exit
```
красивая заставка debian при входе
```
cat > /etc/profile.d/welcome.sh << 'EOF'
#!/bin/bash
[ -n "$PS1" ] || return

echo ""
echo -e "\e[36m"
cat << 'BANNER'
  ██████╗ ███████╗██████╗ ██╗ █████╗ ███╗   ██╗
  ██╔══██╗██╔════╝██╔══██╗██║██╔══██╗████╗  ██║
  ██║  ██║█████╗  ██████╔╝██║███████║██╔██╗ ██║
  ██║  ██║██╔══╝  ██╔══██╗██║██╔══██║██║╚██╗██║
  ██████╔╝███████╗██████╔╝██║██║  ██║██║ ╚████║
  ╚═════╝ ╚══════╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

  chroot Debian на Keenetic с Entware
BANNER
echo -e "\e[0m"

TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -n "$TEMP" ] && echo "  Температура CPU: $((TEMP/1000))°C"

if command -v ndmc >/dev/null 2>&1; then
  VERSION_XML=$(ndmc -c "show version" 2>/dev/null)
  MODEL=$(echo "$VERSION_XML" | grep -oP '(?<=<model>).*?(?=</model>)')
  RELEASE=$(echo "$VERSION_XML" | grep -oP '(?<=<title>).*?(?=</title>)')
  [ -n "$MODEL" ] && echo "  Модель роутера: $MODEL"
  [ -n "$RELEASE" ] && echo "  Прошивка: $RELEASE"
fi

echo ""
EOF
chmod +x /etc/profile.d/welcome.sh
``` 

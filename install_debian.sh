#!/bin/sh

echo "Обновление списка пакетов..."
opkg update
echo "Установка tar curl и wget-ssl..."
opkg install ca-certificates curl wget-ssl tar
echo "Удаление wget-nossl"
opkg remove wget-nossl 2>/dev/null
echo "Остановка и удаление старого Debian"
/opt/etc/init.d/S99debian stop 2>/dev/null
sleep 5
rm -rf /opt/debian 2>&1 || true
rm -rf /opt/bin/debian 2>&1 || true
rm -rf /opt/etc/init.d/S99debian 2>&1 || true
echo "Определение архитектуры роутера..."

ARCH=$(opkg print-architecture | awk '
/^arch/ && $2 !~ /_kn$/ && $2 ~ /-[0-9]+\.[0-9]+$/ {print $2; exit}
')

if [ -z "$ARCH" ]; then
    echo "Ошибка определения архитектуры!"
    exit 1
fi

case "$ARCH" in
    aarch64-3.10)
        FEED_URL="debian-trixie-13.3-aarch64.tar.gz"
        NDMC_URL="ndmq-aarch64_bullseye.tgz"
    ;;
    mipsel-3.4)
        FEED_URL="debian-bookworm-12.13-mipsel.tar.gz"
        NDMC_URL="ndmq-mipsel_buster.tgz"
    ;;
    mips-3.4)
        FEED_URL="debian-buster-10.13-mips.tar.gz"
        NDMC_URL="ndmq-mips_buster.tgz"
    ;;
    *)
        echo "Не поддерживаемая архитектура: $ARCH"
        exit 1
    ;;
esac


echo "Определена архитектура: $ARCH"

cd /opt/root
rm -rf $FEED_URL 2>&1 || true
rm -rf $NDMC_URL 2>&1 || true
echo "Скачиваю архив Debian: $FEED_URL"
wget http://ndm.zyxmon.org/binaries/debian/$FEED_URL
echo "Распаковываю архив Debian: $FEED_URL"
mkdir -p /opt/debian
tar -xzf /opt/root/$FEED_URL -C /opt/debian

echo "Создаем скрипт входа в Debian: /opt/bin/debian"

cat > /opt/bin/debian << 'EOF'
#!/bin/sh
LANG=C LC_ALL=C chroot /opt/debian/debian /bin/bash -l -c "cd /root && exec /bin/bash -l"
EOF

chmod +x /opt/bin/debian

echo "Создаем init скрипт: /opt/etc/init.d/S99debian"

cat > /opt/etc/init.d/S99debian << 'EOF'
#!/bin/sh

PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin

CHROOT_DIR=/opt/debian/debian
CHROOT_SERVICES_LIST=$CHROOT_DIR/chroot-services.list

start() {

MountedDirCount=$(mount | grep $CHROOT_DIR | wc -l)

if [ $MountedDirCount -gt 0 ]; then
logger "Debian already started"
exit 1
fi

logger "Starting Debian"

for dir in dev dev/pts proc sys; do
mount -o bind /$dir $CHROOT_DIR/$dir
done

mount -o bind /opt/debian/etc $CHROOT_DIR/opt/etc

for item in $(cat $CHROOT_SERVICES_LIST); do
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/sbin:/opt/bin
LC_ALL=C
LANG=C
chroot $CHROOT_DIR /etc/init.d/$item start
done

}

stop() {

MountedDirCount=$(mount | grep $CHROOT_DIR | wc -l)

if [ $MountedDirCount -eq 0 ]; then
logger "Debian already stopped"
exit 1
fi

logger "Stopping Debian"

for item in $(cat $CHROOT_SERVICES_LIST); do
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/sbin:/opt/bin
LC_ALL=C
LANG=C
chroot $CHROOT_DIR /etc/init.d/$item stop
done

umount $CHROOT_DIR/dev/pts
mount | grep $CHROOT_DIR | awk '{print $3}' | xargs umount

}

case "$1" in
start) start ;;
stop) stop ;;
restart)
stop
sleep 3
start
;;
status)
mount | grep $CHROOT_DIR >/dev/null && echo "running" || echo "stopped"
;;
*)
echo "Usage: $0 {start|stop|restart|status}"
exit 1
;;
esac

exit 0$NDMC_URL
EOF
echo "Запускаем Debian в системе"
chmod +x /opt/etc/init.d/S99debian
/opt/etc/init.d/S99debian start

echo "Скачиваем ndmq: $NDMC_URL"

wget https://raw.githubusercontent.com/The-BB/debian-keenetic/refs/heads/master/EOL/$NDMC_URL
echo "Перемещаю архив в Debian: $NDMC_URL"
mv /opt/root/$NDMC_URL /opt/debian/debian/root/ndmq.tgz

echo "Скачиваем ndmc установщик: install-debian-ndmq-ndmc.sh"

wget https://raw.githubusercontent.com/pegakmop/entware-debian-alpine/refs/heads/main/install-debian-ndmq-ndmc.sh
echo "Перемещаю архив в Debian: install-debian-ndmq-ndmc.sh"
mv /opt/root/install-debian-ndmq-ndmc.sh /opt/debian/debian/root/install-debian-ndmq-ndmc.sh
chmod +x /opt/debian/debian/root/install-debian-ndmq-ndmc.sh
echo "Debian установлен как дополнение в Entware"
echo "После входа в Debian выполнить установку ndmc командой:"
echo "./install-debian-ndmq-ndmc.sh"
echo "Вход командой: debian"
echo "Выйти из Debian: exit"
echo "Установка завершена"

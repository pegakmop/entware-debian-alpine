установка и настройка алпайн допом к ентвару только для архитектуры **aarch64**
```
opkg update
opkg install ca-certificates wget-ssl curl
# скачиваем архив
cd /opt/root/
wget https://github.com/ryzhovau/keenetic-alpine/releases/download/v0.2/install-alpine-minirootfs-3.21.0-aarch64.tar.gz
# создаем папки
mkdir -p /opt/alpine
mkdir -p /opt/alpine/dev /opt/alpine/proc /opt/alpine/sys
# распакуем архив
tar -xzf install-alpine-minirootfs-3.21.0-aarch64.tar.gz -C /opt/alpine
# создании запуск
cat > /opt/bin/alpine << 'EOF'
#!/bin/sh

CHROOT=/opt/alpine

mount -o bind /dev $CHROOT/dev 2>/dev/null
mount -t proc proc $CHROOT/proc 2>/dev/null
mount -t sysfs sys $CHROOT/sys 2>/dev/null

chroot $CHROOT /bin/sh -l -c "cd /root && exec /bin/sh"
EOF
# даем права
chmod +x /opt/bin/alpine
# запуск 🚀 
alpine
apk update
apk upgrade
exit
# настроен и установлен alpine
``` 

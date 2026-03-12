Установка Debian в Entware под вашу архитектуру
```
cd /opt/root && wget https://raw.githubusercontent.com/pegakmop/entware-debian-alpine/refs/heads/main/install_debian.sh && chmod +x install_debian.sh && ./install_debian.sh
```  
Войти в Debian
```
debian
```
Выйти из Debian
```
exit
```
Перезапустить Debian на случай если не запустился
```
/opt/etc/init.d/S99debian restart
```
Остановить совсем Debian на случай если не сейчас не нужен
```
/opt/etc/init.d/S99debian stop
```
Удалить Debian из entware
```
/opt/etc/init.d/S99debian stop 2>&1 || true && rm -rf /opt/bin/debian 2>&1 || true && rm -rf /opt/etc/init.d/S99debian 2>&1 || true && rm -rf /opt/debian 2>&1 || true && echo "Остановка и удаление Debian из Entware завершено"
``` 

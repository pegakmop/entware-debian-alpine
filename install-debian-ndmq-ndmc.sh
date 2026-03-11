#!/bin/sh

echo "Обновление списка пакетов..."
apt update

echo "Установка tar curl и wget-ssl..."
apt install -y curl wget tar

tar -xzf ndmq.tgz -C /
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
echo "ndmc -c show version"
ndmc -c show version

#!/bin/bash

if [ -z "$1" ]; then
    echo "Использование: ./create_client.sh CLIENT_NAME [CLIENT_IP]"
    echo "Пример: ./create_client.sh employee1"
    echo "        ./create_client.sh employee1 10.8.0.10"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP=${2:-auto}

echo "🔐 Создание VPN клиента: $CLIENT_NAME"

# Создать директорию если нет
mkdir -p openvpn/clients

# Создать клиентский сертификат
docker run -v $PWD/openvpn/config:/etc/openvpn --rm -it kylemanna/openvpn \
    easyrsa build-client-full $CLIENT_NAME nopass

# Экспортировать базовую конфигурацию
docker run -v $PWD/openvpn/config:/etc/openvpn --rm kylemanna/openvpn \
    ovpn_getclient $CLIENT_NAME > ./openvpn/clients/$CLIENT_NAME.ovpn

# Добавить дополнительные настройки для локальной сети
cat >> ./openvpn/clients/$CLIENT_NAME.ovpn << CLIENTCONF

# --- Local Network Extras ---
# Локальная сеть Docker
route 172.20.0.0 255.255.0.0

# DNS через наш сервер
dhcp-option DNS 172.20.0.2

# Компрессия
compress lz4-v2

# Keepalive
keepalive 10 120

# Разрешить доступ к локальной сети клиента (не пускать весь трафик в туннель, если не нужно)
# Если вы хотите, чтобы ВЕСЬ трафик шел через VPN, раскомментируйте redirect-gateway
# redirect-gateway def1

# Но для доступа к локальным ресурсам достаточно маршрутов:
route 10.8.0.0 255.255.255.0
CLIENTCONF

# Если указан статический IP
if [ "$CLIENT_IP" != "auto" ]; then
    echo ""
    echo "⚠️  Для назначения статического IP ($CLIENT_IP) выполняем настройку..."
    mkdir -p openvpn/config/ccd
    echo "ifconfig-push $CLIENT_IP 255.255.255.0" > openvpn/config/ccd/$CLIENT_NAME
    echo "CCD config created."
fi

echo ""
echo "✅ Клиент создан!"
echo "📁 Файл: ./openvpn/clients/$CLIENT_NAME.ovpn"
echo ""
echo "📋 Доступные сервисы после подключения:"
echo "  whier-app:      http://172.20.0.10:3000  или http://whier.local:3000 "
echo "  File Server:    \\\\172.20.0.20\\shared или \\\\files.local\\shared"
echo "  Другие клиенты: 10.8.0.x"

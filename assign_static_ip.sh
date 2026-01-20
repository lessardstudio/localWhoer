#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Использование: ./assign_static_ip.sh CLIENT_NAME IP_ADDRESS"
    echo "Пример: ./assign_static_ip.sh employee1 10.8.0.100"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP=$2

echo "📌 Назначение статического IP: $CLIENT_NAME → $CLIENT_IP"

# Создать директорию для клиентских конфигураций
mkdir -p openvpn/config/ccd

# Создать файл конфигурации
echo "ifconfig-push $CLIENT_IP 255.255.255.0" > openvpn/config/ccd/$CLIENT_NAME

# Обновить server.conf, если директива отсутствует
docker exec openvpn-server bash -c "
if ! grep -q 'client-config-dir' /etc/openvpn/openvpn.conf; then
    echo 'client-config-dir /etc/openvpn/ccd' >> /etc/openvpn/openvpn.conf
    echo 'Added client-config-dir directive.'
fi
"

# Перезапустить OpenVPN
if docker compose version &> /dev/null; then
    docker compose restart openvpn
else
    docker-compose restart openvpn
fi

echo "✅ Статический IP назначен!"
echo "Клиент $CLIENT_NAME будет получать IP: $CLIENT_IP"
echo ""
echo "⚠️  Клиенту нужно переподключиться к VPN"

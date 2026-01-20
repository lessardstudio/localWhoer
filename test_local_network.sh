#!/bin/bash

echo "=== 🧪 Тест локальной VPN сети ==="
echo ""

# 1. Получить IP контейнеров
WHIER_IP=$(docker inspect whier-app | grep '"IPAddress"' | tail -1 | awk '{print $2}' | tr -d '",')
FILES_IP=$(docker inspect file-server 2>/dev/null | grep '"IPAddress"' | tail -1 | awk '{print $2}' | tr -d '",')

echo "📍 IP адреса сервисов:"
echo "  whier-app: $WHIER_IP"
[ ! -z "$FILES_IP" ] && echo "  File Server: $FILES_IP"
echo ""

# 2. Тест из контейнера OpenVPN
echo "🔍 Тест доступности изнутри VPN:"
docker exec openvpn-server sh -c "
    ping -c 1 $WHIER_IP >/dev/null 2>&1 && echo '✅ whier-app доступен' || echo '❌ whier-app недоступен'
    ping -c 1 172.20.0.2 >/dev/null 2>&1 && echo '✅ DNS сервер доступен' || echo '❌ DNS недоступен'
"

echo ""
echo "📋 Для клиентов VPN:"
echo ""
echo "Доступные адреса:"
echo "  whier-app:      http://$WHIER_IP:3000 "
echo "                  http://whier.local:3000 "
[ ! -z "$FILES_IP" ] && echo "  File Server:    \\\\$FILES_IP\\shared"
[ ! -z "$FILES_IP" ] && echo "                  \\\\files.local\\shared"
echo "  Другие клиенты: 10.8.0.X"
echo ""
echo "Команды для проверки (на клиенте после подключения):"
echo "  ping $WHIER_IP"
echo "  curl http://$WHIER_IP:3000 "
echo "  ping 10.8.0.1  # VPN сервер"

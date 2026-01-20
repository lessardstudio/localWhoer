#!/bin/bash

echo "=== 🌐 Мониторинг VPN сети ==="
echo ""

# 1. Подключенные клиенты
echo "👥 Подключенные клиенты:"
# В kylemanna/openvpn статус лог по умолчанию в /tmp/openvpn-status.log или /etc/openvpn/openvpn-status.log
# Нужно проверить конфиг. Обычно ovpn_genconfig ставит статус лог.
docker exec openvpn-server cat /tmp/openvpn-status.log 2>/dev/null | \
    grep "^CLIENT_LIST" | \
    awk -F',' '{print $2 " (" $3 ") - " $4 " bytes in, " $5 " bytes out"}' || \
    echo "Нет активных подключений или лог недоступен"

echo ""

# 2. Активные сервисы в Docker сети
echo "🖥️  Сервисы в локальной сети:"
if command -v jq &> /dev/null; then
    docker network inspect vpn-network | \
        jq -r '.[] | .Containers | to_entries[] | "\(.value.Name) - \(.value.IPv4Address)"' 2>/dev/null
else
    docker network inspect vpn-network | grep -A 10 "Containers"
fi

echo ""

# 3. Доступность сервисов (ping изнутри контейнера VPN)
echo "🔍 Проверка доступности (Internal Check):"
docker exec openvpn-server ping -c 1 172.20.0.10 >/dev/null 2>&1 && \
    echo "✅ whier-app (172.20.0.10) доступен" || echo "❌ whier-app недоступен"

docker exec openvpn-server ping -c 1 172.20.0.20 >/dev/null 2>&1 && \
    echo "✅ File Server (172.20.0.20) доступен" || echo "❌ File Server недоступен"

docker exec openvpn-server ping -c 1 172.20.0.2 >/dev/null 2>&1 && \
    echo "✅ DNS Server (172.20.0.2) доступен" || echo "❌ DNS Server недоступен"

echo ""

# 4. Логи (ошибки)
echo "📝 Последние ошибки в логах:"
docker logs openvpn-server --tail 20 2>&1 | grep -i "error" || echo "Ошибок в последних 20 строках не найдено."

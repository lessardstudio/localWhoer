#!/bin/bash

set -e

echo "🚀 Запуск полного стека VPN + FastAPI..."
echo ""

# Определение команды Docker Compose
if docker compose version &> /dev/null; then
    DC_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DC_CMD="docker-compose"
else
    echo "Error: Neither 'docker compose' nor 'docker-compose' found."
    echo "Please install Docker Compose."
    exit 1
fi

echo "Using Docker Compose command: $DC_CMD"

# 1. Исправление проблем с файлами (Fix: "not a directory" error)
if [ -d "dns/dnsmasq.conf" ]; then
    echo "⚠️  Обнаружено, что dns/dnsmasq.conf является директорией. Исправляем..."
    rm -rf dns/dnsmasq.conf
fi

# 2. Проверка наличия конфига DNS
if [ ! -f "dns/dnsmasq.conf" ]; then
    echo "🔧 Создание конфигурации DNS..."
    mkdir -p dns
    cat > dns/dnsmasq.conf << DNSCONF
# Локальные DNS записи
address=/whier.local/172.20.0.10
address=/files.local/172.20.0.20
address=/vpn.local/172.20.0.5

# Upstream DNS
server=8.8.8.8
server=1.1.1.1

# Локальный домен
domain=vpn.local
DNSCONF
fi

# 3. Инициализация VPN (если еще не сделано)
if [ ! -f "openvpn/config/openvpn.conf" ]; then
    echo "🔧 Инициализация OpenVPN..."
    ./setup_vpn_network.sh
fi

# Fix permissions for docker socket (to allow FastAPI to manage OpenVPN)
echo "🔑 Настройка прав доступа к Docker socket..."
chmod 666 /var/run/docker.sock || echo "⚠️ Не удалось изменить права на docker.sock (возможно, нужны права root)"

# 4. Запуск всех сервисов
echo "🐳 Запуск Docker контейнеров..."
$DC_CMD down
$DC_CMD up -d --build

echo ""
echo "⏳ Ожидание запуска сервисов (30 сек)..."
sleep 30

echo ""
echo "✅ Стек запущен!"
echo ""
echo "📋 Доступные сервисы:"
echo ""
echo "1. Swagger UI (REST API документация):"
echo "   ssh -L 8000:127.0.0.1:8000 root@YOUR_SERVER_IP"
echo "   Затем откройте: http://localhost:8000/docs"
echo ""
echo "2. ReDoc (альтернативная документация):"
echo "   http://localhost:8000/redoc"
echo ""
echo "3. whier-app:"
echo "   http://172.20.0.10:3000 (через VPN)"
echo ""
echo "4. API Key для запросов:"
echo "   Authorization: Bearer $(grep API_KEY .env | cut -d'=' -f2)"
echo ""
echo "🧪 Тестовый запрос:"
echo "   curl -H 'Authorization: Bearer $(grep API_KEY .env | cut -d'=' -f2)' http://localhost:8000/api/v1/vpn/status"

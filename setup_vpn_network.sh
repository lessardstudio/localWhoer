#!/bin/bash

set -e

# Определение внешнего IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com)

echo "=== 🌐 Создание локальной VPN сети на VPS ==="
echo "📍 Внешний IP: $SERVER_IP"
echo ""

# 1. Создать структуру директорий
echo "📁 Создание директорий..."
mkdir -p openvpn/{config,clients}
mkdir -p shared
mkdir -p dns
chmod -R 755 openvpn/ shared/ dns/

# 2. Остановить старые контейнеры
echo "⏹️  Останавливаем старые контейнеры..."
if docker compose version &> /dev/null; then
    docker compose down --remove-orphans || true
else
    docker-compose down --remove-orphans || true
fi

# Очистка старых данных (Опционально, раскомментируйте если нужно сбросить всё)
# rm -rf openvpn/config/*

# 3. Создать базовую конфигурацию OpenVPN (если её нет)
if [ ! -f openvpn/config/openvpn.conf ]; then
    echo "⚙️  Генерация конфигурации OpenVPN..."
    docker run -v $PWD/openvpn/config:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig \
        -u udp://$SERVER_IP:1194 \
        -s 10.8.0.0/24 \
        -p "route 172.20.0.0 255.255.0.0" \
        -p "push \"route 172.20.0.0 255.255.0.0\"" \
        -n 172.20.0.2 \
        -d
else
    echo "⚙️  Конфигурация уже существует, пропускаем генерацию."
fi

# 4. Инициализировать PKI (если нет CA)
if [ ! -f openvpn/config/pki/ca.crt ]; then
    echo "🔐 Инициализация PKI (нажмите Enter для всех вопросов)..."
    docker run -v $PWD/openvpn/config:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki nopass
else
    echo "🔐 PKI уже инициализирован."
fi

# 5. Добавить дополнительные настройки
echo "📝 Настройка client-to-client и оптимизаций..."
docker run -v $PWD/openvpn/config:/etc/openvpn --rm kylemanna/openvpn bash -c '
# Проверяем, есть ли уже настройки, чтобы не дублировать
if ! grep -q "client-to-client" /etc/openvpn/openvpn.conf; then
cat >> /etc/openvpn/openvpn.conf << CONF

# --- Local Network Config ---
# Разрешить клиентам общаться друг с другом
client-to-client

# Разрешить дублирование подключений (удобно для тестов)
duplicate-cn

# Компрессия
compress lz4-v2
push "compress lz4-v2"

# Keepalive
keepalive 10 120

# Дополнительные маршруты
push "route 172.20.0.0 255.255.0.0"

# MTU
tun-mtu 1500
mssfix 1450
CONF
fi
'

# 6. DNS конфигурация
echo "📝 Настройка DNS..."
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

# 7. Настройка UFW (Файрвол)
echo "🔒 Настройка файрвола (UFW)..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 1194/udp comment 'OpenVPN'
    
    # Блокируем прямой доступ к портам сервисов (они должны быть доступны только через VPN или localhost)
    sudo ufw deny 3000/tcp comment 'Block whier direct access'
    sudo ufw deny 445/tcp comment 'Block Samba direct access'
    sudo ufw deny 53/udp comment 'Block DNS direct access'
    
    # Включаем (если еще не включен, осторожно, чтобы не потерять SSH!)
    # sudo ufw --force enable
    echo "   UFW правила обновлены. Убедитесь, что SSH разрешен, прежде чем включать UFW."
else
    echo "   UFW не найден, пропускаем."
fi

# 8. Настроить IP forwarding и NAT (через скрипт хоста)
echo "🔀 Настройка маршрутизации (sysctl)..."
sudo sysctl -w net.ipv4.ip_forward=1 || echo "Не удалось установить sysctl (нужны права root)"

# 9. Запустить все сервисы
echo "🚀 Запуск сервисов..."
if docker compose version &> /dev/null; then
    docker compose up -d
else
    docker-compose up -d
fi

echo ""
echo "✅ Локальная VPN сеть создана!"
echo ""
echo "📋 Информация о сети:"
echo "  VPN подсеть:    10.8.0.0/24"
echo "  Docker подсеть: 172.20.0.0/16"
echo "  whier-app:      172.20.0.10 (http://whier.local:3000)"
echo "  File Server:    172.20.0.20 (files.local)"
echo "  DNS Server:     172.20.0.2"
echo ""
echo "Следующие шаги:"
echo "  1. Создайте клиентов: ./create_client.sh employee1"
echo "  2. Раздайте .ovpn файлы сотрудникам"

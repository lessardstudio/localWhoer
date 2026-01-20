#!/bin/bash
set -e

echo "🚀 Запуск whier-app с VPN защитой..."

# 1. Проверка SSH порта перед настройкой UFW
SSH_PORT=$(ss -tlnp | grep sshd | awk '{print $4}' | awk -F':' '{print $NF}' | head -n1)
SSH_PORT=${SSH_PORT:-22}

# 2. Остановить старые контейнеры
echo "⏹️  Останавливаем старые контейнеры..."
docker-compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# 3. Пересобрать и запустить
echo "🔨 Сборка и запуск..."
# Здесь важно, чтобы в docker-compose.yml было 127.0.0.1:3000:3000
docker-compose up -d --build || docker-compose up -d --build

# 4. Настройка файрвола (БЕЗ полного reset, чтобы не вылететь)
echo "🔒 Настройка файрвола (SSH порт: $SSH_PORT)..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$SSH_PORT"/tcp comment 'SSH'
sudo ufw allow 1935/udp comment 'Hysteria2'
sudo ufw deny 3000/tcp comment 'Block direct access'
sudo ufw --force enable

# 5. Перезапуск Hysteria2
echo "🔄 Перезапуск Hysteria2..."
if systemctl is-active --quiet hysteria-server; then
    sudo systemctl restart hysteria-server
    echo "✅ Hysteria2 перезапущен (systemd)"
elif docker ps | grep -q hysteria; then
    docker restart $(docker ps -q -f name=hysteria)
    echo "✅ Hysteria2 перезапущен (docker)"
else
    echo "⚠️  Hysteria2 не найден. Убедитесь, что он настроен на проксирование 127.0.0.1:3000"
fi

echo "✅ Готово! Проверьте статус командой ./check_security.sh"
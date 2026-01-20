#!/bin/bash

echo "🔄 Обновление whier-app..."

# 1. Остановить старый контейнер
docker-compose down

# 2. Запустить с новой конфигурацией
docker-compose up -d --build

# 3. Настроить файрвол
echo "🔒 Настройка UFW..."
sudo ufw allow 22/tcp
sudo ufw allow 1935/udp
sudo ufw deny 3000/tcp
sudo ufw --force enable

# 4. Перезапустить Blitz/Hysteria2
echo "🔄 Перезапуск Hysteria2..."
sudo systemctl restart hysteria-server
# ИЛИ если Blitz в Docker:
# docker restart blitz-hysteria2

echo "✅ Готово!"
echo ""
echo "Проверка:"
echo "- Порт 3000 извне должен быть ЗАКРЫТ"
echo "- Доступ к whier-app только через VPN"
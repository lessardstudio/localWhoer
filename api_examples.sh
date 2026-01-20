#!/bin/bash

API_KEY=$(grep API_KEY .env | cut -d'=' -f2)
BASE_URL="http://localhost:8000/api/v1"

echo "=== 📡 Примеры использования VPN Management API ==="
echo ""
echo "API Key: $API_KEY"
echo ""

# 1. Проверка здоровья
echo "1️⃣ Health Check:"
curl -s http://localhost:8000/health | jq .
echo ""

# 2. Статус VPN
echo "2️⃣ VPN Status:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/vpn/status | jq .
echo ""

# 3. Подключенные клиенты
echo "3️⃣ Connected Clients:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/vpn/connected-clients | jq .
echo ""

# 4. Список клиентов
echo "4️⃣ All Clients:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/clients/list | jq .
echo ""

# 5. Создать клиента
echo "5️⃣ Create Client (testuser):"
curl -s -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"testuser","email":"test@example.com"}' \
  $BASE_URL/clients/create | jq .
echo ""

# 6. Скачать конфиг
echo "6️⃣ Download Config:"
echo "curl -H 'Authorization: Bearer $API_KEY' $BASE_URL/clients/download/testuser -o testuser.ovpn"
echo ""

# 7. Статистика
echo "7️⃣ VPN Statistics:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/vpn/stats | jq .
echo ""

# 8. Сервисы
echo "8️⃣ Services List:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/services/list | jq .
echo ""

# 9. Network Info
echo "9️⃣ Network Info:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/network/info | jq .

# Деплой на сервере (VPS)

Этот проект поднимает корпоративный доступ к Whier через OpenVPN.

Архитектура:
- OpenVPN сервер (UDP `1194`) выдаёт клиентам маршрут до Docker-сети с Whier.
- Whier доступен только из VPN (порт наружу не публикуется).
- OpenVPN UI доступен только с localhost VPS (через SSH-туннель).

## Требования

- VPS с публичным IPv4.
- Docker Engine и Docker Compose v2.
- Открытый порт `1194/udp` на VPS (в панели провайдера/фаерволе).
- Открытый порт `22/tcp` для SSH.

Проверка на сервере:
```bash
docker version
docker compose version
```

## Установка Docker Compose v2 (если нет)

Рекомендуется Compose v2 (команда `docker compose`, без дефиса).

Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

Если пакет недоступен — установи бинарник Compose v2:
```bash
sudo curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

docker-compose version
```

## Деплой

1) Клонируй репозиторий на VPS:
```bash
git clone https://github.com/lessardstudio/localWhoer.git
cd localWhoer
```

2) Создай файл `.env` (пример есть в `.env.example`) (для пароля админки OpenVPN UI):
```bash
cat > .env << 'EOF'
ADMIN_PASSWORD=ChangeMe123!
OPENVPN_UI_PORT=8080
EOF
```

3) Подними сервисы:
```bash
docker compose pull
docker compose up -d --build
```

4) Проверь, что контейнеры запущены:
```bash
docker ps
```

Ожидаемые контейнеры:
- `openvpn-server`
- `openvpn-ui`
- `whier-app`

## Доступ к OpenVPN UI

UI слушает только `127.0.0.1:8080` на VPS.

Если порт занят, поменяй `OPENVPN_UI_PORT` в `.env` (например, на `8081`).

С локального ПК открой SSH-туннель:
```bash
ssh -L 8080:127.0.0.1:8080 root@<VPS_IP>
```

Открой в браузере:
- `http://127.0.0.1:8080`

Логин:
- Username: `admin`
- Password: значение `ADMIN_PASSWORD` из `.env`

## Подключение OpenVPN клиента

1) В OpenVPN UI создай пользователя/клиента и скачай `.ovpn`.
2) Импортируй `.ovpn` в OpenVPN Connect (Windows/macOS/iOS/Android) или любой OpenVPN клиент.
3) Подключись.

## Доступ к Whier через VPN

Whier не публикует порт наружу. Он доступен только из VPN по IP в Docker-сети.

Открой в браузере (после подключения OpenVPN):
- `http://172.21.0.11:3000`

Примечание:
- Подсеть задаётся в [docker-compose.yml](file:///c:/Users/User/Desktop/localWhoer/docker-compose.yml) (сеть `vpn-network`).

## Важно про безопасность

- Не публикуй `8080/tcp` наружу (UI только через SSH туннель).
- Оставляй наружу только `1194/udp` и `22/tcp`.

## Troubleshooting

### 1) `Pool overlaps with other one on this address space`

Значит выбранная подсеть Docker уже занята другой сетью.

Быстрый фикс:
```bash
docker network ls
docker network inspect <network_name>
```

Если мешает старая сеть проекта:
```bash
docker compose down
docker network rm localwhoer_vpn-network 2>/dev/null || true
docker network prune -f
docker compose up -d --build
```

Либо измени подсеть `vpn-network` в [docker-compose.yml](file:///c:/Users/User/Desktop/localWhoer/docker-compose.yml).

### 2) OpenVPN подключился, но Whier не открывается

Проверь:
```bash
docker exec -it openvpn-server ip route
docker exec -it openvpn-server iptables -S
```

Также убедись, что `HOME_SUB` в `openvpn-server` совпадает с подсетью `vpn-network` в compose.

### 3) Docker Compose не запускается из-за Python (`distutils`)

Используй Docker Compose v2 (`docker compose ...`). Старый `docker-compose` (Python) может ломаться на Python 3.12.


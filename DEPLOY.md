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

## Быстрый старт

1) Клонируй репозиторий на VPS:
```bash
git clone https://github.com/lessardstudio/localWhoer.git
cd localWhoer
```

2) Создай файл `.env` (для пароля админки OpenVPN UI):
```bash
cat > .env << 'EOF'
ADMIN_PASSWORD=ChangeMe123!
OPENVPN_UI_PORT=8080
EOF
```

3) Запусти скрипт установки (он поднимет контейнеры и инициализирует ключи):
```bash
chmod +x init-vpn.sh
./init-vpn.sh
```

4) Проверь, что контейнеры запущены:
```bash
docker ps
```
Ожидаемые контейнеры: `openvpn-server`, `openvpn-ui`, `whier-app`.

## Доступ к OpenVPN UI

UI слушает только `127.0.0.1:8080` на VPS.
С локального ПК открой SSH-туннель:
```bash
ssh -L 8080:127.0.0.1:8080 root@<VPS_IP>
```

Открой в браузере: **http://127.0.0.1:8080**
Логин: `admin` / Пароль: из `.env`.

## Подключение

1) В UI создай пользователя и скачай `.ovpn`.
2) Импортируй в OpenVPN Connect.
3) Whier доступен по адресу: **http://172.21.0.11:3000**

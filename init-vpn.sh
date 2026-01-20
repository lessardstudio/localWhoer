#!/bin/bash

# Остановка при ошибке
set -e

echo "=== Starting OpenVPN Deployment ==="

# 1. Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Please install Docker first."
    exit 1
fi

# 2. Запуск контейнеров
echo "Starting containers..."
docker compose pull
docker compose up -d

echo "Waiting for containers to initialize (10s)..."
sleep 10

# 3. Инициализация PKI (если еще не создана)
if ! docker exec openvpn-ui ls /usr/share/easy-rsa/pki/ca.crt &> /dev/null; then
    echo "Initializing PKI..."

    # Создаем конфигурацию vars
    docker exec openvpn-ui sh -c 'cp /usr/share/easy-rsa/vars.example /etc/openvpn/easy-rsa.vars' || true
    
    # Инициализируем PKI
    echo "Init PKI..."
    docker exec -e EASYRSA_BATCH=1 openvpn-ui /usr/share/easy-rsa/easyrsa --pki-dir=/usr/share/easy-rsa/pki init-pki
    
    # Создаем CA
    echo "Building CA..."
    docker exec -e EASYRSA_BATCH=1 openvpn-ui /usr/share/easy-rsa/easyrsa --pki-dir=/usr/share/easy-rsa/pki build-ca nopass
    
    # Создаем сертификат сервера
    echo "Building Server Certificate..."
    docker exec -e EASYRSA_BATCH=1 openvpn-ui /usr/share/easy-rsa/easyrsa --pki-dir=/usr/share/easy-rsa/pki build-server-full server nopass
    
    # Генерируем Diffie-Hellman
    echo "Generating DH parameters..."
    docker exec -e EASYRSA_BATCH=1 openvpn-ui /usr/share/easy-rsa/easyrsa --pki-dir=/usr/share/easy-rsa/pki gen-dh
    
    # Генерируем CRL
    echo "Generating CRL..."
    docker exec -e EASYRSA_BATCH=1 openvpn-ui /usr/share/easy-rsa/easyrsa --pki-dir=/usr/share/easy-rsa/pki gen-crl
    
    # Генерируем TLS Auth Key (через временный контейнер, так как в UI может не быть openvpn бинарника в PATH)
    echo "Generating TA Key..."
    docker compose run --rm --entrypoint "" openvpn openvpn --genkey --secret /etc/openvpn/pki/ta.key
    
    # Исправляем права
    echo "Fixing permissions..."
    docker exec openvpn-ui sh -c 'chmod -R 755 /etc/openvpn/pki'
    
    echo "PKI Initialized successfully."
    
    # Перезапуск, чтобы сервер подхватил новые ключи
    echo "Restarting OpenVPN Server..."
    docker compose restart openvpn
else
    echo "PKI already initialized. Skipping."
fi

echo "=== Deployment Complete ==="
echo "Access OpenVPN UI at: http://<YOUR_SERVER_IP>:8080 (or via SSH tunnel)"
echo "Credentials are in your .env file."

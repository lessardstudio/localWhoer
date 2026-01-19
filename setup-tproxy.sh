#!/bin/bash

# Настройки
TPROXY_PORT=12345    # Порт TProxy в Hysteria
MARK=1               # Метка пакетов (fwmark)
TABLE=100            # ID таблицы маршрутизации
HYSTERIA_USER="hysteria" # Пользователь, от которого запущена Hysteria (для защиты от петель)

echo "Включаем IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

echo "Настраиваем маршрутизацию (IP Rule)..."
# Очистка старых правил (если были)
ip rule del fwmark $MARK table $TABLE 2>/dev/null
ip route flush table $TABLE 2>/dev/null

# Добавляем правило: пакеты с меткой $MARK идут в таблицу $TABLE
ip rule add fwmark $MARK table $TABLE
# В таблице $TABLE отправляем всё на локальный интерфейс (в TProxy)
ip route add local default dev lo table $TABLE

echo "Настраиваем iptables (Mangle)..."
# Создаем цепочку DIVERT (для уже установленных соединений)
iptables -t mangle -N HYSTERIA_DIVERT 2>/dev/null
iptables -t mangle -F HYSTERIA_DIVERT
iptables -t mangle -A HYSTERIA_DIVERT -j MARK --set-mark $MARK
iptables -t mangle -A HYSTERIA_DIVERT -j ACCEPT

# Создаем цепочку TPROXY
iptables -t mangle -N HYSTERIA_TPROXY 2>/dev/null
iptables -t mangle -F HYSTERIA_TPROXY

# ---------------------------------------------------------
# ИСКЛЮЧЕНИЯ (Bypass) - чтобы не было петель и работала локалка
# ---------------------------------------------------------

# 1. Локальные сети (Docker, LAN) - НЕ трогаем, пусть идут напрямую
iptables -t mangle -A HYSTERIA_TPROXY -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A HYSTERIA_TPROXY -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A HYSTERIA_TPROXY -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A HYSTERIA_TPROXY -d 172.16.0.0/12 -j RETURN  # Включает 172.18.x.x (Docker)

# 2. Трафик самого Hysteria (защита от петли OUTPUT)
# Важно: процесс должен быть запущен от пользователя $HYSTERIA_USER
iptables -t mangle -A HYSTERIA_TPROXY -m owner --uid-owner $HYSTERIA_USER -j RETURN

# 3. Multicast и Broadcast
iptables -t mangle -A HYSTERIA_TPROXY -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A HYSTERIA_TPROXY -d 255.255.255.255 -j RETURN

# ---------------------------------------------------------
# ПРАВИЛА ПЕРЕНАПРАВЛЕНИЯ
# ---------------------------------------------------------

# Перенаправляем TCP и UDP в TProxy порт
iptables -t mangle -A HYSTERIA_TPROXY -p tcp -j TPROXY --tproxy-mark $MARK --on-port $TPROXY_PORT --on-ip 127.0.0.1
iptables -t mangle -A HYSTERIA_TPROXY -p udp -j TPROXY --tproxy-mark $MARK --on-port $TPROXY_PORT --on-ip 127.0.0.1

# Применяем цепочку к PREROUTING (входящий трафик от клиентов/контейнеров)
iptables -t mangle -A PREROUTING -j HYSTERIA_TPROXY

echo "Настройка завершена! TProxy слушает на порту $TPROXY_PORT"

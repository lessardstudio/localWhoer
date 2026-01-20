# Деплой на сервере (VPS) - Локальная Сеть

Этот проект поднимает полноценную локальную сеть через OpenVPN, где клиенты видят друг друга и внутренние Docker-сервисы.

## Архитектура

*   **VPN Network**: `10.8.0.0/24` (Клиенты получают IP из этого диапазона)
*   **Docker Network**: `172.20.0.0/16` (Сервисы имеют статические IP)
*   **Services**:
    *   `whier-app`: `172.20.0.10` (http://whier.local:3000)
    *   `openvpn`: `172.20.0.5`
    *   `samba`: `172.20.0.20` (files.local)
    *   `dns`: `172.20.0.2` (Резолвит .local домены)

## Быстрый старт

1.  **Клонировать репозиторий:**
    ```bash
    git clone https://github.com/lessardstudio/localWhoer.git
    cd localWhoer
    ```

2.  **Запустить установку:**
    ```bash
    chmod +x setup_vpn_network.sh
    ./setup_vpn_network.sh
    ```
    *Скрипт сам сгенерирует конфиги, PKI, настроит файрвол и запустит контейнеры.*

3.  **Создать клиентов:**
    ```bash
    chmod +x create_client.sh
    ./create_client.sh employee1
    ```
    *Файл конфигурации будет в `./openvpn/clients/employee1.ovpn`.*

4.  **Проверка:**
    ```bash
    chmod +x monitor_network.sh
    ./monitor_network.sh
    ```

## Дополнительно

*   **Статические IP клиентам:**
    ```bash
    ./assign_static_ip.sh employee1 10.8.0.50
    ```

*   **Инструкция для пользователей:** См. [CLIENT_NETWORK_GUIDE.md](file:///c:/Users/User/Desktop/localWhoer/CLIENT_NETWORK_GUIDE.md)

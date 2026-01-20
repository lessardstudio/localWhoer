FROM python:3.11-slim

WORKDIR /app

# Установить системные зависимости
RUN apt-get update && apt-get install -y \
    curl \
    docker.io \
    easy-rsa \
    openvpn \
    && rm -rf /var/lib/apt/lists/*

# Установить Python зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копировать приложение
COPY ./app /app

# Создать пользователя
RUN useradd -m -u 1000 apiuser && chown -R apiuser:apiuser /app

USER apiuser

# Запуск
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

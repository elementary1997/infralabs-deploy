#!/bin/bash

# Скрипт для проверки доступности Docker Hub из контейнера

set -e

CONTAINER_NAME="infralabs_web"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Проверка доступности Docker Hub из контейнера ${CONTAINER_NAME}"
echo "=================================="
echo ""

# Проверка существования контейнера
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Контейнер ${CONTAINER_NAME} не запущен!"
    exit 1
fi

echo "✅ Контейнер ${CONTAINER_NAME} найден"
echo ""

# Проверка DNS
echo "📋 Проверка DNS разрешения..."
if docker exec ${CONTAINER_NAME} nslookup registry-1.docker.io >/dev/null 2>&1; then
    echo "✅ DNS разрешение работает"
    docker exec ${CONTAINER_NAME} nslookup registry-1.docker.io | head -5
else
    echo "❌ DNS разрешение не работает!"
    echo "Проверьте настройки DNS в контейнере"
fi
echo ""

# Проверка сетевого подключения
echo "📋 Проверка сетевого подключения..."
if docker exec ${CONTAINER_NAME} ping -c 2 registry-1.docker.io >/dev/null 2>&1; then
    echo "✅ Сетевое подключение работает"
else
    echo "❌ Сетевое подключение не работает!"
    echo "Проверьте сетевые настройки и firewall"
fi
echo ""

# Проверка Docker клиента
echo "📋 Проверка Docker клиента..."
if docker exec ${CONTAINER_NAME} docker version >/dev/null 2>&1; then
    echo "✅ Docker клиент работает"
else
    echo "❌ Docker клиент не работает!"
fi
echo ""

# Попытка загрузить тестовый образ
echo "📋 Попытка загрузить тестовый образ python:3.11-slim..."
echo "Это может занять некоторое время..."
if docker exec ${CONTAINER_NAME} docker pull python:3.11-slim 2>&1 | tee /tmp/docker_pull_test.log; then
    echo ""
    echo "✅ Образ успешно загружен!"
else
    echo ""
    echo "❌ Не удалось загрузить образ!"
    echo ""
    echo "Возможные причины:"
    echo "1. Нет доступа к интернету"
    echo "2. Проблемы с DNS"
    echo "3. Firewall блокирует доступ к Docker Hub"
    echo "4. Проблемы с прокси (если используется)"
    echo ""
    echo "Логи ошибки:"
    tail -20 /tmp/docker_pull_test.log || true
fi
echo ""

# Проверка существующих образов
echo "📋 Проверка существующих образов в системе..."
EXISTING_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "python:3.11|python:3" | head -5 || true)
if [ -n "$EXISTING_IMAGES" ]; then
    echo "Найдены Python образы:"
    echo "$EXISTING_IMAGES"
    echo ""
    echo "💡 Можно использовать один из этих образов вместо загрузки нового"
else
    echo "⚠️  Python образы не найдены"
fi
echo ""

echo "=================================="
echo "✅ Проверка завершена"

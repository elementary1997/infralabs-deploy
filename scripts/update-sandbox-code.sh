#!/bin/bash

# Скрипт для обновления кода sandbox в работающем контейнере (для тестирования)

set -e

CONTAINER_NAME="infralabs_web"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_DIR/../backend"

echo "🔄 Обновление кода sandbox в контейнере..."
echo ""

# Проверка существования контейнера
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Контейнер ${CONTAINER_NAME} не запущен!"
    echo "Запустите: docker-compose up -d web"
    exit 1
fi

echo "✅ Контейнер ${CONTAINER_NAME} найден"
echo ""

# Проверка существования файлов
if [ ! -f "$BACKEND_DIR/apps/sandbox/services/docker_executor.py" ]; then
    echo "❌ Файл не найден: $BACKEND_DIR/apps/sandbox/services/docker_executor.py"
    exit 1
fi

if [ ! -f "$BACKEND_DIR/apps/sandbox/views.py" ]; then
    echo "❌ Файл не найден: $BACKEND_DIR/apps/sandbox/views.py"
    exit 1
fi

echo "📋 Копирование файлов в контейнер..."

# Копирование docker_executor.py
echo "  - docker_executor.py..."
docker cp "$BACKEND_DIR/apps/sandbox/services/docker_executor.py" "${CONTAINER_NAME}:/app/apps/sandbox/services/docker_executor.py"

# Копирование views.py
echo "  - views.py..."
docker cp "$BACKEND_DIR/apps/sandbox/views.py" "${CONTAINER_NAME}:/app/apps/sandbox/views.py"

echo "✅ Файлы скопированы"
echo ""

# Перезапуск контейнера
echo "🔄 Перезапуск контейнера..."
docker-compose restart web

echo "✅ Контейнер перезапущен"
echo ""

# Проверка, что новый код загружен
echo "🔍 Проверка нового кода..."
if docker exec ${CONTAINER_NAME} grep -q "Checking for base image" /app/apps/sandbox/services/docker_executor.py; then
    echo "✅ Новый код загружен успешно!"
else
    echo "⚠️  Новый код не найден в контейнере"
fi

echo ""
echo "📝 Теперь попробуйте создать sandbox и проверьте логи:"
echo "   docker-compose logs web --tail=50 | grep -iE 'sandbox|error|exception|failed|created|container|image'"

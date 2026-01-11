#!/bin/bash

# Скрипт для диагностики проблем с sandbox контейнерами

set -e

CONTAINER_NAME="infralabs_web"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Диагностика Sandbox контейнеров"
echo "=================================="
echo ""

# Переход в директорию проекта
cd "$PROJECT_DIR"

# Проверка существования контейнера
if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Контейнер ${CONTAINER_NAME} не найден!"
    exit 1
fi

echo "✅ Контейнер ${CONTAINER_NAME} найден"
echo ""

# Проверка Docker socket
echo "📋 Проверка Docker socket..."
if docker exec ${CONTAINER_NAME} test -S /var/run/docker.sock; then
    echo "✅ Docker socket доступен"
else
    echo "❌ Docker socket недоступен!"
fi
echo ""

# Проверка Docker клиента внутри контейнера
echo "📋 Проверка Docker клиента..."
if docker exec ${CONTAINER_NAME} docker version >/dev/null 2>&1; then
    echo "✅ Docker клиент работает"
    docker exec ${CONTAINER_NAME} docker version --format "Client: {{.Client.Version}}, Server: {{.Server.Version}}"
else
    echo "❌ Docker клиент не работает!"
    echo "Ошибка:"
    docker exec ${CONTAINER_NAME} docker version 2>&1 || true
fi
echo ""

# Проверка существующих sandbox контейнеров
echo "📋 Проверка существующих sandbox контейнеров..."
SANDBOX_CONTAINERS=$(docker ps -a --filter "label=app=infralabs" --filter "label=type=control_node" --format "{{.Names}}\t{{.Status}}" 2>/dev/null || true)
if [ -z "$SANDBOX_CONTAINERS" ]; then
    echo "⚠️  Sandbox контейнеры не найдены"
else
    echo "Найдены sandbox контейнеры:"
    echo "$SANDBOX_CONTAINERS"
fi
echo ""

# Проверка sandbox сетей
echo "📋 Проверка sandbox сетей..."
SANDBOX_NETWORKS=$(docker network ls --filter "label=app=infralabs" --format "{{.Name}}\t{{.Driver}}" 2>/dev/null || true)
if [ -z "$SANDBOX_NETWORKS" ]; then
    echo "⚠️  Sandbox сети не найдены"
else
    echo "Найдены sandbox сети:"
    echo "$SANDBOX_NETWORKS"
fi
echo ""

# Проверка последних логов sandbox
echo "📋 Последние логи sandbox (последние 50 строк)..."
docker-compose logs web --tail=50 | grep -i "sandbox\|docker\|error\|exception\|failed\|created\|container" | tail -30 || echo "Логи не найдены"
echo ""

# Проверка образов
echo "📋 Проверка образов..."
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "python:3.11-slim"; then
    echo "✅ Образ python:3.11-slim найден"
else
    echo "⚠️  Образ python:3.11-slim не найден (будет загружен автоматически)"
fi

if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "infralabs-sandbox:latest"; then
    echo "✅ Образ infralabs-sandbox:latest найден"
else
    echo "⚠️  Образ infralabs-sandbox:latest не найден (будет использован python:3.11-slim)"
fi
echo ""

# Проверка переменных окружения SANDBOX
echo "📋 Проверка переменных окружения SANDBOX..."
if [ -f .env ]; then
    if grep -q "SANDBOX_" .env; then
        echo "Переменные SANDBOX в .env:"
        grep "SANDBOX_" .env | sed 's/=.*/=***/' || echo "Не найдены"
    else
        echo "⚠️  Переменные SANDBOX не найдены в .env"
    fi
else
    echo "⚠️  Файл .env не найден"
fi
echo ""

echo "=================================="
echo "✅ Диагностика завершена"
echo ""
echo "💡 Следующие шаги:"
echo "1. Проверьте логи контейнера web: docker-compose logs web --tail=100"
echo "2. Попробуйте создать sandbox через API или интерфейс"
echo "3. Проверьте логи после попытки создания: docker-compose logs web --tail=50 | grep -i sandbox"
echo "4. Если контейнер создается, но сразу падает, проверьте логи самого sandbox контейнера:"
echo "   docker logs <sandbox_container_name>"

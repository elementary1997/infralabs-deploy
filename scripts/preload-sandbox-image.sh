#!/bin/bash

# Скрипт для предзагрузки образа python:3.11-slim на сервере

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📦 Предзагрузка образа python:3.11-slim для sandbox контейнеров"
echo "=================================="
echo ""

# Проверка доступности Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    exit 1
fi

echo "✅ Docker найден"
echo ""

# Проверка существования образа
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^python:3.11-slim$"; then
    echo "✅ Образ python:3.11-slim уже существует"
    docker images | grep "python.*3.11-slim"
    echo ""
    echo "💡 Образ готов к использованию"
    exit 0
fi

echo "⚠️  Образ python:3.11-slim не найден"
echo ""

# Попытка загрузить образ
echo "📥 Загрузка образа python:3.11-slim из Docker Hub..."
echo "Это может занять некоторое время (размер ~45MB)..."
echo ""

if docker pull python:3.11-slim; then
    echo ""
    echo "✅ Образ успешно загружен!"
    echo ""
    docker images | grep "python.*3.11-slim"
    echo ""
    echo "💡 Теперь sandbox контейнеры смогут использовать этот образ"
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
    echo "💡 Решения:"
    echo "1. Проверьте интернет-соединение: ping registry-1.docker.io"
    echo "2. Проверьте DNS: nslookup registry-1.docker.io"
    echo "3. Если используете прокси, настройте Docker:"
    echo "   sudo mkdir -p /etc/systemd/system/docker.service.d"
    echo "   sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF"
    echo "   [Service]"
    echo "   Environment=\"HTTP_PROXY=http://proxy.example.com:8080\""
    echo "   Environment=\"HTTPS_PROXY=http://proxy.example.com:8080\""
    echo "   EOF"
    echo "   sudo systemctl daemon-reload"
    echo "   sudo systemctl restart docker"
    echo ""
    echo "4. Или загрузите образ вручную с другого сервера и импортируйте:"
    echo "   # На сервере с интернетом:"
    echo "   docker save python:3.11-slim | gzip > python-3.11-slim.tar.gz"
    echo "   # На этом сервере:"
    echo "   gunzip -c python-3.11-slim.tar.gz | docker load"
    exit 1
fi

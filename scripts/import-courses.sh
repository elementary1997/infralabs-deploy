#!/bin/bash
# Скрипт для импорта курсов, модулей, уроков и упражнений из JSON файла
# Используется в infralabs-deploy для импорта данных курсов

set -e

CONTAINER_NAME=${CONTAINER_NAME:-infralabs_web}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📥 Импорт курсов, модулей, уроков и упражнений${NC}"
echo "=========================================="
echo ""

# Проверка файла
if [ -z "$1" ]; then
    echo -e "${RED}❌ Ошибка: файл для импорта не указан!${NC}"
    echo ""
    echo "Использование: $0 <json_file> [--update] [--skip-existing] [--restore-ids]"
    echo ""
    echo "Параметры:"
    echo "  --update         - Обновлять существующие элементы вместо создания новых"
    echo "  --skip-existing  - Пропускать существующие элементы"
    echo "  --restore-ids    - Восстанавливать оригинальные ID (удалит все существующие данные!)"
    echo ""
    echo "Примеры:"
    echo "  $0 ./exports/courses_export_20250110_120000.json"
    echo "  $0 ./exports/courses_export.json --update"
    echo "  $0 ./exports/courses_export.json --skip-existing"
    exit 1
fi

INPUT_FILE="$1"
shift  # Убираем первый аргумент (путь к файлу)

# Проверка существования файла
if [ ! -f "${INPUT_FILE}" ]; then
    echo -e "${RED}❌ Файл не найден: ${INPUT_FILE}${NC}"
    exit 1
fi

# Проверка контейнера
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Контейнер '${CONTAINER_NAME}' не запущен!${NC}"
    echo "   Запустите контейнеры: docker-compose up -d"
    exit 1
fi

FILE_SIZE=$(du -h "${INPUT_FILE}" | cut -f1)

echo "📋 Параметры импорта:"
echo "   Контейнер: ${CONTAINER_NAME}"
echo "   Файл:      ${INPUT_FILE}"
echo "   Размер:    ${FILE_SIZE}"
echo "   Опции:     $@"
echo ""

# Предупреждение о restore-ids
if [[ "$@" == *"--restore-ids"* ]]; then
    echo -e "${RED}⚠️  ВНИМАНИЕ: --restore-ids удалит ВСЕ существующие курсы, модули, уроки и упражнения!${NC}"
    echo ""
    read -p "Вы уверены? (yes/no): " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
        echo "Импорт отменен."
        exit 0
    fi
fi

# Копирование файла в контейнер
CONTAINER_FILE="/tmp/courses_import.json"
echo "🔄 Копирование файла в контейнер..."
docker cp "${INPUT_FILE}" ${CONTAINER_NAME}:${CONTAINER_FILE}

# Выполнение импорта
echo "📥 Выполнение импорта..."

# Проверяем, что команда доступна (в рабочей директории /app)
if ! docker exec -w /app ${CONTAINER_NAME} python manage.py help import_courses >/dev/null 2>&1; then
    echo -e "${RED}❌ Ошибка: команда 'import_courses' не найдена в контейнере!${NC}"
    echo ""
    echo "   Возможные причины:"
    echo "   1. Образ Docker не содержит management команды"
    echo "   2. Нужно обновить образ: docker-compose pull"
    echo "   3. Контейнер не запущен или поврежден"
    echo ""
    echo "   Попробуйте выполнить команду вручную:"
    echo "   docker exec -w /app ${CONTAINER_NAME} python manage.py import_courses ${CONTAINER_FILE}"
    exit 1
fi

# Выполняем команду в рабочей директории /app
# Используем sh -c для правильной обработки всех аргументов
if [ $# -gt 0 ]; then
    # Есть дополнительные аргументы
    ARGS_STR=""
    for arg in "$@"; do
        ARGS_STR="${ARGS_STR} '${arg}'"
    done
    docker exec -w /app ${CONTAINER_NAME} sh -c "python manage.py import_courses '${CONTAINER_FILE}'${ARGS_STR}"
else
    # Без дополнительных аргументов
    docker exec -w /app ${CONTAINER_NAME} python manage.py import_courses "${CONTAINER_FILE}"
fi

# Удаление временного файла
docker exec ${CONTAINER_NAME} rm -f "${CONTAINER_FILE}"

echo ""
echo -e "${GREEN}✅ Импорт завершен!${NC}"
echo ""
echo "🔄 Перезапуск web сервиса для применения изменений..."
docker-compose restart web 2>/dev/null || echo "   (Перезапуск пропущен - выполните вручную: docker-compose restart web)"

#!/bin/bash
# Скрипт для экспорта курсов, модулей, уроков и упражнений в JSON формат
# Используется в infralabs-deploy для экспорта данных курсов

set -e

CONTAINER_NAME=${CONTAINER_NAME:-infralabs_web}
OUTPUT_DIR="./exports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${OUTPUT_DIR}/courses_export_${TIMESTAMP}.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Экспорт курсов, модулей, уроков, упражнений и квестов${NC}"
echo "=========================================="
echo ""

# Проверка контейнера
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Контейнер '${CONTAINER_NAME}' не запущен!${NC}"
    echo "   Запустите контейнеры: docker-compose up -d"
    exit 1
fi

# Создание директории
mkdir -p "${OUTPUT_DIR}"

# Параметры экспорта
INCLUDE_FILES=false
INCLUDE_UNPUBLISHED=false

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-files)
            INCLUDE_FILES=true
            shift
            ;;
        --include-unpublished)
            INCLUDE_UNPUBLISHED=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo -e "${YELLOW}Неизвестный параметр: $1${NC}"
            shift
            ;;
    esac
done

echo "📋 Параметры экспорта:"
echo "   Контейнер: ${CONTAINER_NAME}"
echo "   Файл:      ${OUTPUT_FILE}"
echo "   С файлами: ${INCLUDE_FILES}"
echo "   Неопубликованные: ${INCLUDE_UNPUBLISHED}"
echo ""

# Построение команды
EXPORT_CMD="python manage.py export_courses /tmp/courses_export.json"
if [ "$INCLUDE_FILES" = "true" ]; then
    EXPORT_CMD="${EXPORT_CMD} --include-files"
fi
if [ "$INCLUDE_UNPUBLISHED" = "true" ]; then
    EXPORT_CMD="${EXPORT_CMD} --include-unpublished"
fi

# Выполнение экспорта (в рабочей директории /app)
echo "🔄 Выполнение экспорта..."
docker exec -w /app ${CONTAINER_NAME} sh -c "${EXPORT_CMD}"

# Копирование файла из контейнера
CONTAINER_FILE="/tmp/courses_export.json"
if docker exec ${CONTAINER_NAME} test -f "${CONTAINER_FILE}"; then
    docker cp ${CONTAINER_NAME}:${CONTAINER_FILE} "${OUTPUT_FILE}"
    docker exec ${CONTAINER_NAME} rm -f "${CONTAINER_FILE}"
    
    FILE_SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
    
    echo ""
    echo -e "${GREEN}✅ Экспорт завершен!${NC}"
    echo "   Файл: ${OUTPUT_FILE}"
    echo "   Размер: ${FILE_SIZE}"
    echo ""
    echo "📦 Для импорта используйте:"
    echo "   ./scripts/import-courses.sh ${OUTPUT_FILE}"
else
    echo -e "${RED}❌ Ошибка: файл экспорта не найден в контейнере${NC}"
    exit 1
fi

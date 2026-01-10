#!/bin/bash
# Скрипт для исправления проблемы с паролем PostgreSQL
# Используется когда пароль в .env не совпадает с паролем в существующей БД

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление проблемы с паролем PostgreSQL${NC}"
echo "=========================================="
echo ""

# Проверка .env файла
if [ ! -f .env ]; then
    echo -e "${RED}❌ Файл .env не найден!${NC}"
    echo "   Запустите сначала: ./scripts/init.sh"
    exit 1
fi

# Читаем текущий пароль из .env
CURRENT_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2 | tr -d '"' || echo "")

if [ -z "$CURRENT_PASSWORD" ]; then
    echo -e "${RED}❌ POSTGRES_PASSWORD не найден в .env${NC}"
    exit 1
fi

echo -e "${CYAN}Текущий пароль из .env: ${CURRENT_PASSWORD:0:10}...${NC}"
echo ""

# Вариант 1: Пересоздать БД с нуля (удалит все данные)
echo -e "${YELLOW}Вариант 1: Пересоздать БД с нуля (рекомендуется для первого запуска)${NC}"
echo "   Это удалит все данные в БД, но создаст новую с правильным паролем"
echo ""
read -p "   Пересоздать БД? (yes/no): " RECREATE

if [ "${RECREATE}" = "yes" ]; then
    echo ""
    echo "🛑 Остановка контейнеров..."
    docker-compose down || true
    
    echo "🗑️  Удаление volume БД..."
    # Находим все volumes связанные с postgres
    VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "(postgres_data|infralabs.*postgres_data|infralabs-deploy.*postgres_data)" || echo "")
    if [ -n "$VOLUMES" ]; then
        echo "$VOLUMES" | while read vol; do
            echo "   Удаление volume: $vol"
            docker volume rm "$vol" 2>/dev/null || true
        done
    fi
    # Дополнительная очистка через docker-compose
    docker-compose down -v 2>/dev/null || true
    
    echo "🔄 Обновление DATABASE_URL..."
    DATABASE_URL_NEW="postgresql://infralabs_user:${CURRENT_PASSWORD}@db:5432/infralabs"
    if command -v awk &> /dev/null; then
        awk -v url="$DATABASE_URL_NEW" '/^DATABASE_URL=/ {print "DATABASE_URL=" url; next} 1' .env > .env.tmp && mv .env.tmp .env
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL_NEW}|" .env
        else
            sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL_NEW}|" .env
        fi
    fi
    
    echo "🚀 Запуск контейнеров с новым паролем..."
    export POSTGRES_PASSWORD="$CURRENT_PASSWORD"
    docker-compose up -d
    
    echo ""
    echo -e "${GREEN}✅ БД пересоздана с паролем из .env${NC}"
    echo "   Подождите 10-15 секунд для инициализации БД..."
    exit 0
fi

# Вариант 2: Изменить пароль в существующей БД
echo ""
echo -e "${YELLOW}Вариант 2: Изменить пароль в существующей БД${NC}"
echo "   Это сохранит все данные, но требует знать старый пароль"
echo ""
read -p "   Введите старый пароль PostgreSQL (или нажмите Enter для пропуска): " OLD_PASSWORD

if [ -n "$OLD_PASSWORD" ]; then
    echo ""
    echo "🔄 Попытка подключения со старым паролем..."
    
    # Временно устанавливаем старый пароль
    export POSTGRES_PASSWORD="$OLD_PASSWORD"
    docker-compose up -d db
    
    echo "⏳ Ожидание готовности БД..."
    sleep 10
    
    # Пытаемся изменить пароль
    if docker-compose exec -T db psql -U infralabs_user -d postgres -c "ALTER USER infralabs_user WITH PASSWORD '${CURRENT_PASSWORD}';" 2>/dev/null; then
        echo -e "${GREEN}✅ Пароль изменен в БД${NC}"
        
        # Обновляем DATABASE_URL
        DATABASE_URL_NEW="postgresql://infralabs_user:${CURRENT_PASSWORD}@db:5432/infralabs"
        if command -v awk &> /dev/null; then
            awk -v url="$DATABASE_URL_NEW" '/^DATABASE_URL=/ {print "DATABASE_URL=" url; next} 1' .env > .env.tmp && mv .env.tmp .env
        else
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL_NEW}|" .env
            else
                sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL_NEW}|" .env
            fi
        fi
        
        # Перезапускаем все сервисы
        export POSTGRES_PASSWORD="$CURRENT_PASSWORD"
        docker-compose restart
        
        echo -e "${GREEN}✅ Готово! Все сервисы перезапущены${NC}"
    else
        echo -e "${RED}❌ Не удалось изменить пароль. Проверьте старый пароль.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Пропущено. Используйте Вариант 1 для пересоздания БД.${NC}"
fi

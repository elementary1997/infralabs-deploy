#!/bin/bash
# Скрипт инициализации для первого развертывания Infra Labs
# Создает .env файл, настраивает ALLOWED_HOSTS и запускает приложение

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 Infra Labs - Инициализация развертывания${NC}"
echo "=========================================="
echo ""

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    echo "   Установите Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose не установлен!${NC}"
    echo "   Установите Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✅ Docker установлен${NC}"
echo ""

# Создание .env файла
if [ ! -f .env ]; then
    echo -e "${CYAN}📝 Создание .env файла...${NC}"
    
    if [ ! -f .env.example ]; then
        echo -e "${RED}❌ Файл .env.example не найден!${NC}"
        exit 1
    fi
    
    cp .env.example .env
    
    # Генерация SECRET_KEY
    echo -e "${CYAN}🔑 Генерация SECRET_KEY...${NC}"
    SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || \
                 openssl rand -hex 32)
    
    # Замена SECRET_KEY в .env используя awk (более надежный метод)
    # awk правильно обрабатывает специальные символы
    if command -v awk &> /dev/null; then
        awk -v key="$SECRET_KEY" '{gsub(/your-secret-key-change-this-in-production/, key)}1' .env > .env.tmp && mv .env.tmp .env
    else
        # Fallback: используем Python если awk недоступен
        python3 << PYEOF
import sys
with open('.env', 'r') as f:
    content = f.read()
content = content.replace('your-secret-key-change-this-in-production', '${SECRET_KEY}')
with open('.env', 'w') as f:
    f.write(content)
PYEOF
    fi
    
    echo -e "${GREEN}✅ .env файл создан с автоматически сгенерированным SECRET_KEY${NC}"
else
    echo -e "${YELLOW}ℹ️  Файл .env уже существует${NC}"
fi

echo ""

# Настройка ALLOWED_HOSTS
echo -e "${CYAN}🌐 Настройка ALLOWED_HOSTS${NC}"
echo "   Введите домены/IP адреса через запятую (или нажмите Enter для localhost,127.0.0.1):"
read -p "   > " ALLOWED_HOSTS_INPUT

if [ -z "$ALLOWED_HOSTS_INPUT" ]; then
    ALLOWED_HOSTS_INPUT="localhost,127.0.0.1"
    echo -e "   ${YELLOW}Используется значение по умолчанию: ${ALLOWED_HOSTS_INPUT}${NC}"
fi

# Обновление ALLOWED_HOSTS в .env используя awk
if command -v awk &> /dev/null; then
    awk -v hosts="$ALLOWED_HOSTS_INPUT" '/^DJANGO_ALLOWED_HOSTS=/ {print "DJANGO_ALLOWED_HOSTS=" hosts; next} 1' .env > .env.tmp && mv .env.tmp .env
else
    # Fallback: используем sed (может работать неправильно со специальными символами)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^DJANGO_ALLOWED_HOSTS=.*|DJANGO_ALLOWED_HOSTS=${ALLOWED_HOSTS_INPUT}|" .env
    else
        sed -i "s|^DJANGO_ALLOWED_HOSTS=.*|DJANGO_ALLOWED_HOSTS=${ALLOWED_HOSTS_INPUT}|" .env
    fi
fi

# Обновление CORS_ALLOWED_ORIGINS на основе ALLOWED_HOSTS
# Преобразуем хосты в HTTP URL через запятую
CORS_ORIGINS=$(echo "$ALLOWED_HOSTS_INPUT" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^/http:\/\//' | tr '\n' ',' | sed 's/,$//')

if command -v awk &> /dev/null; then
    awk -v origins="$CORS_ORIGINS" '/^CORS_ALLOWED_ORIGINS=/ {print "CORS_ALLOWED_ORIGINS=" origins; next} 1' .env > .env.tmp && mv .env.tmp .env
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=${CORS_ORIGINS}|" .env
    else
        sed -i "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=${CORS_ORIGINS}|" .env
    fi
fi

echo -e "${GREEN}✅ ALLOWED_HOSTS настроен: ${ALLOWED_HOSTS_INPUT}${NC}"
echo ""

# Настройка пароля администратора
echo -e "${CYAN}🔐 Настройка пароля администратора${NC}"
echo "   Email: admin@infralabs.com"
read -sp "   Введите пароль (или нажмите Enter для 'admin123'): " ADMIN_PASS
echo ""

if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS="admin123"
    echo -e "   ${YELLOW}Используется пароль по умолчанию: admin123${NC}"
fi

# Обновление ADMIN_PASSWORD в .env используя awk
if command -v awk &> /dev/null; then
    awk -v pass="$ADMIN_PASS" '/^ADMIN_PASSWORD=/ {print "ADMIN_PASSWORD=" pass; next} 1' .env > .env.tmp && mv .env.tmp .env
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
    else
        sed -i "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASS}|" .env
    fi
fi

echo -e "${GREEN}✅ Пароль администратора настроен${NC}"
echo ""

# Настройка пароля PostgreSQL
echo -e "${CYAN}🗄️  Настройка пароля PostgreSQL${NC}"
read -sp "   Введите пароль для PostgreSQL (или нажмите Enter для автоматической генерации): " POSTGRES_PASS
echo ""

if [ -z "$POSTGRES_PASS" ]; then
    POSTGRES_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo -e "   ${YELLOW}Сгенерирован случайный пароль${NC}"
fi

# Обновление POSTGRES_PASSWORD в .env используя awk
if command -v awk &> /dev/null; then
    awk -v pass="$POSTGRES_PASS" '/^POSTGRES_PASSWORD=/ {print "POSTGRES_PASSWORD=" pass; next} 1' .env > .env.tmp && mv .env.tmp .env
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASS}|" .env
    else
        sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASS}|" .env
    fi
fi

# Обновление DATABASE_URL с правильным паролем
DATABASE_URL_NEW="postgresql://infralabs_user:${POSTGRES_PASS}@db:5432/infralabs"
if command -v awk &> /dev/null; then
    awk -v url="$DATABASE_URL_NEW" '/^DATABASE_URL=/ {print "DATABASE_URL=" url; next} 1' .env > .env.tmp && mv .env.tmp .env
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL_NEW}|" .env
    else
        sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${DATABASE_URL_NEW}|" .env
    fi
fi

echo -e "${GREEN}✅ Пароль PostgreSQL настроен${NC}"
echo ""

# Запуск приложения
echo -e "${CYAN}🚀 Запуск приложения...${NC}"
echo ""

# Проверяем, существует ли volume с данными БД
# Ищем volume по имени (может быть с префиксом проекта)
DB_VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep -E "(postgres_data|infralabs.*postgres_data)" | head -1 || echo "")

if [ -n "$DB_VOLUME_NAME" ] && [ ! -f .db_initialized ]; then
    echo -e "${YELLOW}⚠️  Обнаружен существующий volume с данными БД: ${DB_VOLUME_NAME}${NC}"
    echo "   Если вы меняете пароль PostgreSQL, необходимо пересоздать БД."
    echo "   ВАЖНО: Это удалит все существующие данные в БД!"
    echo ""
    read -p "   Пересоздать БД с новым паролем? (yes/no): " RECREATE_DB
    if [ "${RECREATE_DB}" = "yes" ]; then
        echo "🗑️  Удаление существующего volume БД..."
        docker-compose down -v 2>/dev/null || true
        # Пытаемся удалить volume по имени, если docker-compose не удалил
        if docker volume inspect "$DB_VOLUME_NAME" >/dev/null 2>&1; then
            docker volume rm "$DB_VOLUME_NAME" 2>/dev/null || true
        fi
        touch .db_initialized
        echo -e "${GREEN}✅ Volume удален${NC}"
    else
        echo -e "${YELLOW}⚠️  Используется существующая БД. Убедитесь, что пароль в .env совпадает с паролем БД.${NC}"
        echo "   Если пароли не совпадают, используйте существующий пароль или удалите volume вручную:"
        echo "   docker-compose down -v"
    fi
elif [ ! -f .db_initialized ]; then
    echo -e "${GREEN}✅ Первый запуск - БД будет создана с новым паролем${NC}"
    touch .db_initialized
fi

# Экспортируем переменные из .env для docker-compose
# Это необходимо, чтобы переменные были доступны при запуске docker-compose
echo "📋 Загрузка переменных окружения из .env..."

# Явно экспортируем критичные переменные
export POSTGRES_PASSWORD="$POSTGRES_PASS"
export DATABASE_URL="postgresql://infralabs_user:${POSTGRES_PASS}@db:5432/infralabs"

# Загружаем остальные переменные из .env (для использования в docker-compose)
if [ -f .env ]; then
    # Используем source для загрузки переменных из .env
    # Игнорируем ошибки, если есть проблемные символы
    set -a
    source .env 2>/dev/null || {
        # Если source не сработал, загружаем основные переменные вручную
        export DJANGO_SECRET_KEY=$(grep "^DJANGO_SECRET_KEY=" .env | cut -d '=' -f2- | tr -d '"' || echo "")
        export DJANGO_DEBUG=$(grep "^DJANGO_DEBUG=" .env | cut -d '=' -f2 | tr -d '"' || echo "True")
        export DJANGO_ALLOWED_HOSTS=$(grep "^DJANGO_ALLOWED_HOSTS=" .env | cut -d '=' -f2- | tr -d '"' || echo "localhost,127.0.0.1")
    }
    set +a
fi

# Проверка, что пароль установлен
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${RED}❌ Ошибка: POSTGRES_PASSWORD не установлен!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Переменные окружения загружены${NC}"
echo ""

docker-compose pull

# Остановим контейнеры если они уже запущены (для пересоздания с новыми паролями)
echo "🛑 Остановка существующих контейнеров (если есть)..."
docker-compose down 2>/dev/null || true

echo "🚀 Запуск контейнеров..."
echo "   POSTGRES_PASSWORD установлен: ${POSTGRES_PASSWORD:0:10}..."
docker-compose up -d

echo ""
echo -e "${GREEN}✅ Инициализация завершена!${NC}"
echo ""
echo -e "${BLUE}📋 Информация о развертывании:${NC}"
echo "   • Приложение: http://localhost"
echo "   • Админ-панель: http://localhost/admin/"
echo "   • Email администратора: admin@infralabs.com"
echo "   • Пароль администратора: ${ADMIN_PASS}"
echo "   • ALLOWED_HOSTS: ${ALLOWED_HOSTS_INPUT}"
echo ""
echo -e "${YELLOW}⏳ Ожидание запуска сервисов...${NC}"

# Ожидание готовности
sleep 5

# Проверка статуса
echo ""
docker-compose ps

echo ""
echo -e "${GREEN}✅ Готово! Приложение запущено.${NC}"
echo ""
echo "Полезные команды:"
echo "  • Просмотр логов: docker-compose logs -f web"
echo "  • Остановка: docker-compose down"
echo "  • Перезапуск: docker-compose restart"
echo ""

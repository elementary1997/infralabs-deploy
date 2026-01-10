#!/bin/bash
# Скрипт для генерации самоподписанного SSL сертификата
# Используется для локального развертывания или тестирования HTTPS

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CERT_DIR="./ssl"
CERT_FILE="${CERT_DIR}/cert.pem"
KEY_FILE="${CERT_DIR}/key.pem"

echo -e "${BLUE}🔐 Генерация SSL сертификата${NC}"
echo "=========================================="
echo ""

# Параметры сертификата
DOMAIN="${1:-localhost}"
DAYS="${2:-365}"

echo "📋 Параметры:"
echo "   Домен: ${DOMAIN}"
echo "   Срок действия: ${DAYS} дней"
echo ""

# Создание директории
mkdir -p "${CERT_DIR}"

# Генерация сертификата
echo "🔧 Генерация самоподписанного сертификата..."

openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -subj "/C=RU/ST=State/L=City/O=InfraLabs/CN=${DOMAIN}" \
    2>/dev/null || {
    echo -e "${RED}❌ Ошибка: openssl не найден или произошла ошибка${NC}"
    echo "   Установите openssl: apt-get install openssl"
    exit 1
}

# Проверка файлов
if [ ! -f "${CERT_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
    echo -e "${RED}❌ Ошибка: не удалось создать сертификат${NC}"
    exit 1
fi

# Установка прав доступа
chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

echo ""
echo -e "${GREEN}✅ Сертификат создан!${NC}"
echo "   Сертификат: ${CERT_FILE}"
echo "   Приватный ключ: ${KEY_FILE}"
echo ""

# Копирование в Docker volume
if docker volume inspect infralabs-deploy_ssl_certs >/dev/null 2>&1; then
    echo "📦 Копирование сертификата в Docker volume..."
    
    # Временный контейнер для копирования
    docker run --rm -v infralabs-deploy_ssl_certs:/data \
        -v "$(pwd)/${CERT_DIR}:/source" \
        alpine sh -c "cp /source/cert.pem /data/ && cp /source/key.pem /data/ && chmod 600 /data/key.pem && chmod 644 /data/cert.pem"
    
    echo -e "${GREEN}✅ Сертификат скопирован в Docker volume${NC}"
    echo ""
    echo "🔄 Перезапустите nginx для применения изменений:"
    echo "   docker-compose restart nginx"
else
    echo -e "${YELLOW}⚠️  Docker volume 'infralabs-deploy_ssl_certs' не найден${NC}"
    echo "   Запустите сначала: docker-compose up -d"
    echo ""
    echo "   Затем скопируйте сертификаты вручную:"
    echo "   docker cp ${CERT_FILE} infralabs_nginx:/etc/nginx/ssl/cert.pem"
    echo "   docker cp ${KEY_FILE} infralabs_nginx:/etc/nginx/ssl/key.pem"
fi

echo ""
echo -e "${YELLOW}⚠️  ВАЖНО: Самоподписанный сертификат не подходит для production!${NC}"
echo "   Для production используйте Let's Encrypt или сертификат от доверенного CA"
echo ""
echo "📖 Документация: docs/HTTPS_SETUP.md"

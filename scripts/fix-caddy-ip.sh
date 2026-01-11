#!/bin/bash
# Скрипт для исправления Caddyfile для работы с IP адресом

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔧 Исправление Caddyfile для работы с IP адресом${NC}"
echo ""

# Определяем IP адрес сервера
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || \
            ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || \
            hostname -i 2>/dev/null | awk '{print $1}' || \
            echo "")

if [ -z "$SERVER_IP" ]; then
    echo -e "${YELLOW}⚠️  Не удалось автоматически определить IP адрес${NC}"
    read -p "   Введите IP адрес сервера: " SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}❌ IP адрес не указан!${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Определен IP адрес: ${SERVER_IP}${NC}"
    read -p "   Использовать этот IP? (y/n, по умолчанию y): " USE_DETECTED
    if [ "$USE_DETECTED" != "y" ] && [ "$USE_DETECTED" != "Y" ] && [ -n "$USE_DETECTED" ]; then
        read -p "   Введите IP адрес сервера: " SERVER_IP
        if [ -z "$SERVER_IP" ]; then
            echo -e "${RED}❌ IP адрес не указан!${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${CYAN}📝 Создание Caddyfile для IP: ${SERVER_IP}${NC}"

cat > Caddyfile << CADDYEOF
# Caddy конфигурация для автоматического HTTPS
# IP адрес: ${SERVER_IP}
# Режим SSL: Самоподписанный сертификат
# Caddy автоматически сделает редирект HTTP -> HTTPS

${SERVER_IP} {
    # Проксирование на nginx
    reverse_proxy nginx:80 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-Proto {scheme}
    }

    # Логирование
    log {
        output stdout
        format console
    }

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # Самоподписанный сертификат для IP адреса
    tls internal
}
CADDYEOF

echo -e "${GREEN}✅ Caddyfile создан${NC}"
echo ""

# Обновляем DOMAIN в .env если файл существует
if [ -f .env ]; then
    echo -e "${CYAN}📝 Обновление DOMAIN в .env...${NC}"
    if command -v awk &> /dev/null; then
        awk -v domain="$SERVER_IP" '/^DOMAIN=/ {print "DOMAIN=" domain; next} 1' .env > .env.tmp && mv .env.tmp .env || echo "DOMAIN=$SERVER_IP" >> .env
    else
        if grep -q "^DOMAIN=" .env; then
            sed -i "s|^DOMAIN=.*|DOMAIN=${SERVER_IP}|" .env
        else
            echo "DOMAIN=$SERVER_IP" >> .env
        fi
    fi
    echo -e "${GREEN}✅ DOMAIN обновлен в .env${NC}"
    echo ""
fi

# Перезапускаем Caddy
echo -e "${CYAN}🔄 Перезапуск контейнера Caddy...${NC}"
if docker-compose restart caddy 2>/dev/null || docker compose restart caddy 2>/dev/null; then
    echo -e "${GREEN}✅ Контейнер Caddy перезапущен${NC}"
else
    echo -e "${RED}❌ Не удалось перезапустить контейнер Caddy${NC}"
    echo "   Попробуйте вручную: docker-compose restart caddy"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo -e "${CYAN}📋 Проверьте доступ:${NC}"
echo "   - HTTP:  http://${SERVER_IP}  (автоматически перенаправит на HTTPS)"
echo "   - HTTPS: https://${SERVER_IP}"
echo ""
echo -e "${YELLOW}⚠️  Браузер покажет предупреждение о самоподписанном сертификате${NC}"
echo "   Это нормально для IP адресов. Нажмите 'Дополнительно' → 'Перейти на сайт'"
echo ""
echo -e "${CYAN}🔍 Полезные команды:${NC}"
echo "   docker logs infralabs_caddy          # Логи Caddy"
echo "   docker exec infralabs_caddy cat /etc/caddy/Caddyfile  # Проверка конфигурации"
echo "   docker ps | grep caddy               # Статус контейнера"

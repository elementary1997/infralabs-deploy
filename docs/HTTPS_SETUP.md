# Настройка HTTPS для Infra Labs

Это руководство описывает настройку HTTPS для развертывания Infra Labs.

## Варианты настройки

### Вариант 1: Самоподписанный сертификат (для тестирования/локальной разработки)

**Быстрая настройка:**

```bash
# 1. Генерация сертификата
./scripts/generate-ssl-certs.sh yourdomain.com

# 2. Включение SSL в .env
echo "ENABLE_SSL=true" >> .env

# 3. Перезапуск nginx
docker-compose restart nginx
```

**Вручную:**

```bash
# 1. Создание директории
mkdir -p ssl

# 2. Генерация сертификата
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=RU/ST=State/L=City/O=InfraLabs/CN=yourdomain.com"

# 3. Копирование в Docker volume
docker volume create infralabs-deploy_ssl_certs
docker run --rm -v infralabs-deploy_ssl_certs:/data \
    -v "$(pwd)/ssl:/source" \
    alpine sh -c "cp /source/*.pem /data/"

# 4. Обновление .env
echo "ENABLE_SSL=true" >> .env

# 5. Перезапуск
docker-compose restart nginx
```

⚠️ **Внимание:** Самоподписанные сертификаты вызовут предупреждение в браузере. Подходят только для тестирования!

### Вариант 2: Let's Encrypt (для production)

**Требования:**
- Домен должен указывать на ваш сервер
- Порты 80 и 443 должны быть открыты
- Docker и docker-compose установлены

**Установка через Certbot:**

```bash
# 1. Установка certbot
sudo apt-get update
sudo apt-get install certbot

# 2. Получение сертификата
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# 3. Копирование сертификатов в Docker volume
docker volume create infralabs-deploy_ssl_certs
sudo docker run --rm \
    -v infralabs-deploy_ssl_certs:/data \
    -v /etc/letsencrypt/live/yourdomain.com:/source:ro \
    alpine sh -c "cp /source/fullchain.pem /data/cert.pem && cp /source/privkey.pem /data/key.pem && chmod 600 /data/key.pem"

# 4. Обновление .env
echo "ENABLE_SSL=true" >> .env
echo "SSL_CERT_PATH=/etc/nginx/ssl/cert.pem" >> .env
echo "SSL_KEY_PATH=/etc/nginx/ssl/key.pem" >> .env

# 5. Перезапуск nginx
docker-compose restart nginx
```

**Автоматическое обновление сертификатов:**

Создайте cron задачу для автоматического обновления:

```bash
# Добавьте в crontab (sudo crontab -e)
0 0 * * * certbot renew --quiet && docker run --rm -v infralabs-deploy_ssl_certs:/data -v /etc/letsencrypt/live/yourdomain.com:/source:ro alpine sh -c "cp /source/fullchain.pem /data/cert.pem && cp /source/privkey.pem /data/key.pem && chmod 600 /data/key.pem" && docker-compose restart nginx
```

### Вариант 3: Существующий сертификат

Если у вас уже есть SSL сертификат:

```bash
# 1. Копирование сертификата
mkdir -p ssl
cp your-cert.pem ssl/cert.pem
cp your-key.pem ssl/key.pem

# 2. Копирование в Docker volume
docker volume create infralabs-deploy_ssl_certs
docker run --rm -v infralabs-deploy_ssl_certs:/data \
    -v "$(pwd)/ssl:/source" \
    alpine sh -c "cp /source/*.pem /data/ && chmod 600 /data/key.pem"

# 3. Обновление .env
echo "ENABLE_SSL=true" >> .env

# 4. Перезапуск
docker-compose restart nginx
```

## Конфигурация

### Переменные окружения (.env)

```bash
# Включение/выключение HTTPS
ENABLE_SSL=true

# Порты (по умолчанию)
HTTPS_PORT=443

# Пути к сертификатам (по умолчанию)
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
SSL_KEY_PATH=/etc/nginx/ssl/key.pem
```

### docker-compose.yml

Конфигурация уже включает поддержку HTTPS:

- Порт 443 открыт для HTTPS
- Volume `ssl_certs` для хранения сертификатов
- Volume `certbot_data` для Let's Encrypt ACME challenge

## Проверка работы

После настройки проверьте:

```bash
# Проверка портов
docker-compose ps nginx

# Проверка сертификата
openssl s_client -connect localhost:443 -servername yourdomain.com

# Тест HTTPS
curl -k https://localhost/api/health

# Проверка редиректа HTTP -> HTTPS
curl -I http://localhost
# Должен вернуть 301 редирект
```

## Troubleshooting

### Ошибка: SSL certificate not found

**Решение:**
1. Проверьте наличие файлов в volume:
   ```bash
   docker run --rm -v infralabs-deploy_ssl_certs:/data alpine ls -la /data
   ```

2. Убедитесь, что пути в .env совпадают с путями в volume

3. Перезапустите nginx:
   ```bash
   docker-compose restart nginx
   ```

### Ошибка: Port 443 already in use

**Решение:**
1. Проверьте, что порт не занят:
   ```bash
   sudo netstat -tulpn | grep :443
   ```

2. Измените порт в .env:
   ```bash
   HTTPS_PORT=8443
   ```

3. Обновите docker-compose.yml и перезапустите

### Браузер показывает "Небезопасное соединение"

**Для самоподписанных сертификатов:**
- Это нормально! Добавьте исключение в браузере

**Для Let's Encrypt:**
- Проверьте, что домен правильно настроен
- Убедитесь, что сертификат действителен: `openssl x509 -in ssl/cert.pem -text -noout`

### Редирект HTTP -> HTTPS не работает

**Решение:**
1. Убедитесь, что `ENABLE_SSL=true` в .env
2. Проверьте логи nginx: `docker-compose logs nginx`
3. Убедитесь, что конфигурация nginx загружена правильно

## Отключение HTTPS

Для отключения HTTPS:

```bash
# 1. Обновить .env
echo "ENABLE_SSL=false" >> .env

# 2. Перезапустить nginx
docker-compose restart nginx
```

Nginx продолжит работать на HTTP (порт 80), HTTPS будет отключен.

## Безопасность

Рекомендации для production:

1. **Используйте Let's Encrypt** или сертификат от доверенного CA
2. **Настройте автоматическое обновление** сертификатов
3. **Используйте strong ciphers** (уже настроено в конфигурации)
4. **Включите HSTS** (уже настроено в конфигурации)
5. **Регулярно обновляйте** nginx и систему
6. **Мониторьте логи** на подозрительную активность

## Дополнительные ресурсы

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - проверка качества SSL конфигурации

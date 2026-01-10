# Быстрая настройка HTTPS

## Самоподписанный сертификат (для тестирования)

```bash
# 1. Генерация сертификата
./scripts/generate-ssl-certs.sh yourdomain.com

# 2. Включение SSL
echo "ENABLE_SSL=true" >> .env

# 3. Перезапуск nginx
docker-compose restart nginx

# 4. Откройте https://yourdomain.com
```

⚠️ **Браузер покажет предупреждение** - это нормально для самоподписанного сертификата. Нажмите "Продолжить" или "Advanced -> Proceed".

## Let's Encrypt (для production)

```bash
# 1. Установите certbot
sudo apt-get install certbot

# 2. Получите сертификат (замените yourdomain.com на ваш домен)
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# 3. Скопируйте сертификаты в Docker volume
docker volume create infralabs-deploy_ssl_certs
sudo docker run --rm \
    -v infralabs-deploy_ssl_certs:/data \
    -v /etc/letsencrypt/live/yourdomain.com:/source:ro \
    alpine sh -c "cp /source/fullchain.pem /data/cert.pem && cp /source/privkey.pem /data/key.pem && chmod 600 /data/key.pem"

# 4. Включите SSL
echo "ENABLE_SSL=true" >> .env

# 5. Перезапустите nginx
docker-compose restart nginx
```

## Проверка

```bash
# Проверка HTTPS
curl -k https://yourdomain.com/api/health

# Проверка редиректа HTTP -> HTTPS
curl -I http://yourdomain.com
# Должен вернуть 301 редирект на https://
```

## Отключение HTTPS

```bash
# Установите ENABLE_SSL=false в .env
sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/' .env

# Перезапустите nginx
docker-compose restart nginx
```

📖 **Подробная документация:** [docs/HTTPS_SETUP.md](docs/HTTPS_SETUP.md)

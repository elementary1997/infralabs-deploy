# Исправление HTTPS для IP адреса в Caddy

Если вы получаете ошибку "Этот сайт не может обеспечить безопасное соединение" при доступе по HTTPS через IP адрес, выполните следующие шаги:

## Шаг 1: Определите IP адрес вашего сервера

```bash
hostname -I | awk '{print $1}'
```

Или проверьте IP адрес, который вы используете в браузере (например, `192.168.92.129`).

## Шаг 2: Создайте правильный Caddyfile

Замените `192.168.92.129` на IP адрес вашего сервера:

```bash
cd infralabs-deploy
cat > Caddyfile << 'EOF'
192.168.92.129 {
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
EOF
```

## Шаг 3: Перезапустите контейнер Caddy

```bash
docker-compose restart caddy
```

Или пересоздайте контейнер:

```bash
docker-compose up -d --force-recreate caddy
```

## Шаг 4: Проверьте логи Caddy

```bash
docker logs infralabs_caddy
```

Убедитесь, что нет ошибок конфигурации.

## Шаг 5: Проверьте, что Caddyfile применился

```bash
docker exec infralabs_caddy cat /etc/caddy/Caddyfile
```

Убедитесь, что в файле указан правильный IP адрес.

## Шаг 6: Проверьте доступность

- HTTP должен автоматически перенаправляться на HTTPS
- HTTPS должен работать (браузер покажет предупреждение о самоподписанном сертификате - это нормально)
- Нажмите "Дополнительно" → "Перейти на сайт" чтобы принять сертификат

## Альтернативный вариант: Использовать localhost

Если вам не нужен доступ по IP адресу, вы можете использовать localhost:

```bash
cat > Caddyfile << 'EOF'
localhost {
    reverse_proxy nginx:80 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    log {
        output stdout
        format console
    }
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    tls internal
}
EOF

docker-compose restart caddy
```

Тогда доступ будет по `https://localhost` или `https://127.0.0.1`.

## Важные замечания

1. **Самоподписанный сертификат**: Браузер покажет предупреждение о безопасности - это нормально для IP адресов и localhost. Нажмите "Дополнительно" → "Перейти на сайт" чтобы принять.

2. **HTTP редирект**: Caddy автоматически перенаправляет HTTP на HTTPS.

3. **Для production**: Для реального домена используйте режим 3 в `init.sh` для получения Let's Encrypt сертификата.

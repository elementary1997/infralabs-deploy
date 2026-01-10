# 🚀 Быстрый старт - Infra Labs

## 🎯 Автоматическая настройка (рекомендуется)

Самый простой способ - использовать скрипт инициализации:

```bash
# 1. Клонировать репозиторий
git clone https://github.com/elementary1997/infralabs-deploy.git
cd infralabs-deploy

# 2. Запустить скрипт инициализации
chmod +x scripts/init.sh
./scripts/init.sh
```

Скрипт автоматически:
- ✅ Создаст `.env` файл с настройками
- ✅ Сгенерирует `SECRET_KEY`
- ✅ Настроит `ALLOWED_HOSTS` (запросит у вас)
- ✅ Настроит пароли
- ✅ Запустит приложение с тестовыми данными

**После выполнения:**
- Приложение: `http://localhost` или `http://your-server-ip`
- Админка: `http://localhost/admin/` или `http://your-server-ip/admin/`
- Логин: `admin@infralabs.com` / пароль (по умолчанию: `admin123`)

## 📝 Ручная настройка

Если предпочитаете ручную настройку:

### 1. Клонировать репозиторий
```bash
git clone https://github.com/elementary1997/infralabs-deploy.git
cd infralabs-deploy
```

### 2. Создать .env файл
```bash
cp .env.example .env
nano .env  # или любой другой редактор
```

**Обязательно измените:**
- `DJANGO_SECRET_KEY` - сгенерируйте новый ключ
- `DJANGO_ALLOWED_HOSTS` - укажите домен/IP через запятую
- `POSTGRES_PASSWORD` - надежный пароль
- `ADMIN_PASSWORD` - пароль администратора (по умолчанию: `admin123`)

**Примеры настройки ALLOWED_HOSTS:**
```bash
# Локальное использование
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# Production с доменом
DJANGO_ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com

# Несколько серверов
DJANGO_ALLOWED_HOSTS=server1.example.com,server2.example.com,192.168.1.100
```

### 3. Запустить
```bash
docker-compose up -d
```

### 4. Проверить статус
```bash
docker-compose ps
docker-compose logs -f web
```

### 5. Открыть в браузере
- Приложение: `http://your-server-ip` или `http://your-domain`
- Админка: `http://your-server-ip/admin/` или `http://your-domain/admin/`
- Логин: `admin@infralabs.com` / пароль из `.env`

## Обновление
```bash
VERSION=0.1.0 docker-compose pull
VERSION=0.1.0 docker-compose up -d
```

## Остановка
```bash
docker-compose down
```

## Полное удаление (с данными)
```bash
docker-compose down -v
```

## Восстановление базы данных из основного проекта

Для восстановления полной БД со всеми данными:

```bash
# 1. На основном проекте экспортируйте БД:
#    ./scripts/export-full-db.sh
#    (или используйте pg_dump вручную)

# 2. Скопируйте файл на сервер:
#    scp backups/infralabs_full_db_*.sql user@server:/path/to/infralabs-deploy/backups/

# 3. Импортируйте БД (⚠️ заменит всю существующую БД!):
docker-compose up -d db
./scripts/import-full-db.sh ./backups/infralabs_full_db_YYYYMMDD_HHMMSS.sql
```

📖 Подробнее: [docs/DATABASE_RESTORE.md](docs/DATABASE_RESTORE.md)

## ⚠️ Ошибка: password authentication failed

Если при первом запуске видите ошибку аутентификации PostgreSQL:

```bash
# Быстрое исправление
./scripts/fix-db-password.sh

# Или вручную (удалит все данные БД!)
docker-compose down -v
export POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2)
docker-compose up -d
```

📖 Подробнее: [docs/FIX_PASSWORD_AUTH.md](docs/FIX_PASSWORD_AUTH.md)

# 🚀 Быстрый старт - Infra Labs

## Минимальные шаги для запуска

### 1. Клонировать репозиторий
```bash
git clone https://github.com/elementary1997/infralabs-deploy.git
cd infralabs-deploy
```

### 2. Создать .env файл
```bash
cp .env.example .env
```

Отредактируйте `.env` и обязательно измените:
- `SECRET_KEY` (сгенерируйте новый)
- `ALLOWED_HOSTS` (ваш домен/IP)
- `POSTGRES_PASSWORD` (надежный пароль)

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
- Приложение: `http://your-server-ip`
- Админка: `http://your-server-ip/admin/`
- Логин: `admin@infralabs.com` / `admin123`

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

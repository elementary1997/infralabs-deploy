# Исправление ошибки: password authentication failed for user "infralabs_user"

## Проблема

При запуске проекта возникает ошибка:
```
OperationalError: password authentication failed for user "infralabs_user"
```

## Причины

1. **Пароль PostgreSQL в `.env` не совпадает с паролем в существующей БД**
   - Если volume БД уже был создан с другим паролем, изменение переменной окружения не поможет
   - PostgreSQL хранит пароль при инициализации volume

2. **Переменная `POSTGRES_PASSWORD` не передается в контейнер `db`**
   - Сервис `db` должен иметь `env_file` или переменная должна быть экспортирована

3. **`DATABASE_URL` содержит неправильный пароль**
   - Django использует `DATABASE_URL` для подключения, и он должен совпадать с паролем БД

## Решения

### Вариант 1: Первый запуск с нуля (рекомендуется)

Если это первый запуск и нет важных данных:

```bash
cd /path/to/infralabs-deploy

# 1. Остановите контейнеры
docker-compose down

# 2. Удалите volume с данными БД (⚠️ удалит все данные!)
docker volume rm infralabs-deploy_postgres_data

# 3. Запустите скрипт инициализации заново
./scripts/init.sh
```

### Вариант 2: Использовать существующий пароль

Если volume уже существует с данными:

```bash
# 1. Узнайте, какой пароль использовался при создании volume
# Проверьте историю команд или логи

# 2. Установите этот пароль в .env
nano .env
# Установите POSTGRES_PASSWORD на тот же пароль

# 3. Обновите DATABASE_URL
# DATABASE_URL=postgresql://infralabs_user:ВАШ_СТАРЫЙ_ПАРОЛЬ@db:5432/infralabs

# 4. Перезапустите контейнеры
docker-compose down
docker-compose up -d
```

### Вариант 3: Изменить пароль в существующей БД

Если нужно изменить пароль в уже созданной БД:

```bash
# 1. Запустите контейнер БД со старым паролем
docker-compose down
# Временно установите старый пароль в .env
nano .env  # POSTGRES_PASSWORD=старый_пароль
docker-compose up -d db

# 2. Подключитесь к БД и измените пароль
docker-compose exec db psql -U infralabs_user -d infralabs -c "ALTER USER infralabs_user WITH PASSWORD 'новый_пароль';"

# 3. Обновите .env с новым паролем
nano .env  # POSTGRES_PASSWORD=новый_пароль
# Обновите DATABASE_URL
# DATABASE_URL=postgresql://infralabs_user:новый_пароль@db:5432/infralabs

# 4. Перезапустите все сервисы
docker-compose restart
```

### Вариант 4: Проверить и исправить через скрипт

```bash
cd /path/to/infralabs-deploy

# 1. Проверьте текущий пароль в .env
grep POSTGRES_PASSWORD .env

# 2. Проверьте DATABASE_URL
grep DATABASE_URL .env

# 3. Убедитесь, что они совпадают
# DATABASE_URL должен содержать тот же пароль, что и POSTGRES_PASSWORD

# 4. Если не совпадают, исправьте:
# Отредактируйте .env и обновите DATABASE_URL
nano .env

# 5. Перезапустите с правильными переменными
docker-compose down
export POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)
docker-compose up -d
```

## Проверка

После исправления проверьте подключение:

```bash
# Проверка подключения к БД из контейнера web
docker-compose exec web python manage.py dbshell

# Или через psql
docker-compose exec db psql -U infralabs_user -d infralabs -c "SELECT version();"
```

## Предотвращение проблемы

1. **При первом запуске:**
   - Используйте `./scripts/init.sh` - он автоматически настраивает все пароли
   - Не изменяйте пароли вручную после первого запуска без обновления БД

2. **При изменении пароля:**
   - Всегда обновляйте и `POSTGRES_PASSWORD`, и `DATABASE_URL` в `.env`
   - Перезапускайте контейнеры после изменения
   - Если volume уже существует, используйте Вариант 3

3. **Бэкап перед изменениями:**
   ```bash
   docker-compose exec db pg_dump -U infralabs_user infralabs > backup_before_change.sql
   ```

## Автоматическое исправление (быстрый способ)

Если volume пустой или нет важных данных:

```bash
cd /path/to/infralabs-deploy
docker-compose down -v  # Удалит все volumes
./scripts/init.sh       # Пересоздаст все с нуля
```

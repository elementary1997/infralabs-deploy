# Быстрый импорт курсов

## Проблема: "Unknown command: 'import_courses'"

Если вы получили эту ошибку, убедитесь, что:

1. **Контейнер запущен:**
   ```bash
   docker-compose ps
   ```

2. **Образ содержит management команды:**
   ```bash
   docker exec infralabs_web python manage.py help | grep import_courses
   ```

3. **Команда выполняется из правильной директории:**
   ```bash
   docker exec -w /app infralabs_web python manage.py import_courses --help
   ```

## Импорт курсов

### Через скрипт (рекомендуется)

```bash
./scripts/import-courses.sh /path/to/courses_export.json
```

### С опциями

```bash
# Обновить существующие
./scripts/import-courses.sh /path/to/courses_export.json --update

# Пропустить существующие
./scripts/import-courses.sh /path/to/courses_export.json --skip-existing

# Восстановить оригинальные ID (⚠️ удалит все существующие данные!)
./scripts/import-courses.sh /path/to/courses_export.json --restore-ids
```

### Вручную (если скрипт не работает)

```bash
# 1. Скопировать файл в контейнер
docker cp /path/to/courses_export.json infralabs_web:/tmp/courses_import.json

# 2. Выполнить импорт
docker exec -w /app infralabs_web python manage.py import_courses /tmp/courses_import.json

# 3. Удалить временный файл
docker exec infralabs_web rm /tmp/courses_import.json
```

## Проверка импорта

После импорта проверьте:

```bash
# Проверить количество курсов
docker exec -w /app infralabs_web python manage.py shell -c "from apps.courses.models import Course; print(f'Курсов: {Course.objects.count()}')"

# Проверить логи импорта
docker-compose logs web | grep -i "import\|course"
```

## Troubleshooting

### Ошибка: "Unknown command"

**Решение:**
1. Убедитесь, что контейнер использует правильный образ:
   ```bash
   docker-compose pull web
   docker-compose up -d web
   ```

2. Проверьте, что команда доступна:
   ```bash
   docker exec -w /app infralabs_web python manage.py help import_courses
   ```

3. Если команда отсутствует, возможно нужно пересобрать образ с обновленным кодом

### Ошибка: "File not found"

**Решение:**
- Убедитесь, что файл скопирован в контейнер:
  ```bash
  docker exec infralabs_web ls -la /tmp/courses_import.json
  ```

### Ошибка: "Foreign key constraint failed"

**Решение:**
- JSON файл может быть поврежден или неполный
- Проверьте структуру файла:
  ```bash
  python -m json.tool courses_export.json | head -50
  ```
- Попробуйте использовать `--restore-ids` для полного пересоздания

📖 **Подробная документация:** [docs/COURSES_EXPORT_IMPORT.md](docs/COURSES_EXPORT_IMPORT.md)

# Настройка Sandbox контейнеров для упражнений

## Обзор

Sandbox контейнеры создаются автоматически, когда пользователь заходит в упражнение. Они позволяют выполнять Ansible код в изолированной среде.

## Требования

1. **Docker socket должен быть доступен** в контейнере `web`:
   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   ```

2. **Контейнер `web` должен работать от root** (или иметь права на Docker socket)

3. **Переменные окружения** должны быть настроены в `.env`:
   ```bash
   SANDBOX_TIMEOUT=300
   SANDBOX_MEMORY_LIMIT=512m
   SANDBOX_CPU_LIMIT=1.0
   MAX_CONCURRENT_SANDBOXES=50
   ```

## Проверка работоспособности

### 1. Проверка Docker клиента в контейнере

```bash
docker-compose exec web python -c "import docker; client = docker.from_env(); print('✅ Docker клиент работает'); print('Версия:', client.version()['Version'])"
```

### 2. Проверка создания тестового контейнера

```bash
docker-compose exec web python -c "
import docker
client = docker.from_env()
try:
    container = client.containers.run('hello-world', remove=True, detach=False)
    print('✅ Контейнеры могут создаваться')
except Exception as e:
    print(f'❌ Ошибка: {e}')
"
```

### 3. Проверка создания сети

```bash
docker-compose exec web python -c "
import docker
client = docker.from_env()
try:
    net = client.networks.create('test_network', driver='bridge')
    print('✅ Сети могут создаваться')
    net.remove()
    print('✅ Сеть удалена')
except Exception as e:
    print(f'❌ Ошибка: {e}')
"
```

## Устранение проблем

### Проблема: Контейнеры не создаются

**Причины:**
1. Docker socket не доступен
2. Нет прав на создание контейнеров
3. Отсутствует docker-py в образе

**Решение:**
1. Проверьте, что Docker socket смонтирован:
   ```bash
   docker-compose exec web ls -la /var/run/docker.sock
   ```
   Должно быть: `srw-rw---- 1 root docker`

2. Проверьте, что контейнер работает от root:
   ```bash
   docker-compose exec web id
   ```
   Должно быть: `uid=0(root) gid=0(root) groups=0(root)`

3. Если используете готовый образ, убедитесь, что он содержит:
   - Docker CLI (`docker-ce-cli`)
   - docker-py (`pip install docker`)

### Проблема: Контейнеры создаются, но не запускаются

**Причины:**
1. Проблемы с сетью
2. Ошибки в образе контейнера
3. Недостаточно ресурсов

**Решение:**
1. Проверьте логи контейнера:
   ```bash
   docker logs <container_name>
   ```

2. Проверьте доступность базового образа:
   ```bash
   docker images | grep python:3.11-slim
   ```

3. Проверьте ресурсы системы:
   ```bash
   docker stats
   ```

### Проблема: Контейнеры создаются, но упражнения не выполняются

**Причины:**
1. Ansible не установлен в sandbox контейнере
2. Проблемы с inventory файлами
3. Ошибки в коде выполнения

**Решение:**
1. Проверьте, что Ansible установлен в контейнере:
   ```bash
   docker exec <sandbox_container> ansible --version
   ```

2. Проверьте логи веб-сервера:
   ```bash
   docker-compose logs web | grep -i sandbox
   ```

## Настройка в docker-compose.yml

Убедитесь, что в `docker-compose.yml` есть:

```yaml
services:
  web:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ⚠️ Обязательно!
    # Контейнер должен работать от root или иметь права на docker socket
  
  celery_worker:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # Для очистки контейнеров
```

## Логирование

Для отладки включите DEBUG логирование в `.env`:
```bash
DJANGO_DEBUG=True
```

Логи sandbox будут в:
```bash
docker-compose logs web | grep -i sandbox
docker-compose logs celery_worker | grep -i sandbox
```

## Автоматическая очистка

Celery Beat автоматически очищает истекшие контейнеры каждые 5 минут. Для ручной очистки:

```bash
docker-compose exec web python manage.py shell -c "
from apps.sandbox.tasks import cleanup_expired_sandboxes
result = cleanup_expired_sandboxes()
print(f'Очищено: {result}')
"
```

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

## Диагностика

Для автоматической диагностики проблем используйте скрипт:

```bash
./scripts/check-sandbox.sh
```

Скрипт проверит:
- ✅ Доступность Docker socket
- ✅ Работоспособность Docker клиента
- ✅ Существующие sandbox контейнеры и их статусы
- ✅ Sandbox сети
- ✅ Доступность образов
- ✅ Переменные окружения SANDBOX
- ✅ Последние логи

### Улучшенное логирование

В коде добавлено детальное логирование на каждом этапе создания контейнера:
- Создание/поиск сети
- Поиск/загрузка образа
- Создание контейнера
- Проверка статуса контейнера
- Все ошибки с полным traceback

Для просмотра логов:
```bash
# Все логи sandbox
docker-compose logs web | grep -i sandbox

# Последние 100 строк с ошибками
docker-compose logs web --tail=100 | grep -iE "sandbox|error|exception|failed"

# Логи конкретного sandbox контейнера
docker logs <sandbox_container_name>
```

## Предзагрузка образа sandbox

Образ `python:3.11-slim` **автоматически предзагружается** при запуске скрипта инициализации `init.sh`:

```bash
./scripts/init.sh
```

Скрипт `init.sh`:
- Автоматически проверяет наличие образа `python:3.11-slim` локально
- Если образ не найден, загружает его из Docker Hub
- Если загрузка не удалась, выводит предупреждение (не блокирует запуск)

**Ручная предзагрузка (опционально):**

Если нужно предзагрузить образ вручную, используйте скрипт:

```bash
./scripts/preload-sandbox-image.sh
```

**Важно:** Если сервер не имеет доступа к интернету или Docker Hub недоступен, образ нужно загрузить вручную или импортировать с другого сервера.

## Устранение проблем

### Проблема: Образ python:3.11-slim не загружается

**Симптомы:**
- В логах видно "Python base image not found, pulling..."
- Процесс зависает или выдает ошибку подключения
- Сообщение "Timeout pulling image" или "Cannot connect to Docker Hub"

**Причины:**
1. Нет доступа к интернету
2. Проблемы с DNS
3. Firewall блокирует доступ к Docker Hub
4. Проблемы с прокси

**Решение:**

1. **Проверьте доступность Docker Hub:**
   ```bash
   ./scripts/test-docker-hub.sh
   ```

2. **Предзагрузите образ вручную:**
   ```bash
   docker pull python:3.11-slim
   ```
   Или используйте скрипт:
   ```bash
   ./scripts/preload-sandbox-image.sh
   ```

3. **Если Docker Hub недоступен, импортируйте образ:**
   ```bash
   # На сервере с интернетом:
   docker save python:3.11-slim | gzip > python-3.11-slim.tar.gz
   
   # На этом сервере:
   gunzip -c python-3.11-slim.tar.gz | docker load
   ```

4. **Проверьте сетевые настройки:**
   ```bash
   # Проверка DNS
   docker exec infralabs_web nslookup registry-1.docker.io
   
   # Проверка сетевого подключения
   docker exec infralabs_web ping -c 2 registry-1.docker.io
   ```

5. **Если используете прокси, настройте Docker:**
   ```bash
   sudo mkdir -p /etc/systemd/system/docker.service.d
   sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
   [Service]
   Environment="HTTP_PROXY=http://proxy.example.com:8080"
   Environment="HTTPS_PROXY=http://proxy.example.com:8080"
   EOF
   sudo systemctl daemon-reload
   sudo systemctl restart docker
   ```

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

**Симптомы:**
- В логах видно "Sandbox image not found" или "Creating container..."
- Но нет сообщения "Created sandbox successfully" или "Container status after creation: running"
- Контейнер создается, но сразу падает (статус: exited)

**Причины:**
1. Проблемы с сетью (ошибка при подключении к сети)
2. Ошибки в образе контейнера
3. Недостаточно ресурсов
4. Ошибка при установке Ansible (для python:3.11-slim)

**Решение:**
1. Запустите диагностический скрипт:
   ```bash
   ./scripts/check-sandbox.sh
   ```

2. Проверьте подробные логи создания:
   ```bash
   docker-compose logs web --tail=200 | grep -iE "sandbox|container|network|error|exception"
   ```

3. Проверьте логи самого sandbox контейнера:
   ```bash
   # Найдите имя контейнера
   docker ps -a | grep sandbox
   
   # Просмотрите логи
   docker logs <sandbox_container_name>
   ```

4. Проверьте доступность базового образа:
   ```bash
   docker images | grep python:3.11-slim
   # Если нет, образ будет загружен автоматически
   ```

5. Проверьте ресурсы системы:
   ```bash
   docker stats
   ```

6. Проверьте, что контейнер действительно создается:
   ```bash
   docker ps -a | grep infralabs_sandbox
   ```

7. Если контейнер создается, но сразу падает, проверьте причину:
   ```bash
   docker inspect <sandbox_container_name> | grep -A 10 "State"
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

### Настройка уровня логирования

Для отладки включите DEBUG логирование в `.env`:
```bash
DJANGO_DEBUG=True
LOG_LEVEL=DEBUG
```

### Просмотр логов

**Все логи sandbox:**
```bash
docker-compose logs web | grep -i sandbox
```

**Последние логи с ошибками:**
```bash
docker-compose logs web --tail=100 | grep -iE "sandbox|error|exception|failed|created|container"
```

**Логи Celery worker:**
```bash
docker-compose logs celery_worker | grep -i sandbox
```

**Логи конкретного sandbox контейнера:**
```bash
docker logs <sandbox_container_name> --tail=50
```

**Поиск конкретной ошибки:**
```bash
docker-compose logs web 2>&1 | grep -A 10 -B 5 "Failed to create sandbox"
```

### Что логируется

При создании sandbox контейнера логируется:
1. ✅ Начало создания (пользователь, имя контейнера)
2. ✅ Создание/поиск сети
3. ✅ Поиск/загрузка образа
4. ✅ Создание контейнера
5. ✅ Подключение к сети
6. ✅ Проверка статуса контейнера
7. ✅ Получение IP адреса
8. ✅ Создание inventory файла
9. ✅ Все ошибки с полным traceback

Пример успешного лога:
```
INFO Starting sandbox creation for user: user@example.com, container: infralabs_sandbox_user_example_com
INFO Creating new network: infralabs_net_user_example_com
INFO Successfully created network: infralabs_net_user_example_com
INFO Sandbox image not found, using python:3.11-slim with Ansible installation
INFO Creating container infralabs_sandbox_user_example_com with Python base image and Ansible installation...
INFO Container infralabs_sandbox_user_example_com created successfully, ID: abc123
INFO Container status after creation: running
INFO Created sandbox: infralabs_sandbox_user_example_com (single container), IP: 172.20.0.2, ID: abc123
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

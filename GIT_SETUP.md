# Инструкция по созданию GitHub репозитория

## 1. Инициализация Git репозитория

```bash
cd deploy-minimal
git init
git add .
git commit -m "Initial commit: Minimal deployment setup"
```

## 2. Создание репозитория на GitHub

1. Перейдите на https://github.com/new
2. Название репозитория: `infralabs-deploy` (или другое на ваше усмотрение)
3. Описание: "Minimal deployment setup for Infra Labs using Docker Compose"
4. Выберите Public или Private
5. **НЕ** добавляйте README, .gitignore или license (они уже есть)
6. Нажмите "Create repository"

## 3. Подключение к удаленному репозиторию

```bash
# Добавьте remote (замените USERNAME на ваш GitHub username)
git remote add origin https://github.com/elementary1997/infralabs-deploy.git

# Или через SSH
git remote add origin git@github.com:elementary1997/infralabs-deploy.git
```

## 4. Отправка на GitHub

```bash
# Переименуйте ветку в main (если нужно)
git branch -M main

# Отправьте код
git push -u origin main
```

## 5. Проверка

После успешной отправки проверьте:
- Все файлы загружены
- README.md отображается корректно
- .env.example виден в репозитории

## Файлы в репозитории

Следующие файлы будут включены:
- ✅ `docker-compose.yml` - основной файл развертывания
- ✅ `.env.example` - пример конфигурации
- ✅ `README.md` - полная документация
- ✅ `QUICKSTART.md` - краткая инструкция
- ✅ `.gitignore` - игнорируемые файлы
- ✅ `.dockerignore` - игнорируемые файлы для Docker

Следующие файлы НЕ будут включены:
- ❌ `.env` - локальные настройки (в .gitignore)
- ❌ Логи и временные файлы
- ❌ Данные volumes

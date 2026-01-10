#!/usr/bin/env python
"""
Скрипт для автоматического создания или обновления администратора.
Идемпотентный - можно запускать многократно без ошибок.
"""
import os
import sys
import django

# Настройка Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()

def main():
    # Получение данных из переменных окружения
    email = os.environ.get('ADMIN_EMAIL', 'admin@infralabs.com')
    username = os.environ.get('ADMIN_USERNAME', 'admin')
    password = os.environ.get('ADMIN_PASSWORD', 'admin123')
    
    try:
        # Проверка существования пользователя
        if User.objects.filter(email=email).exists():
            user = User.objects.get(email=email)
            user.is_superuser = True
            user.is_staff = True
            user.username = username
            user.set_password(password)
            user.save()
            print(f'✅ Admin user {email} updated (password reset)')
        else:
            # Создание нового пользователя
            User.objects.create_superuser(
                username=username,
                email=email,
                password=password
            )
            print(f'✅ Admin user {email} created successfully')
        
        return 0
    except Exception as e:
        print(f'❌ Error creating admin user: {e}', file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())

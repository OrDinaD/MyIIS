#!/usr/bin/env python3
"""
Тест обновления настроек профиля через API
Проверяет, работает ли PUT /api/v1/students/me/settings
"""

import requests
import json
from datetime import datetime

# Конфигурация
BASE_URL = "https://iis.bsuir.by/api/v1"
USERNAME = "42850012"
PASSWORD = "Bsuirinyouv.12_"

def log(message):
    """Красивое логирование"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def test_settings_update():
    """Тестирование обновления настроек профиля"""
    
    session = requests.Session()
    
    # Шаг 1: Логин
    log("🔐 Шаг 1: Авторизация...")
    login_url = f"{BASE_URL}/auth/login"
    login_data = {
        "username": USERNAME,
        "password": PASSWORD
    }
    
    try:
        login_response = session.post(login_url, json=login_data)
        login_response.raise_for_status()
        log(f"✅ Логин успешен! Пользователь: {login_response.json()['fio']}")
    except Exception as e:
        log(f"❌ Ошибка логина: {e}")
        return
    
    # Шаг 2: Получить текущую информацию профиля
    log("\n📋 Шаг 2: Получение текущих данных профиля...")
    personal_info_url = f"{BASE_URL}/personal-information"
    
    try:
        profile_response = session.get(personal_info_url)
        profile_response.raise_for_status()
        profile_data = profile_response.json()
        
        current_settings = profile_data.get("settings", {})
        log(f"📊 Текущие настройки:")
        log(f"   - Публичный профиль: {current_settings.get('isPublicProfile')}")
        log(f"   - Ищу работу: {current_settings.get('isSearchJob')}")
        log(f"   - Показывать рейтинг: {current_settings.get('isShowRating')}")
        
    except Exception as e:
        log(f"❌ Ошибка получения профиля: {e}")
        return
    
    # Шаг 3: Попробовать обновить настройки через разные эндпоинты
    log("\n🔧 Шаг 3: Тестирование различных эндпоинтов для обновления...")
    
    # Создаём тестовые настройки (инвертируем текущие)
    test_settings = {
        "isPublicProfile": not current_settings.get('isPublicProfile', True),
        "isSearchJob": not current_settings.get('isSearchJob', False),
        "isShowRating": not current_settings.get('isShowRating', False)
    }
    
    log(f"🧪 Тестовые настройки для отправки:")
    log(f"   - Публичный профиль: {test_settings['isPublicProfile']}")
    log(f"   - Ищу работу: {test_settings['isSearchJob']}")
    log(f"   - Показывать рейтинг: {test_settings['isShowRating']}")
    
    # Вариант 1: PUT /students/me/settings (из документации v2)
    log("\n🔍 Вариант 1: PUT /api/v1/students/me/settings")
    try:
        url = f"{BASE_URL}/students/me/settings"
        response = session.put(url, json=test_settings)
        log(f"   Статус: {response.status_code}")
        
        if response.status_code == 200:
            log(f"   ✅ РАБОТАЕТ! Ответ: {response.json()}")
        elif response.status_code == 404:
            log(f"   ❌ 404 - Эндпоинт не найден")
        elif response.status_code == 401:
            log(f"   ❌ 401 - Не авторизован")
        elif response.status_code == 405:
            log(f"   ❌ 405 - Метод не поддерживается")
        else:
            log(f"   ⚠️ Статус {response.status_code}: {response.text[:200]}")
            
    except Exception as e:
        log(f"   ❌ Ошибка запроса: {e}")
    
    # Вариант 2: PATCH /personal-information/settings
    log("\n🔍 Вариант 2: PATCH /api/v1/personal-information/settings")
    try:
        url = f"{BASE_URL}/personal-information/settings"
        response = session.patch(url, json=test_settings)
        log(f"   Статус: {response.status_code}")
        
        if response.status_code == 200:
            log(f"   ✅ РАБОТАЕТ! Ответ: {response.json()}")
        elif response.status_code == 404:
            log(f"   ❌ 404 - Эндпоинт не найден")
        else:
            log(f"   ⚠️ Статус {response.status_code}: {response.text[:200]}")
            
    except Exception as e:
        log(f"   ❌ Ошибка запроса: {e}")
    
    # Вариант 3: PUT /personal-information/settings
    log("\n🔍 Вариант 3: PUT /api/v1/personal-information/settings")
    try:
        url = f"{BASE_URL}/personal-information/settings"
        response = session.put(url, json=test_settings)
        log(f"   Статус: {response.status_code}")
        
        if response.status_code == 200:
            log(f"   ✅ РАБОТАЕТ! Ответ: {response.json()}")
        elif response.status_code == 404:
            log(f"   ❌ 404 - Эндпоинт не найден")
        else:
            log(f"   ⚠️ Статус {response.status_code}: {response.text[:200]}")
            
    except Exception as e:
        log(f"   ❌ Ошибка запроса: {e}")
    
    # Вариант 4: PATCH /personal-information (обновление всего профиля)
    log("\n🔍 Вариант 4: PATCH /api/v1/personal-information")
    try:
        url = f"{BASE_URL}/personal-information"
        payload = {"settings": test_settings}
        response = session.patch(url, json=payload)
        log(f"   Статус: {response.status_code}")
        
        if response.status_code == 200:
            log(f"   ✅ РАБОТАЕТ! Ответ: {response.json()}")
        elif response.status_code == 404:
            log(f"   ❌ 404 - Эндпоинт не найден")
        else:
            log(f"   ⚠️ Статус {response.status_code}: {response.text[:200]}")
            
    except Exception as e:
        log(f"   ❌ Ошибка запроса: {e}")
    
    # Вариант 5: PUT /personal-information (обновление всего профиля)
    log("\n🔍 Вариант 5: PUT /api/v1/personal-information")
    try:
        url = f"{BASE_URL}/personal-information"
        # Отправляем весь профиль с обновлёнными настройками
        full_profile = profile_data.copy()
        full_profile['settings'] = test_settings
        response = session.put(url, json=full_profile)
        log(f"   Статус: {response.status_code}")
        
        if response.status_code == 200:
            log(f"   ✅ РАБОТАЕТ! Ответ: {response.json()}")
        elif response.status_code == 404:
            log(f"   ❌ 404 - Эндпоинт не найден")
        else:
            log(f"   ⚠️ Статус {response.status_code}: {response.text[:200]}")
            
    except Exception as e:
        log(f"   ❌ Ошибка запроса: {e}")
    
    # Шаг 4: Проверить, изменились ли настройки
    log("\n🔍 Шаг 4: Проверка, изменились ли настройки...")
    try:
        profile_response = session.get(personal_info_url)
        profile_response.raise_for_status()
        updated_profile = profile_response.json()
        updated_settings = updated_profile.get("settings", {})
        
        log(f"📊 Настройки после попыток обновления:")
        log(f"   - Публичный профиль: {updated_settings.get('isPublicProfile')}")
        log(f"   - Ищу работу: {updated_settings.get('isSearchJob')}")
        log(f"   - Показывать рейтинг: {updated_settings.get('isShowRating')}")
        
        if updated_settings == current_settings:
            log("\n⚠️ ВЫВОД: Настройки НЕ изменились! API не поддерживает обновление.")
        else:
            log("\n✅ ВЫВОД: Настройки ИЗМЕНИЛИСЬ! Один из эндпоинтов работает.")
            
    except Exception as e:
        log(f"❌ Ошибка проверки: {e}")
    
    log("\n" + "="*70)
    log("📝 РЕКОМЕНДАЦИЯ:")
    log("Если ни один эндпоинт не сработал - настройки профиля READ-ONLY.")
    log("В таком случае нужно убрать возможность редактирования из UI.")
    log("="*70)

if __name__ == "__main__":
    print("="*70)
    print("🧪 ТЕСТ ОБНОВЛЕНИЯ НАСТРОЕК ПРОФИЛЯ MyIIS API")
    print("="*70 + "\n")
    test_settings_update()

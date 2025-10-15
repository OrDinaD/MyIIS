#!/usr/bin/env python3
"""
Расширенный тест эндпоинтов API БГУИР
"""

import requests
import json
import os

USERNAME = "42850012"
PASSWORD = "Bsuirinyouv.12_"

BASE_URL = "https://iis.bsuir.by/api/v1"

def main():
    print("=" * 80)
    print("🔍 Расширенный тест API БГУИР - Поиск полных данных профиля")
    print("=" * 80)
    
    session = requests.Session()
    
    # Шаг 1: Аутентификация
    print("\n📝 Шаг 1: Аутентификация")
    login_response = session.post(
        f"{BASE_URL}/auth/login",
        json={"username": USERNAME, "password": PASSWORD},
        headers={"Content-Type": "application/json"}
    )
    
    if login_response.status_code != 200:
        print(f"❌ Ошибка аутентификации: {login_response.status_code}")
        return
    
    print("✅ Успешная аутентификация!")
    user_data = login_response.json()
    
    # Шаг 2: Тестируем множество возможных эндпоинтов
    print("\n📝 Шаг 2: Тестируем все возможные эндпоинты")
    
    endpoints_to_test = [
        # Профиль
        "/personal-information",
        "/profile",
        "/user",
        "/me",
        "/account",
        "/student",
        "/student/profile",
        "/student/me",
        "/students/profile",
        "/students/me",
        f"/students/{user_data.get('username')}",
        
        # Группа
        "/group",
        "/groups",
        "/my-group",
        "/student/group",
        "/students/me/group",
        f"/groups/{user_data.get('group')}",
        
        # Зачётная книжка
        "/record-book",
        "/recordbook",
        "/gradebook",
        "/marks",
        "/student/record-book",
        "/students/me/record-book",
        
        # Настройки
        "/settings",
        "/student/settings",
        "/students/me/settings",
        
        # Рейтинг
        "/rating",
        f"/rating?group={user_data.get('group')}",
        
        # Посещаемость
        "/attendance",
        "/student/attendance",
        
        # Расписание
        "/schedule",
        f"/schedule?studentGroup={user_data.get('group')}",
        
        # Образование
        "/education",
        "/student/education",
        "/faculties",
        "/faculties-specialities",
    ]
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    successful_endpoints = {}
    
    for endpoint in endpoints_to_test:
        url = f"{BASE_URL}{endpoint}"
        print(f"\n🔍 {url}", end=" ")
        
        try:
            response = session.get(url, timeout=5)
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    print(f"✅ Status: {response.status_code}")
                    
                    # Показываем первые ключи
                    if isinstance(data, dict):
                        keys = list(data.keys())
                        print(f"   📋 Keys ({len(keys)}): {keys[:8]}")
                        if 'firstName' in keys or 'lastName' in keys or 'faculty' in keys:
                            print("   🎯 ВАЖНО: Содержит личные данные!")
                    elif isinstance(data, list) and len(data) > 0:
                        print(f"   📋 Array length: {len(data)}")
                        if isinstance(data[0], dict):
                            print(f"   📋 First item keys: {list(data[0].keys())[:8]}")
                    
                    successful_endpoints[endpoint] = data
                    
                except Exception as e:
                    print(f"✅ Status: {response.status_code} (не JSON)")
                    print(f"   {response.text[:100]}")
            elif response.status_code == 404:
                print(f"❌ 404")
            elif response.status_code == 401:
                print(f"❌ 401 (Unauthorized)")
            elif response.status_code == 403:
                print(f"❌ 403 (Forbidden)")
            else:
                print(f"❌ {response.status_code}")
                
        except Exception as e:
            print(f"❌ Exception: {str(e)[:50]}")
    
    # Сохраняем все успешные ответы
    print("\n" + "=" * 80)
    print("📊 ИТОГИ")
    print("=" * 80)
    
    if successful_endpoints:
        print(f"\n✅ Найдено {len(successful_endpoints)} рабочих эндпоинта(ов):\n")
        
        for endpoint, data in successful_endpoints.items():
            print(f"✓ {endpoint}")
            
            # Сохраняем каждый ответ в отдельный файл
            safe_name = endpoint.replace("/", "_").replace("?", "_").replace("=", "_")
            filename = f"api_response{safe_name}.json"
            filepath = os.path.join(script_dir, filename)
            
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"  💾 Сохранено в {filename}")
    else:
        print("\n❌ Не найдено рабочих эндпоинтов")
    
    print("\n" + "=" * 80)

if __name__ == "__main__":
    main()

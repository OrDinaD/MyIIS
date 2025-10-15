#!/usr/bin/env python3
"""
Полный тест API БГУИР с cookie-based аутентификацией
"""

import requests
import json

USERNAME = "42850012"
PASSWORD = "Bsuirinyouv.12_"

BASE_URL = "https://iis.bsuir.by/api/v1"

def main():
    print("=" * 80)
    print("🚀 Полный тест API БГУИР")
    print("=" * 80)
    
    # Создаём сессию для сохранения cookies
    session = requests.Session()
    
    # Шаг 1: Аутентификация
    print("\n📝 Шаг 1: Аутентификация")
    print(f"URL: {BASE_URL}/auth/login")
    
    login_response = session.post(
        f"{BASE_URL}/auth/login",
        json={"username": USERNAME, "password": PASSWORD},
        headers={"Content-Type": "application/json"}
    )
    
    print(f"Status: {login_response.status_code}")
    
    if login_response.status_code == 200:
        print("✅ Успешная аутентификация!")
        user_data = login_response.json()
        print(f"Username: {user_data.get('username')}")
        print(f"FIO: {user_data.get('fio')}")
        print(f"Group: {user_data.get('group')}")
        
        # Проверяем cookie
        if 'SESSION' in session.cookies:
            print(f"🍪 Session Cookie: {session.cookies['SESSION'][:30]}...")
        
        # Сохраняем данные входа
        import os
        script_dir = os.path.dirname(os.path.abspath(__file__))
        with open(os.path.join(script_dir, "login_response.json"), "w", encoding="utf-8") as f:
            json.dump(user_data, f, ensure_ascii=False, indent=2)
        print("✅ Данные входа сохранены в login_response.json")
        
    else:
        print(f"❌ Ошибка аутентификации: {login_response.status_code}")
        print(login_response.text)
        return
    
    # Шаг 2: Проверяем различные эндпоинты с session cookie
    print("\n📝 Шаг 2: Тестируем эндпоинты с session cookie")
    
    endpoints_to_test = [
        "/profile",
        "/personal-information",
        "/user",
        "/me",
        "/account",
        "/student/profile",
        "/students/profile",
    ]
    
    successful_endpoints = []
    
    for endpoint in endpoints_to_test:
        url = f"{BASE_URL}{endpoint}"
        print(f"\n🔍 Тестирую: {url}")
        
        try:
            response = session.get(url, timeout=5)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    print(f"   ✅ Успех! Получены данные")
                    print(f"   Keys: {list(data.keys())[:10]}")
                    
                    successful_endpoints.append({
                        "url": url,
                        "data": data
                    })
                    
                    # Сохраняем первый успешный ответ
                    if len(successful_endpoints) == 1:
                        with open(os.path.join(script_dir, "profile_response.json"), "w", encoding="utf-8") as f:
                            json.dump(data, f, ensure_ascii=False, indent=2)
                        print(f"   💾 Данные сохранены в profile_response.json")
                    
                except Exception as e:
                    print(f"   Response (text): {response.text[:200]}")
            else:
                print(f"   ❌ Ошибка: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Исключение: {str(e)}")
    
    print("\n" + "=" * 80)
    print("📊 ИТОГИ")
    print("=" * 80)
    
    if successful_endpoints:
        print(f"\n✅ Найдено {len(successful_endpoints)} рабочих эндпоинта(ов):")
        for ep in successful_endpoints:
            print(f"  - {ep['url']}")
    else:
        print("\n❌ Не найдено рабочих эндпоинтов для профиля")
        print("Возможно, данные профиля уже получены при логине")

if __name__ == "__main__":
    main()
